import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/services/alarm_scheduler_service.dart';
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
  Future<AlarmReconciliationResult>? _inFlight;

  ReconcileAlarmsUseCase(
    this._alarmRepository,
    this._registryRepository,
    this._schedulerService,
    this._fallbackNotificationService,
  ) : _nowProvider = DateTime.now,
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
  }) : _nowProvider = nowProvider,
       _languageCodeProvider = languageCodeProvider ?? _currentLanguageCode,
       _timeZoneProvider = timeZoneProvider ?? LocalTimeZoneService.current;

  static String _currentLanguageCode() =>
      ui.PlatformDispatcher.instance.locale.languageCode;

  Future<AlarmReconciliationResult> call() {
    final running = _inFlight;
    if (running != null) {
      AppLogger.debug('$_logTag call joined existing in-flight reconciliation');
      return running;
    }

    late final Future<AlarmReconciliationResult> pending;
    pending = _run().whenComplete(() {
      if (identical(_inFlight, pending)) {
        _inFlight = null;
      }
    });
    _inFlight = pending;
    return pending;
  }

  Future<AlarmReconciliationResult> _run() async {
    final now = _nowProvider();
    final scheduleWindowStart = now;
    final scheduleWindowEnd = DateTime(now.year + 50, 1, 1);
    final alarmCoverageStart = now;
    final capabilities = await _schedulerService.getCapabilities();
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
      AppLogger.debug(
        '$_logTag settings alarmsEnabled=${settings.alarmsEnabled} '
        'alarmOffset=${settings.alarmOffset}',
      );
    } catch (_) {
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
      final stored = await _registryRepository.loadAll();
      final observed = await _observeFallback();
      final records = [...stored, ..._fallbackOrphans(observed, stored)];
      final nativeObserved = await _observeNative(records, capabilities);
      final nativeUncertain = _nativeUncertain(nativeObserved, capabilities);
      AppLogger.debug(
        '$_logTag alarms disabled; canceling existingRecords=${records.length}',
      );
      final failedCancellations = await _cancelRecords(records);
      await _registryRepository.replaceAll(failedCancellations);
      final result = _result(
        status:
            failedCancellations.isEmpty &&
                !nativeUncertain &&
                (observed.available ||
                    capabilities.fallbackProvider !=
                        AlarmProvider.localNotification)
            ? AlarmReconciliationStatus.disabled
            : AlarmReconciliationStatus.partial,
        failures: [
          ..._cancellationFailures(failedCancellations),
          if (nativeUncertain) _observationFailure(),
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
      AppLogger.debug(
        '$_logTag getAlarmWindow success count=${schedules.length}',
      );
    } catch (error) {
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
    final allDesiredRecords = _desiredRecords(
      schedules: schedules,
      now: now,
      alarmCoverageEnd: alarmCoverageEnd,
      alarmOffset: settings.alarmOffset,
      detailedNotificationContent: settings.detailedNotificationContent,
      currentTimeZoneId: await _timeZoneProvider(),
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

    final storedRecords = await _registryRepository.loadAll();
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
    final existingByScheduleId = {
      for (final record in existingRecords) record.scheduleId: record,
    };
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

    final staleRecords = existingRecords.where((record) {
      final desired = desiredByScheduleId[record.scheduleId];
      return !deliveryPolicy.canDeliver ||
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
    final failedCancellations = await _cancelRecords(staleRecords);
    final blockedScheduleIds = failedCancellations
        .map((record) => record.scheduleId)
        .toSet();

    final finalRecords = <ScheduledAlarmRecord>[];
    final retainedRecords = <ScheduledAlarmRecord>[];
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
      // Never overwrite cancellation evidence or report an old detailed
      // registration as a newly armed private one.
      if (blockedScheduleIds.contains(desired.scheduleId)) continue;
      if (!desired.alarmTime.isAfter(_nowProvider())) continue;
      final existing = existingByScheduleId[desired.scheduleId];
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
    await _registryRepository.replaceAll([
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
    required String currentTimeZoneId,
    required String languageCode,
  }) {
    final records = schedules
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
    final alarmTime = computeAlarmTime(schedule, offset: alarmOffset);
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
    required AlarmSchedulerCapabilities capabilities,
    required AlarmDeliveryPolicy deliveryPolicy,
    required AlarmPermissionState fallbackPermission,
  }) async {
    if (deliveryPolicy.mode == AlarmDeliveryMode.nativeAlarm) {
      final record = desired.copyWith(
        provider: capabilities.nativeAlarmProvider,
      );
      await _rememberOwnership([record]);
      try {
        if (!record.alarmTime.isAfter(_nowProvider())) {
          return const _ScheduleAttempt(
            failureReason: AlarmFailureReason.scheduleInvalid,
          );
        }
        await _schedulerService.scheduleNativeAlarm(record);
        return _ScheduleAttempt(record: record);
      } catch (error) {
        // A channel error can follow an OS write. Confirm cleanup before
        // changing providers; do not create two deliveries for one Schedule.
        final pending = await _cancelRecords([record]);
        if (pending.isNotEmpty) {
          return _ScheduleAttempt(
            pendingRecord: pending.single,
            failureReason: AlarmFailureReason.cancellationFailed,
          );
        }
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
      final record = desired.copyWith(
        provider: AlarmProvider.localNotification,
      );
      await _rememberOwnership([record]);
      try {
        if (!record.alarmTime.isAfter(_nowProvider())) {
          return const _ScheduleAttempt(
            failureReason: AlarmFailureReason.scheduleInvalid,
          );
        }
        final timing = await _fallbackNotificationService.scheduleFallbackAlarm(
          record,
        );
        return _ScheduleAttempt(
          record: record.copyWith(notificationTiming: timing),
        );
      } catch (error) {
        final pending = await _cancelRecords([record]);
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
        existing.scheduleFingerprint == desired.scheduleFingerprint &&
        existing.payload['alarmLaunchPayloadVersion'] ==
            desired.payload['alarmLaunchPayloadVersion'] &&
        existing.alarmTime.isAtSameMomentAs(desired.alarmTime) &&
        existing.preparationStartTime.isAtSameMomentAs(
          desired.preparationStartTime,
        );
  }

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

  String _ownershipKey(ScheduledAlarmRecord record) =>
      '${record.provider.name}:${record.provider == AlarmProvider.localNotification ? record.fallbackNotificationId ?? stableAlarmId(record.scheduleId) : record.scheduleId}';

  Future<void> _rememberOwnership(List<ScheduledAlarmRecord> records) async {
    final stored = await _registryRepository.loadAll();
    final keys = records.map(_ownershipKey).toSet();
    await _registryRepository.replaceAll([
      ...stored.where((record) => !keys.contains(_ownershipKey(record))),
      ...records.map((record) => record.copyWith(cancellationPending: true)),
    ]);
  }

  Future<List<ScheduledAlarmRecord>> _cancelRecords(
    List<ScheduledAlarmRecord> records,
  ) async {
    final failed = <ScheduledAlarmRecord>[];
    if (records.isNotEmpty) await _rememberOwnership(records);
    for (final record in records) {
      try {
        if (record.provider == AlarmProvider.localNotification) {
          AppLogger.debug(
            '$_logTag cancel fallback '
            'scheduleId=${record.scheduleId} provider=${record.provider}',
          );
          await _fallbackNotificationService.cancelFallbackAlarm(record);
        } else if (record.provider != AlarmProvider.none) {
          AppLogger.debug(
            '$_logTag cancel native '
            'scheduleId=${record.scheduleId} provider=${record.provider}',
          );
          await _schedulerService.cancelNativeAlarm(record);
        }
      } catch (_) {
        failed.add(record.copyWith(cancellationPending: true));
        AppLogger.debug(
          '$_logTag cancel failed; retaining retry evidence '
          'scheduleId=${record.scheduleId} provider=${record.provider}',
        );
      }
    }
    return failed;
  }

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
