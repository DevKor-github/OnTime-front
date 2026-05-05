import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/services/alarm_scheduler_service.dart';
import 'package:on_time_front/core/services/fallback_alarm_notification_service.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/repositories/alarm_registry_repository.dart';
import 'package:on_time_front/domain/repositories/alarm_repository.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';

typedef AlarmNowProvider = DateTime Function();

@Singleton()
class ReconcileAlarmsUseCase {
  final AlarmRepository _alarmRepository;
  final AlarmRegistryRepository _registryRepository;
  final AlarmSchedulerService _schedulerService;
  final FallbackAlarmNotificationService _fallbackNotificationService;
  final UserRepository? _userRepository;
  final AlarmNowProvider _nowProvider;
  Future<AlarmReconciliationResult>? _inFlight;

  ReconcileAlarmsUseCase(
    this._alarmRepository,
    this._registryRepository,
    this._schedulerService,
    this._fallbackNotificationService,
    UserRepository userRepository,
  )   : _userRepository = userRepository,
        _nowProvider = DateTime.now;

  @visibleForTesting
  ReconcileAlarmsUseCase.test(
    this._alarmRepository,
    this._registryRepository,
    this._schedulerService,
    this._fallbackNotificationService, {
    required AlarmNowProvider nowProvider,
    UserRepository? userRepository,
  })  : _userRepository = userRepository,
        _nowProvider = nowProvider;

