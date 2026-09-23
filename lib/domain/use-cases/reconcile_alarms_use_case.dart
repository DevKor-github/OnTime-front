import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/services/alarm_scheduler_service.dart';
import 'package:on_time_front/core/services/fallback_alarm_notification_service.dart';
import 'package:on_time_front/core/services/local_time_zone_service.dart';
import 'package:on_time_front/domain/entities/alarm_delivery_policy.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
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
      final records = await _registryRepository.loadAll();
      AppLogger.debug(
        '$_logTag alarms disabled; canceling existingRecords=${records.length}',
      );
      final failedCancellations = await _cancelRecords(records);
      await _registryRepository.replaceAll(failedCancellations);
      final result = _result(
        status: failedCancellations.isEmpty
            ? AlarmReconciliationStatus.disabled
            : AlarmReconciliationStatus.partial,
        failures: _cancellationFailures(failedCancellations),
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

    final existingRecords = await _registryRepository.loadAll();
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

    final staleRecords = existingRecords.where((record) {
      final desired = desiredByScheduleId[record.scheduleId];
      return desired == null ||
          !_recordMatches(record, desired) ||
          !_recordProviderMatchesCapabilities(record, capabilities);
    }).toList();
    AppLogger.debug(
      '$_logTag staleRecords=${staleRecords.length} '
      'stale=${_recordSummary(staleRecords)}',
    );
    final failedCancellations = await _cancelRecords(staleRecords);
    final blockedScheduleIds = failedCancellations
        .map((record) => record.scheduleId)
        .toSet();

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

    final finalRecords = <ScheduledAlarmRecord>[];
    final failures = _cancellationFailures(failedCancellations);
    AlarmPermissionIssue? permissionIssue;

    for (final desired in desiredRecords) {
      // Never overwrite cancellation evidence or report an old detailed
      // registration as a newly armed private one.
      if (blockedScheduleIds.contains(desired.scheduleId)) continue;
      final existing = existingByScheduleId[desired.scheduleId];
      if (existing != null &&
          _recordMatches(existing, desired) &&
          _recordProviderMatchesCapabilities(existing, capabilities)) {
        AppLogger.debug(
          '$_logTag keeping existing alarm '
          'scheduleId=${existing.scheduleId} provider=${existing.provider}',
        );
        finalRecords.add(existing);
        continue;
      }

      final scheduled = await _scheduleRecord(
        desired,
        capabilities: capabilities,
        deliveryPolicy: deliveryPolicy,
        fallbackPermission: fallbackPermission,
      );

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

    await _registryRepository.replaceAll([
      ...finalRecords,
      ...failedCancellations,
    ]);
    AppLogger.debug(
      '$_logTag registry replaced finalRecords=${finalRecords.length} '
      'final=${_recordSummary(finalRecords)}',
    );

    final status = _statusFor(
      desiredCount: desiredRecords.length,
      armedCount: finalRecords.length,
      failures: failures,
      permissionIssue: permissionIssue,
      deliveryPolicy: deliveryPolicy,
    );

    final result = _result(
      status: status,
      permissionIssue: permissionIssue,
      capabilities: _effectiveCapabilities(capabilities, finalRecords),
      armedScheduleIds: finalRecords
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
      final nativeRecord = desired.copyWith(
        provider: capabilities.nativeAlarmProvider,
      );
      try {
        AppLogger.debug(
          '$_logTag trying native schedule '
          'scheduleId=${nativeRecord.scheduleId} '
          'alarmTime=${nativeRecord.alarmTime.toIso8601String()}',
        );
        await _schedulerService.scheduleNativeAlarm(nativeRecord);
        return _ScheduleAttempt(record: nativeRecord);
      } on AlarmSchedulingException catch (error) {
        AppLogger.debug(
          '$_logTag native schedule failed '
          'scheduleId=${nativeRecord.scheduleId} reason=${error.reason} '
          'permissionIssue=${error.permissionIssue} message=${error.message}',
        );
        if (error.permissionIssue == null &&
            fallbackPermission != AlarmPermissionState.granted) {
          return _ScheduleAttempt(
            failureReason: error.reason,
            message: error.message,
          );
        }
      } catch (error) {
        AppLogger.debug(
          '$_logTag native schedule threw '
          'scheduleId=${nativeRecord.scheduleId} error=$error',
        );
        if (fallbackPermission != AlarmPermissionState.granted) {
          return _ScheduleAttempt(
            failureReason: AlarmFailureReason.platformError,
            message: error.toString(),
          );
        }
      }
    }

    if ((deliveryPolicy.mode == AlarmDeliveryMode.fallbackNotification ||
            capabilities.fallbackProvider == AlarmProvider.localNotification) &&
        fallbackPermission == AlarmPermissionState.granted) {
      final fallbackRecord = desired.copyWith(
        provider: AlarmProvider.localNotification,
      );
      try {
        AppLogger.debug(
          '$_logTag trying fallback schedule '
          'scheduleId=${fallbackRecord.scheduleId} '
          'alarmTime=${fallbackRecord.alarmTime.toIso8601String()}',
        );
        await _fallbackNotificationService.scheduleFallbackAlarm(
          fallbackRecord,
        );
        return _ScheduleAttempt(record: fallbackRecord);
      } on AlarmSchedulingException catch (error) {
        AppLogger.debug(
          '$_logTag fallback schedule failed '
          'scheduleId=${fallbackRecord.scheduleId} reason=${error.reason} '
          'permissionIssue=${error.permissionIssue} message=${error.message}',
        );
        if (error.permissionIssue != null) {
          return _ScheduleAttempt(permissionIssue: error.permissionIssue);
        }
        return _ScheduleAttempt(
          failureReason: error.reason,
          message: error.message,
        );
      } catch (error) {
        AppLogger.debug(
          '$_logTag fallback schedule threw '
          'scheduleId=${fallbackRecord.scheduleId} error=$error',
        );
        return _ScheduleAttempt(
          failureReason: AlarmFailureReason.platformError,
          message: error.toString(),
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

  Future<List<ScheduledAlarmRecord>> _cancelRecords(
    List<ScheduledAlarmRecord> records,
  ) async {
    final failed = <ScheduledAlarmRecord>[];
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
  final AlarmPermissionIssue? permissionIssue;
  final AlarmFailureReason? failureReason;
  final String? message;

  const _ScheduleAttempt({
    this.record,
    this.permissionIssue,
    this.failureReason,
    this.message,
  });
}
