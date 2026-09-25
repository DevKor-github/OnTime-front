import 'package:on_time_front/core/time/schedule_time_resolution.dart';
import 'package:on_time_front/core/database/restore_runtime_identity.dart';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/services/alarm_scheduler_service.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/core/services/alarm_registration_cleanup.dart';
import 'package:on_time_front/core/services/fallback_alarm_notification_service.dart';
import 'package:on_time_front/core/services/local_time_zone_service.dart';
import 'package:on_time_front/domain/entities/alarm_delivery_policy.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/entities/delivery_observation.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/repositories/alarm_registry_repository.dart';
import 'package:on_time_front/domain/repositories/alarm_repository.dart';
import 'package:on_time_front/core/logging/app_logger.dart';

typedef AlarmNowProvider = DateTime Function();

@Singleton()
class ReconcileAlarmsUseCase {
  static const _logTag = '[ReconcileAlarms]';
  static const _platformAlarmCapacity = 60;

  final AlarmRepository _alarmRepository;
  final AlarmRegistryRepository _registryRepository;
  final AlarmSchedulerService _schedulerService;
  final FallbackAlarmNotificationService _fallbackNotificationService;
  final AlarmNowProvider _nowProvider;
  final String Function() _languageCodeProvider;
  final Future<String> Function() _timeZoneProvider;
  final AlarmOperationCoordinator _operations;
  final _requests = <_ReconciliationRequest>[];
  int _revision = 0;
  bool _draining = false;

  AlarmRegistrationCleanup get _cleanup => AlarmRegistrationCleanup(
    _registryRepository,
    _schedulerService,
    _fallbackNotificationService,
    _operations,
  );

  ReconcileAlarmsUseCase(
    this._alarmRepository,
    this._registryRepository,
    this._schedulerService,
    this._fallbackNotificationService, {
    @ignoreParam AlarmOperationCoordinator? operations,
  }) : _operations = operations ?? AlarmOperationCoordinator.shared,
       _nowProvider = DateTime.now,
       _languageCodeProvider = _currentLanguageCode,
       _timeZoneProvider = LocalTimeZoneService.current;

  @visibleForTesting
  ReconcileAlarmsUseCase.test(
    this._alarmRepository,
    this._registryRepository,
    this._schedulerService,
    this._fallbackNotificationService, {
    required AlarmNowProvider nowProvider,
    String Function()? languageCodeProvider,
    Future<String> Function()? timeZoneProvider,
    AlarmOperationCoordinator? operations,
  }) : _operations = operations ?? AlarmOperationCoordinator.shared,
       _nowProvider = nowProvider,
       _languageCodeProvider = languageCodeProvider ?? _currentLanguageCode,
       _timeZoneProvider = timeZoneProvider ?? LocalTimeZoneService.current;

  static String _currentLanguageCode() =>
      ui.PlatformDispatcher.instance.locale.languageCode;

  Future<AlarmReconciliationResult> call() {
    final AlarmOperationLease lease;
    try {
      lease = _operations.capture();
    } catch (error, stack) {
      return Future.error(error, stack);
    }
    final request = _ReconciliationRequest(++_revision, lease);
    _requests.add(request);
    if (!_draining) {
      _draining = true;
      _operations.addListener(_invalidateRequests);
      unawaited(_drain());
    }
    return request.completer.future;
  }

  void _invalidateRequests() {
    for (final request in _requests) {
      if (!request.lease.isCurrent && !request.completer.isCompleted) {
        request.completer.completeError(const AlarmOperationInvalidated());
      }
    }
  }

  Future<void> _drain() async {
    try {
      while (_requests.isNotEmpty) {
        final batch = List<_ReconciliationRequest>.of(_requests);
        final cutoff = batch.last.revision;
        try {
          final result = await _operations.run(
            batch.last.lease,
            () => _run(batch.last.lease),
          );
          batch.last.lease.check();
          for (final request in batch) {
            if (!request.completer.isCompleted) {
              request.completer.complete(result);
            }
          }
        } catch (error, stack) {
          for (final request in batch) {
            if (!request.completer.isCompleted) {
              request.completer.completeError(error, stack);
            }
          }
        }
        _requests.removeWhere((request) => request.revision <= cutoff);
      }
    } finally {
      // No await between the final queue check and idle transition.
      _operations.removeListener(_invalidateRequests);
      _draining = false;
    }
  }