  Future<AlarmReconciliationResult> call() {
    final running = _inFlight;
    if (running != null) {
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
    final scheduleWindowEnd = now.add(const Duration(days: 8));
    final alarmCoverageStart = now;
    final alarmCoverageEnd = now.add(const Duration(days: 7));
    final deviceId = await _alarmRepository.getDeviceId();
    final capabilities = await _schedulerService.getCapabilities();

    AlarmSettings settings;
    try {
      settings = await _alarmRepository.getAlarmSettings();
    } catch (_) {
      final result = _result(
        status: AlarmReconciliationStatus.settingsUnavailable,
        capabilities: capabilities,
        scheduleWindowStart: scheduleWindowStart,
        scheduleWindowEnd: scheduleWindowEnd,
        alarmCoverageStart: alarmCoverageStart,
        alarmCoverageEnd: alarmCoverageEnd,
      );
      await _postStatusBestEffort(deviceId, result);
      return result;
    }

    if (!settings.alarmsEnabled) {
      final records = await _registryRepository.loadAll();
      await _cancelRecords(records);
      await _registryRepository.deleteAll();
      final result = _result(
        status: AlarmReconciliationStatus.disabled,
        capabilities: capabilities,
        scheduleWindowStart: scheduleWindowStart,
        scheduleWindowEnd: scheduleWindowEnd,
        alarmCoverageStart: alarmCoverageStart,
        alarmCoverageEnd: alarmCoverageEnd,
      );
      await _postStatusBestEffort(deviceId, result);
      return result;
    }

    try {
      await _alarmRepository.registerCurrentDevice(
        await _alarmRepository.buildCurrentDeviceInfo(),
      );
    } catch (_) {
      // Device registration is diagnostic. Local scheduling can still proceed.
    }

    final schedules = await _alarmRepository.getAlarmWindow(
      scheduleWindowStart,
      scheduleWindowEnd,
    );
    final desiredRecords = _desiredRecords(
      schedules: schedules,
      now: now,
      alarmCoverageEnd: alarmCoverageEnd,
      alarmOffset: settings.alarmOffset,
    );
    final skippedScheduleCount = schedules
        .where((schedule) =>
            !_isDesired(schedule, now, alarmCoverageEnd, settings.alarmOffset))
        .length;

    final existingRecords = await _registryRepository.loadAll();
    final existingByScheduleId = {
      for (final record in existingRecords) record.scheduleId: record,
    };
    final desiredByScheduleId = {
      for (final record in desiredRecords) record.scheduleId: record,
    };

    final staleRecords = existingRecords.where((record) {
      final desired = desiredByScheduleId[record.scheduleId];
      return desired == null || !_recordMatches(record, desired);
    }).toList();
    await _cancelRecords(staleRecords);

    final nativePermission = await _checkNativePermission(capabilities);
    final fallbackPermission = await _fallbackNotificationService
        .checkPermission()
        .catchError((_) => AlarmPermissionState.denied);

    final finalRecords = <ScheduledAlarmRecord>[];
    final failures = <AlarmFailure>[];
    AlarmPermissionIssue? permissionIssue;

    for (final desired in desiredRecords) {
      final existing = existingByScheduleId[desired.scheduleId];
      if (existing != null && _recordMatches(existing, desired)) {
        finalRecords.add(existing);
        continue;
      }

      final scheduled = await _scheduleRecord(
        desired,
        capabilities: capabilities,
        nativePermission: nativePermission,
        fallbackPermission: fallbackPermission,
      );

      if (scheduled.record != null) {
        finalRecords.add(scheduled.record!);
      } else if (scheduled.permissionIssue != null) {
        permissionIssue ??= scheduled.permissionIssue;
      } else {
        failures.add(
          AlarmFailure(
            scheduleId: desired.scheduleId,
            reason: scheduled.failureReason ?? AlarmFailureReason.unknown,
            message: scheduled.message,
          ),
        );
      }
    }

    await _registryRepository.replaceAll(finalRecords);

    final status = _statusFor(
      desiredCount: desiredRecords.length,
      armedCount: finalRecords.length,
      failures: failures,
      permissionIssue: permissionIssue,
      capabilities: capabilities,
      fallbackPermission: fallbackPermission,
    );

    final result = _result(
      status: status,
      permissionIssue: permissionIssue,
      capabilities: _effectiveCapabilities(capabilities, finalRecords),
      armedScheduleIds:
          finalRecords.map((record) => record.scheduleId).toList(),
      skippedScheduleCount: skippedScheduleCount,
      failures: failures,
      scheduleWindowStart: scheduleWindowStart,
      scheduleWindowEnd: scheduleWindowEnd,
      alarmCoverageStart: alarmCoverageStart,
      alarmCoverageEnd: alarmCoverageEnd,
    );

    await _postStatusBestEffort(deviceId, result);
    return result;
  }

  List<ScheduledAlarmRecord> _desiredRecords({
    required List<ScheduleWithPreparationEntity> schedules,
    required DateTime now,
    required DateTime alarmCoverageEnd,
    required Duration alarmOffset,
  }) {
    return schedules
        .where((schedule) =>
            _isDesired(schedule, now, alarmCoverageEnd, alarmOffset))
        .map(
          (schedule) => buildScheduledAlarmRecord(
            schedule,
            alarmOffset: alarmOffset,
            provider: AlarmProvider.none,
          ),
        )
        .toList();
  }

  bool _isDesired(
    ScheduleWithPreparationEntity schedule,
    DateTime now,
    DateTime alarmCoverageEnd,
    Duration alarmOffset,
  ) {
    if (!isAlarmEligibleSchedule(schedule)) return false;
    if (schedule.id.isEmpty) return false;
    final alarmTime = computeAlarmTime(schedule, offset: alarmOffset);
    return alarmTime.isAfter(now) &&
        (alarmTime.isBefore(alarmCoverageEnd) ||
            alarmTime.isAtSameMomentAs(alarmCoverageEnd));
  }

  Future<AlarmPermissionState> _checkNativePermission(
    AlarmSchedulerCapabilities capabilities,
  ) async {
    if (!capabilities.supportsNativeAlarm ||
        capabilities.nativeAlarmProvider == AlarmProvider.none) {
      return AlarmPermissionState.unsupported;
    }
    return _schedulerService
        .checkPermission()
        .catchError((_) => AlarmPermissionState.unsupported);
  }

  Future<_ScheduleAttempt> _scheduleRecord(
    ScheduledAlarmRecord desired, {
    required AlarmSchedulerCapabilities capabilities,
    required AlarmPermissionState nativePermission,
    required AlarmPermissionState fallbackPermission,
  }) async {
    if (capabilities.supportsNativeAlarm &&
        capabilities.nativeAlarmProvider != AlarmProvider.none &&
        nativePermission == AlarmPermissionState.granted) {
      final nativeRecord = desired.copyWith(
        provider: capabilities.nativeAlarmProvider,
      );
      try {
        await _schedulerService.scheduleNativeAlarm(nativeRecord);
        return _ScheduleAttempt(record: nativeRecord);
      } on AlarmSchedulingException catch (error) {
        if (error.permissionIssue == null &&
            fallbackPermission != AlarmPermissionState.granted) {
          return _ScheduleAttempt(
            failureReason: error.reason,
            message: error.message,
          );
        }
      } catch (error) {
        if (fallbackPermission != AlarmPermissionState.granted) {
          return _ScheduleAttempt(
            failureReason: AlarmFailureReason.platformError,
            message: error.toString(),
          );
        }
      }
    }

    if (fallbackPermission == AlarmPermissionState.granted) {
      final fallbackRecord = desired.copyWith(
        provider: AlarmProvider.localNotification,
      );
      try {
        await _fallbackNotificationService.scheduleFallbackAlarm(
          fallbackRecord,
        );
        return _ScheduleAttempt(record: fallbackRecord);
      } on AlarmSchedulingException catch (error) {
        if (error.permissionIssue != null) {
          return _ScheduleAttempt(permissionIssue: error.permissionIssue);
        }
        return _ScheduleAttempt(
          failureReason: error.reason,
          message: error.message,
        );
      } catch (error) {
        return _ScheduleAttempt(
          failureReason: AlarmFailureReason.platformError,
          message: error.toString(),
        );
      }
    }

    if (nativePermission == AlarmPermissionState.denied ||
        nativePermission == AlarmPermissionState.notDetermined) {
      return const _ScheduleAttempt(
        permissionIssue: AlarmPermissionIssue.nativePermissionDenied,
      );
    }
    if (fallbackPermission == AlarmPermissionState.denied ||
        fallbackPermission == AlarmPermissionState.notDetermined) {
      return const _ScheduleAttempt(
        permissionIssue: AlarmPermissionIssue.notificationPermissionDenied,
      );
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
    required AlarmSchedulerCapabilities capabilities,
    required AlarmPermissionState fallbackPermission,
  }) {
    final hasAnyProvider = capabilities.supportsNativeAlarm ||
        fallbackPermission == AlarmPermissionState.granted;
    if (!hasAnyProvider) {
      if (permissionIssue != null) {
        return AlarmReconciliationStatus.permissionNeeded;
      }
      return AlarmReconciliationStatus.unsupported;
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
      fallbackProvider:
          usesFallback ? AlarmProvider.localNotification : AlarmProvider.none,
    );
  }

  bool _recordMatches(
    ScheduledAlarmRecord existing,
    ScheduledAlarmRecord desired,
  ) {
    return existing.scheduleFingerprint == desired.scheduleFingerprint &&
        existing.payload['alarmLaunchPayloadVersion'] ==
            desired.payload['alarmLaunchPayloadVersion'] &&
        existing.alarmTime.isAtSameMomentAs(desired.alarmTime) &&
        existing.preparationStartTime
            .isAtSameMomentAs(desired.preparationStartTime);
  }

  Future<void> _cancelRecords(List<ScheduledAlarmRecord> records) async {
    for (final record in records) {
      try {
        if (record.provider == AlarmProvider.localNotification) {
          await _fallbackNotificationService.cancelFallbackAlarm(record);
        } else if (record.provider != AlarmProvider.none) {
          await _schedulerService.cancelNativeAlarm(record);
        }
      } catch (_) {
        // Keep reconciliation moving; registry replacement is authoritative.
      }
    }
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

  Future<void> _postStatusBestEffort(
    String deviceId,
    AlarmReconciliationResult result,
  ) async {
    try {
      await _alarmRepository.postAlarmStatus(
        AlarmStatusReport(
          deviceId: deviceId,
          reconciledAt: _nowProvider(),
          scheduleWindowStart: result.scheduleWindowStart,
          scheduleWindowEnd: result.scheduleWindowEnd,
          alarmCoverageStart: result.alarmCoverageStart,
          alarmCoverageEnd: result.alarmCoverageEnd,
          status: result.status,
          permissionIssue: result.permissionIssue,
          nativeAlarmProvider: result.nativeAlarmProvider,
          fallbackProvider: result.fallbackProvider,
          armedScheduleCount: result.armedScheduleCount,
          armedScheduleIds: result.armedScheduleIds,
          skippedScheduleCount: result.skippedScheduleCount,
          failures: result.failures,
        ),
      );
    } on DeviceSessionNotActiveException {
      final records = await _registryRepository.loadAll();
      await _cancelRecords(records);
      await _registryRepository.deleteAll();
      await _userRepository?.signOut();
    } catch (_) {
      // Status reports are diagnostic; scheduling result should still return.
    }
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