  Future<AlarmReconciliationResult> _run(AlarmOperationLease lease) async {
    lease.check();
    final contentPermit = _operations.captureContentPermit();
    final now = _nowProvider();
    final scheduleWindowStart = now;
    final scheduleWindowEnd = DateTime(now.year + 50, 1, 1);
    final alarmCoverageStart = now;
    final capabilities = await _schedulerService.getCapabilities();
    lease.check();
    final alarmCoverageEnd = scheduleWindowEnd;
    AppLogger.debug(
      '$_logTag start now=${now.toIso8601String()} '
      'scheduleWindow=${scheduleWindowStart.toIso8601String()}..'
      '${scheduleWindowEnd.toIso8601String()} '
      'alarmCoverage=${alarmCoverageStart.toIso8601String()}..'
      '${alarmCoverageEnd.toIso8601String()}',
    );
    AppLogger.debug(
      '$_logTag capabilities='
      'nativeSupported=${capabilities.supportsNativeAlarm} '
      'nativeProvider=${capabilities.nativeAlarmProvider} '
      'fallbackProvider=${capabilities.fallbackProvider}',
    );

    AlarmSettings settings;
    try {
      settings = await _alarmRepository.getAlarmSettings();
      lease.check();
      AppLogger.debug(
        '$_logTag settings alarmsEnabled=${settings.alarmsEnabled} '
        'alarmOffset=${settings.alarmOffset}',
      );
    } catch (_) {
      lease.check();
      AppLogger.debug('$_logTag settings unavailable');
      final result = _result(
        status: AlarmReconciliationStatus.settingsUnavailable,
        capabilities: capabilities,
        scheduleWindowStart: scheduleWindowStart,
        scheduleWindowEnd: scheduleWindowEnd,
        alarmCoverageStart: alarmCoverageStart,
        alarmCoverageEnd: alarmCoverageEnd,
      );
      return result;
    }

    if (!settings.alarmsEnabled) {
      final stored = await _operations.loadRecords(_registryRepository);
      final unknownOwnership =
          (await _operations.journal.read()).unknownOwnership;
      final observed = await _observeFallback();
      final records = [...stored, ..._fallbackOrphans(observed, stored)];
      final nativeObserved = await _observeNative(records, capabilities);
      final nativeUncertain = _nativeUncertain(nativeObserved, capabilities);
      AppLogger.debug(
        '$_logTag alarms disabled; canceling existingRecords=${records.length}',
      );
      lease.check();
      final failedCancellations = await _cancelRecords(records);
      lease.check();
      await _operations.replaceRecords(
        _registryRepository,
        failedCancellations,
      );
      final result = _result(
        status:
            failedCancellations.isEmpty &&
                !unknownOwnership &&
                !nativeUncertain &&
                (observed.available ||
                    capabilities.fallbackProvider !=
                        AlarmProvider.localNotification)
            ? AlarmReconciliationStatus.disabled
            : AlarmReconciliationStatus.partial,
        failures: [
          ..._cancellationFailures(failedCancellations),
          if (nativeUncertain || unknownOwnership) _observationFailure(),
          if (!observed.available &&
              capabilities.fallbackProvider == AlarmProvider.localNotification)
            _observationFailure(),
        ],
        capabilities: capabilities,
        scheduleWindowStart: scheduleWindowStart,
        scheduleWindowEnd: scheduleWindowEnd,
        alarmCoverageStart: alarmCoverageStart,
        alarmCoverageEnd: alarmCoverageEnd,
      );
      return result;
    }

    late final List<ScheduleWithPreparationEntity> schedules;
    try {
      AppLogger.debug(
        '$_logTag getAlarmWindow request '
        '${scheduleWindowStart.toIso8601String()}..'
        '${scheduleWindowEnd.toIso8601String()}',
      );
      schedules = await _alarmRepository.getAlarmWindow(
        scheduleWindowStart,
        scheduleWindowEnd,
      );
      lease.check();
      AppLogger.debug(
        '$_logTag getAlarmWindow success count=${schedules.length}',
      );
    } catch (error) {
      lease.check();
      AppLogger.debug('$_logTag getAlarmWindow failed: $error');
      final result = _result(
        status: AlarmReconciliationStatus.partial,
        capabilities: capabilities,
        failures: [
          AlarmFailure(
            reason: AlarmFailureReason.preparationLoadFailed,
            message: error.toString(),
          ),
        ],
        scheduleWindowStart: scheduleWindowStart,
        scheduleWindowEnd: scheduleWindowEnd,
        alarmCoverageStart: alarmCoverageStart,
        alarmCoverageEnd: alarmCoverageEnd,
      );
      return result;
    }
    String? deviceZone;
    try {
      deviceZone = await _timeZoneProvider();
    } catch (_) {
      // Display-zone discovery does not revoke resolved schedule instants or
      // the authority to clean up requests already owned by this installation.
    }
    final allDesiredRecords = _desiredRecords(
      schedules: schedules,
      now: now,
      alarmCoverageEnd: alarmCoverageEnd,
      alarmOffset: settings.alarmOffset,
      detailedNotificationContent: settings.detailedNotificationContent,
      currentTimeZoneId: deviceZone,
      languageCode: _languageCodeProvider(),
    );
    final desiredRecords = allDesiredRecords
        .take(_platformAlarmCapacity)
        .toList();
    final skippedScheduleCount =
        schedules
            .where(
              (schedule) => !_isDesired(
                schedule,
                now,
                alarmCoverageEnd,
                settings.alarmOffset,
              ),
            )
            .length +
        (allDesiredRecords.length - desiredRecords.length);
    AppLogger.debug(
      '$_logTag desiredRecords=${desiredRecords.length} '
      'skippedSchedules=$skippedScheduleCount '
      'desired=${_recordSummary(desiredRecords)}',
    );

    final storedRecords = await _operations.loadRecords(_registryRepository);
    if ((await _operations.journal.read()).unknownOwnership) {
      lease.check();
      return _result(
        status: AlarmReconciliationStatus.partial,
        failures: [_observationFailure()],
        capabilities: capabilities,
        scheduleWindowStart: scheduleWindowStart,
        scheduleWindowEnd: scheduleWindowEnd,
        alarmCoverageStart: alarmCoverageStart,
        alarmCoverageEnd: alarmCoverageEnd,
      );
    }
    final fallbackObservation = await _observeFallback();
    final existingRecords = [
      ...storedRecords,
      ..._fallbackOrphans(fallbackObservation, storedRecords),
    ];
    final nativeObservation = await _observeNative([
      ...existingRecords,
      ...desiredRecords,
    ], capabilities);
    AppLogger.debug(
      '$_logTag existingRecords=${existingRecords.length} '
      'existing=${_recordSummary(existingRecords)}',
    );
    final desiredByScheduleId = {
      for (final record in desiredRecords) record.scheduleId: record,
    };

    final timingPermission = await _fallbackNotificationService
        .checkExactTimingPermission();
    final desiredTiming = timingPermission == AlarmPermissionState.unsupported
        ? NotificationTiming.platformDefault
        : timingPermission == AlarmPermissionState.granted
        ? NotificationTiming.exact
        : NotificationTiming.approximate;
    bool timingMatches(ScheduledAlarmRecord record) =>
        record.provider != AlarmProvider.localNotification ||
        // iOS has no Android timing access and keeps its existing delivery policy.
        desiredTiming == NotificationTiming.platformDefault ||
        record.notificationTiming == desiredTiming;

    final nativePermission = await _checkNativePermission(capabilities);
    final fallbackPermission = await _checkFallbackPermission(capabilities);
    AppLogger.debug(
      '$_logTag permissions native=$nativePermission '
      'fallback=$fallbackPermission',
    );
    final deliveryPolicy = AlarmDeliveryPolicy.evaluate(
      capabilities: capabilities,
      nativePermission: nativePermission,
      fallbackPermission: fallbackPermission,
    );

    final existingByScheduleId = <String, ScheduledAlarmRecord>{};
    for (final record in existingRecords) {
      final desired = desiredByScheduleId[record.scheduleId];
      final previous = existingByScheduleId[record.scheduleId];
      bool keepable(ScheduledAlarmRecord value) =>
          desired != null &&
          !value.cancellationPending &&
          _recordMatches(value, desired) &&
          value.provider == deliveryPolicy.activeProvider &&
          timingMatches(value);
      if (previous == null || (!keepable(previous) && keepable(record))) {
        existingByScheduleId[record.scheduleId] = record;
      }
    }

    bool preservePrivate(ScheduledAlarmRecord record) {
      final desired = desiredByScheduleId[record.scheduleId];
      return desired != null &&
          desired.deliveryContent.detailed &&
          !_operations.allowsDetailed(contentPermit) &&
          record.hasCurrentContent &&
          !record.deliveryContent.detailed &&
          _timingAndRoutingMatch(record, desired) &&
          record.provider == deliveryPolicy.activeProvider &&
          _recordProviderMatchesCapabilities(record, capabilities) &&
          timingMatches(record) &&
          deliveryPolicy.canDeliver &&
          !_fallbackIdentityConflict(record, fallbackObservation);
    }

    lease.check();
    final staleRecords = existingRecords.where((record) {
      if (preservePrivate(record)) return false;
      final desired = desiredByScheduleId[record.scheduleId];
      return !identical(record, existingByScheduleId[record.scheduleId]) ||
          !deliveryPolicy.canDeliver ||
          desired == null ||
          !_recordMatches(record, desired) ||
          _fallbackIdentityConflict(record, fallbackObservation) ||
          record.provider != deliveryPolicy.activeProvider ||
          !_recordProviderMatchesCapabilities(record, capabilities) ||
          !timingMatches(record);
    }).toList();
    AppLogger.debug(
      '$_logTag staleRecords=${staleRecords.length} '
      'stale=${_recordSummary(staleRecords)}',
    );
    final failedCancellations = <ScheduledAlarmRecord>[];
    final deferredPrivate = <ScheduledAlarmRecord>[];
    for (final record in List<ScheduledAlarmRecord>.of(staleRecords)) {
      if (preservePrivate(record)) {
        deferredPrivate.add(record);
        continue;
      }
      try {
        failedCancellations.addAll(
          await _cleanup.cancelRecords([
            record,
          ], isCurrent: () => lease.isCurrent && !preservePrivate(record)),
        );
      } on AlarmOperationInvalidated {
        lease.check();
        if (!preservePrivate(record)) rethrow;
        // A privacy request arrived while ownership was being persisted. Keep
        // the existing ID; no caller may mistake this for confirmed delivery.
        deferredPrivate.add(record);
      }
    }
    staleRecords.removeWhere(deferredPrivate.contains);
    lease.check();
    final blockedScheduleIds = failedCancellations
        .map((record) => record.scheduleId)
        .toSet();

    final finalRecords = <ScheduledAlarmRecord>[];
    final retainedRecords = <ScheduledAlarmRecord>[
      ...existingRecords.where(
        (record) =>
            blockedScheduleIds.contains(record.scheduleId) &&
            !staleRecords.contains(record),
      ),
    ];
    final failures = [
      ..._cancellationFailures(failedCancellations),
      if (!fallbackObservation.available &&
          capabilities.fallbackProvider == AlarmProvider.localNotification)
        _observationFailure(),
      if (_nativeUncertain(nativeObservation, capabilities))
        _observationFailure(
          message:
              'Native registrations or their ownership could not be confirmed',
        ),
    ];
    AlarmPermissionIssue? permissionIssue;

    for (final desired in desiredRecords) {
      lease.check();
      // Never overwrite cancellation evidence or report an old detailed
      // registration as a newly armed private one.
      if (blockedScheduleIds.contains(desired.scheduleId)) continue;
      if (!desired.alarmTime.isAfter(_nowProvider())) continue;
      final existing = existingByScheduleId[desired.scheduleId];
      if (desired.deliveryContent.detailed &&
          !_operations.allowsDetailed(contentPermit)) {
        if (existing != null && !staleRecords.contains(existing)) {
          retainedRecords.add(existing);
        }
        failures.add(
          AlarmFailure(
            scheduleId: desired.scheduleId,
            reason: AlarmFailureReason.contentDeferred,
          ),
        );
        continue;
      }
      if (existing != null &&
          !staleRecords.contains(existing) &&
          existing.provider == deliveryPolicy.activeProvider &&
          _recordMatches(existing, desired) &&
          timingMatches(existing) &&
          deliveryPolicy.canDeliver) {
        final observation = existing.provider == AlarmProvider.localNotification
            ? fallbackObservation
            : nativeObservation;
        if (observation.isOsObservation &&
            observation.presence(existing) == DeliveryPresence.present) {
          finalRecords.add(existing);
          continue;
        }
        if (observation.presence(existing) == DeliveryPresence.unknown &&
            observation.source !=
                DeliveryObservationSource.androidPluginCache) {
          retainedRecords.add(existing);
          failures.add(_observationFailure(scheduleId: existing.scheduleId));
          continue;
        }
        // iOS OS absence is repaired; Android always reapplies the same ID.
        // Cache presence is not evidence that AlarmManager kept the request.
      }

      // Retain the owned platform ID even for older installations that used
      // another stable ID algorithm. Reapplying must not leave two requests.
      final reapplied =
          existing != null &&
              !staleRecords.contains(existing) &&
              existing.provider == AlarmProvider.localNotification
          ? desired.copyWith(
              fallbackNotificationId: existing.fallbackNotificationId,
            )
          : desired;
      final scheduled = await _scheduleRecord(
        reapplied,
        contentPermit: contentPermit,
        lease: lease,
        capabilities: capabilities,
        deliveryPolicy: deliveryPolicy,
        fallbackPermission: fallbackPermission,
      );

      if (scheduled.pendingRecord != null) {
        retainedRecords.add(scheduled.pendingRecord!);
      }
      if (scheduled.record != null) {
        AppLogger.debug(
          '$_logTag scheduled alarm '
          'scheduleId=${scheduled.record!.scheduleId} '
          'provider=${scheduled.record!.provider}',
        );
        finalRecords.add(scheduled.record!);
      } else if (scheduled.permissionIssue != null) {
        AppLogger.debug(
          '$_logTag schedule permission issue '
          'scheduleId=${desired.scheduleId} '
          'issue=${scheduled.permissionIssue}',
        );
        permissionIssue ??= scheduled.permissionIssue;
      } else {
        AppLogger.debug(
          '$_logTag schedule failure scheduleId=${desired.scheduleId} '
          'reason=${scheduled.failureReason} message=${scheduled.message}',
        );
        failures.add(
          AlarmFailure(
            scheduleId: desired.scheduleId,
            reason: scheduled.failureReason ?? AlarmFailureReason.unknown,
            message: scheduled.message,
          ),
        );
      }
    }

    // Query again after writes. A scheduling receipt and OS presence are
    // different facts; keep ownership when verification fails.
    final postFallback = await _observeFallback();
    final postNative = await _observeNative([
      ...existingRecords,
      ...finalRecords,
    ], capabilities);
    if (_nativeUncertain(postNative, capabilities)) {
      failures.add(_observationFailure());
    }
    if (!postFallback.available &&
        capabilities.fallbackProvider == AlarmProvider.localNotification) {
      failures.add(_observationFailure());
    }
    final confirmedRecords = <ScheduledAlarmRecord>[];
    for (final record in finalRecords) {
      final observed = record.provider == AlarmProvider.localNotification
          ? postFallback
          : postNative;
      if (observed.presence(record) == DeliveryPresence.present) {
        confirmedRecords.add(record);
      } else {
        retainedRecords.add(record);
        failures.add(_observationFailure(scheduleId: record.scheduleId));
      }
    }
    lease.check();
    await _operations.replaceRecords(_registryRepository, [
      ...confirmedRecords,
      ...retainedRecords,
      ...failedCancellations,
    ]);
    AppLogger.debug(
      '$_logTag registry replaced finalRecords=${finalRecords.length} '
      'final=${_recordSummary(finalRecords)}',
    );

    final status = _statusFor(
      desiredCount: desiredRecords.length,
      armedCount: confirmedRecords.length,
      failures: failures,
      permissionIssue: permissionIssue,
      deliveryPolicy: deliveryPolicy,
    );

    final result = _result(
      status: status,
      permissionIssue: permissionIssue,
      capabilities: _effectiveCapabilities(capabilities, confirmedRecords),
      armedScheduleIds: confirmedRecords
          .map((record) => record.scheduleId)
          .toList(),
      skippedScheduleCount: skippedScheduleCount,
      failures: failures,
      scheduleWindowStart: scheduleWindowStart,
      scheduleWindowEnd: scheduleWindowEnd,
      alarmCoverageStart: alarmCoverageStart,
      alarmCoverageEnd: alarmCoverageEnd,
    );

    AppLogger.debug(
      '$_logTag complete status=${result.status} '
      'armed=${result.armedScheduleCount} skipped=${result.skippedScheduleCount} '
      'permissionIssue=${result.permissionIssue} failures=${result.failures.length}',
    );
    return result;
  }

  List<ScheduledAlarmRecord> _desiredRecords({
    required List<ScheduleWithPreparationEntity> schedules,
    required DateTime now,
    required DateTime alarmCoverageEnd,
    required Duration alarmOffset,
    required bool detailedNotificationContent,
    required String? currentTimeZoneId,
    required String languageCode,
  }) {
    final resolved = <ScheduleWithPreparationEntity>[];
    for (final schedule in schedules) {
      final time = ScheduleTimeResolver.resolve(schedule, nowUtc: now);
      if (time.instantUtc == null) continue;
      resolved.add(
        ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
          schedule,
          schedule.preparation,
          timeResolution: time,
        ),
      );
    }
    final records = resolved
        .where(
          (schedule) =>
              _isDesired(schedule, now, alarmCoverageEnd, alarmOffset),
        )
        .map(
          (schedule) => buildScheduledAlarmRecord(
            schedule,
            alarmOffset: alarmOffset,
            provider: AlarmProvider.none,
            detailedNotificationContent: detailedNotificationContent,
            currentTimeZoneId: currentTimeZoneId,
            languageCode: languageCode,
            storeIncarnation: RestoreRuntimeIdentity.shared.storeIncarnation,
          ),
        )
        .toList();
    records.sort((a, b) => a.alarmTime.compareTo(b.alarmTime));
    return records;
  }

  bool _isDesired(
    ScheduleWithPreparationEntity schedule,
    DateTime now,
    DateTime alarmCoverageEnd,
    Duration alarmOffset,
  ) {
    if (!isAlarmEligibleSchedule(schedule) || schedule.isStarted) return false;
    if (schedule.id.isEmpty) return false;
    final time = ScheduleTimeResolver.resolve(schedule, nowUtc: now);
    final instant = time.instantUtc;
    if (instant == null) return false;
    final alarmTime = instant
        .subtract(schedule.totalDuration)
        .subtract(alarmOffset);
    return alarmTime.isAfter(now) &&
        (alarmTime.isBefore(alarmCoverageEnd) ||
            alarmTime.isAtSameMomentAs(alarmCoverageEnd));
  }

  Future<AlarmPermissionState> _checkNativePermission(
    AlarmSchedulerCapabilities capabilities,
  ) async {
    if (!_canUseNativeProvider(capabilities)) {
      return AlarmPermissionState.unsupported;
    }
    return _schedulerService.checkPermission().catchError(
      (_) => AlarmPermissionState.unsupported,
    );
  }

  Future<AlarmPermissionState> _checkFallbackPermission(
    AlarmSchedulerCapabilities capabilities,
  ) async {
    if (capabilities.fallbackProvider != AlarmProvider.localNotification) {
      return AlarmPermissionState.unsupported;
    }
    return _fallbackNotificationService.checkPermission().catchError(
      (_) => AlarmPermissionState.denied,
    );
  }

  Future<_ScheduleAttempt> _scheduleRecord(
    ScheduledAlarmRecord desired, {
    required AlarmContentPermit contentPermit,
    required AlarmOperationLease lease,
    required AlarmSchedulerCapabilities capabilities,
    required AlarmDeliveryPolicy deliveryPolicy,
    required AlarmPermissionState fallbackPermission,
  }) async {
    bool held() =>
        desired.deliveryContent.detailed &&
        !_operations.allowsDetailed(contentPermit);
    if (held()) {
      return const _ScheduleAttempt(
        failureReason: AlarmFailureReason.contentDeferred,
      );
    }
    if (deliveryPolicy.mode == AlarmDeliveryMode.nativeAlarm) {
      final record = desired.copyWith(
        provider: capabilities.nativeAlarmProvider,
      );
      lease.check();
      await _rememberOwnership([record]);
      lease.check();
      try {
        if (!record.alarmTime.isAfter(_nowProvider())) {
          return const _ScheduleAttempt(
            failureReason: AlarmFailureReason.scheduleInvalid,
          );
        }
        if (held()) {
          return _ScheduleAttempt(
            pendingRecord: AlarmOperationCoordinator.ownershipOnly(record),
            failureReason: AlarmFailureReason.contentDeferred,
          );
        }
        await _schedulerService.scheduleNativeAlarm(record);
        lease.check();
        return _ScheduleAttempt(record: record);
      } catch (error) {
        if (error is AlarmOperationInvalidated) rethrow;
        // A channel error can follow an OS write. Confirm cleanup before
        // changing providers; do not create two deliveries for one Schedule.
        final pending = await _cancelRecords([record]);
        if (pending.isNotEmpty) {
          return _ScheduleAttempt(
            pendingRecord: pending.single,
            failureReason: AlarmFailureReason.cancellationFailed,
          );
        }
        lease.check();
        if (fallbackPermission != AlarmPermissionState.granted) {
          return _ScheduleAttempt(
            failureReason: error is AlarmSchedulingException
                ? error.reason
                : AlarmFailureReason.platformError,
            permissionIssue: error is AlarmSchedulingException
                ? error.permissionIssue
                : null,
            message: error is AlarmSchedulingException
                ? error.message
                : error.toString(),
          );
        }
      }
    }

    if (capabilities.fallbackProvider == AlarmProvider.localNotification &&
        fallbackPermission == AlarmPermissionState.granted) {
      if (held()) {
        return const _ScheduleAttempt(
          failureReason: AlarmFailureReason.contentDeferred,
        );
      }
      final record = desired.copyWith(
        provider: AlarmProvider.localNotification,
      );
      lease.check();
      await _rememberOwnership([record]);
      lease.check();
      try {
        if (!record.alarmTime.isAfter(_nowProvider())) {
          return const _ScheduleAttempt(
            failureReason: AlarmFailureReason.scheduleInvalid,
          );
        }
        if (held()) {
          return _ScheduleAttempt(
            pendingRecord: AlarmOperationCoordinator.ownershipOnly(record),
            failureReason: AlarmFailureReason.contentDeferred,
          );
        }
        final timing = await _fallbackNotificationService.scheduleFallbackAlarm(
          record,
        );
        lease.check();
        return _ScheduleAttempt(
          record: record.copyWith(notificationTiming: timing),
        );
      } catch (error) {
        if (error is AlarmOperationInvalidated) rethrow;
        final pending = await _cancelRecords([record]);
        lease.check();
        return _ScheduleAttempt(
          pendingRecord: pending.firstOrNull,
          message: error is AlarmSchedulingException
              ? error.message
              : error.toString(),
          failureReason: pending.isNotEmpty
              ? AlarmFailureReason.cancellationFailed
              : error is AlarmSchedulingException
              ? error.reason
              : AlarmFailureReason.platformError,
          permissionIssue: pending.isEmpty && error is AlarmSchedulingException
              ? error.permissionIssue
              : null,
        );
      }
    }

    final blockingIssue = deliveryPolicy.blockingPermissionIssue;
    if (blockingIssue != null) {
      return _ScheduleAttempt(permissionIssue: blockingIssue);
    }

    return const _ScheduleAttempt(
      failureReason: AlarmFailureReason.platformError,
      message: 'No alarm delivery provider is available',
    );
  }

  AlarmReconciliationStatus _statusFor({
    required int desiredCount,
    required int armedCount,
    required List<AlarmFailure> failures,
    required AlarmPermissionIssue? permissionIssue,
    required AlarmDeliveryPolicy deliveryPolicy,
  }) {
    if (failures.any(
      (failure) => failure.reason == AlarmFailureReason.cancellationFailed,
    )) {
      return AlarmReconciliationStatus.partial;
    }
    if (!deliveryPolicy.canDeliver) {
      if (permissionIssue != null) {
        return AlarmReconciliationStatus.permissionNeeded;
      }
      return deliveryPolicy.isUnsupported
          ? AlarmReconciliationStatus.unsupported
          : AlarmReconciliationStatus.permissionNeeded;
    }
    if (desiredCount > armedCount || failures.isNotEmpty) {
      return armedCount == 0 && permissionIssue != null
          ? AlarmReconciliationStatus.permissionNeeded
          : AlarmReconciliationStatus.partial;
    }
    if (permissionIssue != null && armedCount == 0) {
      return AlarmReconciliationStatus.permissionNeeded;
    }
    return AlarmReconciliationStatus.armed;
  }

  AlarmSchedulerCapabilities _effectiveCapabilities(
    AlarmSchedulerCapabilities capabilities,
    List<ScheduledAlarmRecord> records,
  ) {
    var nativeProvider = AlarmProvider.none;
    for (final record in records) {
      if (record.provider != AlarmProvider.none &&
          record.provider != AlarmProvider.localNotification) {
        nativeProvider = record.provider;
        break;
      }
    }
    final usesFallback = records.any(
      (record) => record.provider == AlarmProvider.localNotification,
    );
    return AlarmSchedulerCapabilities(
      supportsNativeAlarm: capabilities.supportsNativeAlarm,
      nativeAlarmProvider: nativeProvider,
      fallbackProvider: usesFallback
          ? AlarmProvider.localNotification
          : AlarmProvider.none,
    );
  }

  bool _recordMatches(
    ScheduledAlarmRecord existing,
    ScheduledAlarmRecord desired,
  ) {
    return existing.hasCurrentContent &&
        existing.contentVersion == desired.contentVersion &&
        existing.contentDigest == desired.contentDigest &&
        _timingAndRoutingMatch(existing, desired);
  }

  bool _timingAndRoutingMatch(
    ScheduledAlarmRecord existing,
    ScheduledAlarmRecord desired,
  ) =>
      existing.scheduleFingerprint == desired.scheduleFingerprint &&
      existing.payload['storeIncarnation'] ==
          desired.payload['storeIncarnation'] &&
      existing.payload['alarmLaunchPayloadVersion'] ==
          desired.payload['alarmLaunchPayloadVersion'] &&
      existing.alarmTime.isAtSameMomentAs(desired.alarmTime) &&
      existing.preparationStartTime.isAtSameMomentAs(
        desired.preparationStartTime,
      );

  bool _recordProviderMatchesCapabilities(
    ScheduledAlarmRecord record,
    AlarmSchedulerCapabilities capabilities,
  ) {
    if (record.provider == AlarmProvider.localNotification) {
      return capabilities.fallbackProvider == AlarmProvider.localNotification;
    }
    if (record.provider == AlarmProvider.none) return false;
    return _canUseNativeProvider(capabilities) &&
        record.provider == capabilities.nativeAlarmProvider;
  }

  bool _canUseNativeProvider(AlarmSchedulerCapabilities capabilities) {
    return capabilities.supportsNativeAlarm &&
        capabilities.nativeAlarmProvider != AlarmProvider.none &&
        nativeAlarmProviderAllowedByReleasePolicy(
          capabilities.nativeAlarmProvider,
        );
  }

  List<AlarmFailure> _cancellationFailures(
    List<ScheduledAlarmRecord> records,
  ) => records
      .map(
        (record) => AlarmFailure(
          scheduleId: record.scheduleId,
          reason: AlarmFailureReason.cancellationFailed,
          message: 'Existing notification cancellation could not be confirmed',
        ),
      )
      .toList();

  Future<DeliveryObservation> _observeFallback() async {
    try {
      return await _fallbackNotificationService.observePending();
    } catch (_) {
      return const DeliveryObservation.unknown();
    }
  }

  Future<DeliveryObservation> _observeNative(
    List<ScheduledAlarmRecord> records,
    AlarmSchedulerCapabilities capabilities,
  ) async {
    if (capabilities.nativeAlarmProvider != AlarmProvider.iosAlarmKit &&
        !records.any((r) => r.provider == AlarmProvider.iosAlarmKit)) {
      return const DeliveryObservation.unknown();
    }
    try {
      return await _schedulerService.observePendingNativeAlarms(
        records.map((r) => r.scheduleId),
      );
    } catch (_) {
      return const DeliveryObservation.unknown(
        source: DeliveryObservationSource.iosAlarmKit,
      );
    }
  }

  bool _nativeUncertain(
    DeliveryObservation observed,
    AlarmSchedulerCapabilities capabilities,
  ) =>
      observed.unmappedCount > 0 ||
      (!observed.available &&
          (capabilities.nativeAlarmProvider == AlarmProvider.iosAlarmKit ||
              observed.source == DeliveryObservationSource.iosAlarmKit));

  AlarmFailure _observationFailure({String? scheduleId, String? message}) =>
      AlarmFailure(
        scheduleId: scheduleId,
        reason: AlarmFailureReason.observationFailed,
        message: message ?? 'Delivery registration could not be confirmed',
      );

  List<ScheduledAlarmRecord> _fallbackOrphans(
    DeliveryObservation observed,
    List<ScheduledAlarmRecord> stored,
  ) {
    if (!observed.available) return const [];
    final knownIds = stored
        .where((r) => r.provider == AlarmProvider.localNotification)
        .map(
          (r) => (r.fallbackNotificationId ?? stableAlarmId(r.scheduleId))
              .toString(),
        )
        .toSet();
    return observed.entries
        .where(
          (entry) =>
              !knownIds.contains(entry.id) &&
              entry.scheduleId != null &&
              int.tryParse(entry.id) != null,
        )
        .map(
          (entry) => ScheduledAlarmRecord(
            scheduleId: entry.scheduleId!,
            provider: AlarmProvider.localNotification,
            fallbackNotificationId: int.parse(entry.id),
            alarmTime: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
            preparationStartTime: DateTime.fromMillisecondsSinceEpoch(
              0,
              isUtc: true,
            ),
            scheduleFingerprint: '',
            scheduleTitle: 'OnTime',
            payload: const {},
            cancellationPending: true,
          ),
        )
        .toList();
  }

  bool _fallbackIdentityConflict(
    ScheduledAlarmRecord record,
    DeliveryObservation observed,
  ) {
    if (!observed.available ||
        record.provider != AlarmProvider.localNotification) {
      return false;
    }
    final id =
        (record.fallbackNotificationId ?? stableAlarmId(record.scheduleId))
            .toString();
    return observed.entries.any(
      (entry) => entry.id == id && entry.scheduleId != record.scheduleId,
    );
  }

  Future<void> _rememberOwnership(List<ScheduledAlarmRecord> records) =>
      _operations.remember(_registryRepository, records);

  Future<List<ScheduledAlarmRecord>> _cancelRecords(
    List<ScheduledAlarmRecord> records,
  ) => _cleanup.cancelRecords(records);

  AlarmReconciliationResult _result({
    required AlarmReconciliationStatus status,
    required AlarmSchedulerCapabilities capabilities,
    required DateTime scheduleWindowStart,
    required DateTime scheduleWindowEnd,
    required DateTime alarmCoverageStart,
    required DateTime alarmCoverageEnd,
    AlarmPermissionIssue? permissionIssue,
    List<String> armedScheduleIds = const [],
    int skippedScheduleCount = 0,
    List<AlarmFailure> failures = const [],
  }) {
    return AlarmReconciliationResult(
      status: status,
      permissionIssue: permissionIssue,
      nativeAlarmProvider: capabilities.nativeAlarmProvider,
      fallbackProvider: capabilities.fallbackProvider,
      armedScheduleIds: armedScheduleIds,
      skippedScheduleCount: skippedScheduleCount,
      failures: failures,
      scheduleWindowStart: scheduleWindowStart,
      scheduleWindowEnd: scheduleWindowEnd,
      alarmCoverageStart: alarmCoverageStart,
      alarmCoverageEnd: alarmCoverageEnd,
    );
  }

  String _recordSummary(List<ScheduledAlarmRecord> records) {
    if (records.isEmpty) return '[]';
    return records
        .map(
          (record) =>
              '{id=${record.scheduleId}, '
              'provider=${record.provider}, '
              'nativeId=${record.nativeAlarmId}, '
              'alarm=${record.alarmTime.toIso8601String()}}',
        )
        .join(', ');
  }
}

class _ScheduleAttempt {
  final ScheduledAlarmRecord? record;
  final ScheduledAlarmRecord? pendingRecord;
  final AlarmPermissionIssue? permissionIssue;
  final AlarmFailureReason? failureReason;
  final String? message;

  const _ScheduleAttempt({
    this.record,
    this.pendingRecord,
    this.permissionIssue,
    this.failureReason,
    this.message,
  });
}

final class _ReconciliationRequest {
  _ReconciliationRequest(this.revision, this.lease);
  final int revision;
  final AlarmOperationLease lease;
  final completer = Completer<AlarmReconciliationResult>();
}

/// Acceptance is synchronous; errors remain observed where DB saves do not wait
/// for operating-system delivery effects.
void requestAlarmReconciliation(ReconcileAlarmsUseCase reconcile) {
  unawaited(
    reconcile().then<void>(
      (_) {},
      onError: (Object error, StackTrace _) {
        AppLogger.debug(
          '[ReconcileAlarms] request ended errorType=${error.runtimeType}',
        );
      },
    ),
  );
}
