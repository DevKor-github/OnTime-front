import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/services/alarm_scheduler_service.dart';
import 'package:on_time_front/core/services/fallback_alarm_notification_service.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/repositories/alarm_registry_repository.dart';
import 'package:on_time_front/domain/repositories/alarm_repository.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';

class FakeAlarmRepository implements AlarmRepository {
  AlarmSettings settings = const AlarmSettings(alarmsEnabled: true);
  bool throwSettings = false;
  bool throwAlarmWindow = false;
  List<ScheduleWithPreparationEntity> schedules = [];
  DateTime? requestedWindowStart;
  DateTime? requestedWindowEnd;
  final updatedSettings = <bool>[];
  int alarmWindowRequestCount = 0;

  @override
  Future<AlarmSettings> getAlarmSettings() async {
    if (throwSettings) {
      throw Exception('settings unavailable');
    }
    return settings;
  }

  @override
  Future<AlarmSettings> updateAlarmSettings({
    required bool alarmsEnabled,
  }) async {
    updatedSettings.add(alarmsEnabled);
    settings = AlarmSettings(alarmsEnabled: alarmsEnabled);
    return settings;
  }

  @override
  Future<List<ScheduleWithPreparationEntity>> getAlarmWindow(
    DateTime startDate,
    DateTime endDate,
  ) async {
    alarmWindowRequestCount += 1;
    if (throwAlarmWindow) {
      throw Exception('alarm window unavailable');
    }
    requestedWindowStart = startDate;
    requestedWindowEnd = endDate;
    return schedules;
  }
}

class FakeAlarmRegistryRepository implements AlarmRegistryRepository {
  List<ScheduledAlarmRecord> records = [];

  @override
  Future<List<ScheduledAlarmRecord>> loadAll() async => List.of(records);

  @override
  Future<void> upsert(ScheduledAlarmRecord record) async {
    records =
        records
            .where((existing) => existing.scheduleId != record.scheduleId)
            .toList()
          ..add(record);
  }

  @override
  Future<void> deleteByScheduleId(String scheduleId) async {
    records = records
        .where((record) => record.scheduleId != scheduleId)
        .toList();
  }

  @override
  Future<void> deleteAll() async {
    records = [];
  }

  @override
  Future<void> replaceAll(List<ScheduledAlarmRecord> records) async {
    this.records = List.of(records);
  }
}

class FakeAlarmSchedulerService implements AlarmSchedulerService {
  AlarmSchedulerCapabilities capabilities = const AlarmSchedulerCapabilities(
    supportsNativeAlarm: true,
    nativeAlarmProvider: AlarmProvider.androidAlarmManager,
  );
  AlarmPermissionState nativePermission = AlarmPermissionState.granted;
  bool throwOnCheckPermission = false;
  final scheduledNative = <ScheduledAlarmRecord>[];
  final canceledNative = <ScheduledAlarmRecord>[];
  final throwOnScheduleIds = <String>{};
  final throwGenericOnScheduleIds = <String>{};
  final throwOnCancelIds = <String>{};

  @override
  Future<AlarmSchedulerCapabilities> getCapabilities() async => capabilities;

  @override
  Future<AlarmPermissionState> checkPermission() async {
    if (throwOnCheckPermission) {
      throw Exception('native permission unavailable');
    }
    return nativePermission;
  }

  @override
  Future<AlarmPermissionState> requestPermission() async => nativePermission;

  @override
  Future<void> scheduleNativeAlarm(ScheduledAlarmRecord record) async {
    if (throwGenericOnScheduleIds.contains(record.scheduleId)) {
      throw Exception('native channel failed');
    }
    if (throwOnScheduleIds.contains(record.scheduleId)) {
      throw const AlarmSchedulingException(
        reason: AlarmFailureReason.platformError,
        message: 'native failure',
      );
    }
    scheduledNative.add(record);
  }

  @override
  Future<void> cancelNativeAlarm(ScheduledAlarmRecord record) async {
    if (throwOnCancelIds.contains(record.scheduleId)) {
      throw Exception('cancel failed');
    }
    canceledNative.add(record);
  }

  @override
  Future<void> cancelAllNativeAlarms(List<ScheduledAlarmRecord> records) async {
    canceledNative.addAll(records);
  }

  @override
  Future<void> initializeLaunchHandling(
    AlarmLaunchPayloadHandler onPayload,
  ) async {}

  @override
  Future<void> dispatchPendingLaunchPayload() async {}
}

class FakeFallbackAlarmNotificationService
    implements FallbackAlarmNotificationService {
  AlarmPermissionState permission = AlarmPermissionState.denied;
  bool throwOnCheckPermission = false;
  final scheduledFallback = <ScheduledAlarmRecord>[];
  final canceledFallback = <ScheduledAlarmRecord>[];
  final throwOnScheduleIds = <String>{};
  final throwPermissionOnScheduleIds = <String>{};
  final throwGenericOnScheduleIds = <String>{};
  final throwOnCancelIds = <String>{};

  @override
  Future<AlarmPermissionState> checkPermission() async {
    if (throwOnCheckPermission) {
      throw Exception('fallback permission unavailable');
    }
    return permission;
  }

  @override
  Future<AlarmPermissionState> requestPermission() async => permission;

  @override
  Future<void> scheduleFallbackAlarm(ScheduledAlarmRecord record) async {
    if (throwPermissionOnScheduleIds.contains(record.scheduleId)) {
      throw const AlarmSchedulingException(
        reason: AlarmFailureReason.platformError,
        permissionIssue: AlarmPermissionIssue.notificationPermissionDenied,
        message: 'notification denied',
      );
    }
    if (throwOnScheduleIds.contains(record.scheduleId)) {
      throw const AlarmSchedulingException(
        reason: AlarmFailureReason.platformError,
        message: 'fallback failed',
      );
    }
    if (throwGenericOnScheduleIds.contains(record.scheduleId)) {
      throw Exception('fallback channel failed');
    }
    scheduledFallback.add(record);
  }

  @override
  Future<void> cancelFallbackAlarm(ScheduledAlarmRecord record) async {
    if (throwOnCancelIds.contains(record.scheduleId)) {
      throw Exception('fallback cancel failed');
    }
    canceledFallback.add(record);
  }
}

void main() {
  late DateTime now;
  late FakeAlarmRepository alarmRepository;
  late FakeAlarmRegistryRepository registryRepository;
  late FakeAlarmSchedulerService schedulerService;
  late FakeFallbackAlarmNotificationService fallbackService;
  late ReconcileAlarmsUseCase useCase;

  setUp(() {
    now = DateTime(2026, 5, 5, 9, 0);
    alarmRepository = FakeAlarmRepository();
    registryRepository = FakeAlarmRegistryRepository();
    schedulerService = FakeAlarmSchedulerService();
    fallbackService = FakeFallbackAlarmNotificationService();
    fallbackService.permission = AlarmPermissionState.granted;
    useCase = ReconcileAlarmsUseCase.test(
      alarmRepository,
      registryRepository,
      schedulerService,
      fallbackService,
      nowProvider: () => now,
    );
  });

  test(
    'requests the full future window and schedules only eligible records',
    () async {
      final eligible = scheduleWithAlarmAt(
        id: 'eligible',
        alarmTime: now.add(const Duration(hours: 1)),
      );
      final past = scheduleWithAlarmAt(
        id: 'past',
        alarmTime: now.subtract(const Duration(minutes: 1)),
      );
      final outsideCoverage = scheduleWithAlarmAt(
        id: 'outside',
        alarmTime: DateTime(now.year + 51, 1, 1),
      );
      final ended = scheduleWithAlarmAt(
        id: 'ended',
        alarmTime: now.add(const Duration(hours: 2)),
        doneStatus: ScheduleDoneStatus.normalEnd,
      );
      alarmRepository.schedules = [eligible, past, outsideCoverage, ended];

      final result = await useCase();

      expect(alarmRepository.requestedWindowStart, now);
      expect(alarmRepository.requestedWindowEnd, DateTime(now.year + 50, 1, 1));
      expect(schedulerService.scheduledNative, isEmpty);
      expect(
        fallbackService.scheduledFallback.map((record) => record.scheduleId),
        ['eligible'],
      );
      expect(result.armedScheduleIds, ['eligible']);
      expect(result.nativeAlarmProvider, AlarmProvider.none);
      expect(result.fallbackProvider, AlarmProvider.localNotification);
      expect(result.skippedScheduleCount, 3);
      expect(result.alarmCoverageEnd, DateTime(now.year + 50, 1, 1));
      expect(registryRepository.records.single.scheduleId, 'eligible');
    },
  );

  test('skips a just-missed alarm instead of scheduling catch-up', () async {
    alarmRepository.schedules = [
      scheduleWithAlarmAt(
        id: 'just-missed',
        alarmTime: now.subtract(const Duration(seconds: 5)),
      ),
    ];

    final result = await useCase();

    expect(result.armedScheduleIds, isEmpty);
    expect(result.skippedScheduleCount, 1);
    expect(schedulerService.scheduledNative, isEmpty);
  });

  test(
    'clears an already armed just-missed alarm instead of scheduling catch-up',
    () async {
      final schedule = scheduleWithAlarmAt(
        id: 'already-fired',
        alarmTime: now.subtract(const Duration(seconds: 5)),
      );
      final existing = buildScheduledAlarmRecord(
        schedule,
        alarmOffset: const Duration(minutes: 5),
        provider: AlarmProvider.androidAlarmManager,
      );
      alarmRepository.schedules = [schedule];
      registryRepository.records = [existing];

      final result = await useCase();

      expect(schedulerService.scheduledNative, isEmpty);
      expect(schedulerService.canceledNative, [existing]);
      expect(registryRepository.records, isEmpty);
      expect(result.armedScheduleIds, isEmpty);
      expect(result.skippedScheduleCount, 1);
    },
  );

  test('android schedule notifications arm beyond 24 hours', () async {
    alarmRepository.schedules = [
      scheduleWithAlarmAt(
        id: 'two-days',
        alarmTime: now.add(const Duration(days: 2)),
      ),
    ];

    final result = await useCase();

    expect(schedulerService.scheduledNative, isEmpty);
    expect(
      fallbackService.scheduledFallback.map((record) => record.scheduleId),
      ['two-days'],
    );
    expect(
      fallbackService.scheduledFallback.single.provider,
      AlarmProvider.localNotification,
    );
    expect(result.nativeAlarmProvider, AlarmProvider.none);
    expect(result.fallbackProvider, AlarmProvider.localNotification);
    expect(result.alarmCoverageEnd, DateTime(now.year + 50, 1, 1));
  });

  test(
    'arms only the nearest 60 future alarms and reports the overflow',
    () async {
      alarmRepository.schedules = [
        for (var index = 60; index >= 0; index--)
          scheduleWithAlarmAt(
            id: 'capacity-$index',
            alarmTime: now.add(Duration(minutes: index + 1)),
          ),
      ];

      final result = await useCase();

      expect(fallbackService.scheduledFallback, hasLength(60));
      expect(fallbackService.scheduledFallback.first.scheduleId, 'capacity-0');
      expect(fallbackService.scheduledFallback.last.scheduleId, 'capacity-59');
      expect(result.armedScheduleIds, hasLength(60));
      expect(result.armedScheduleIds, isNot(contains('capacity-60')));
      expect(result.skippedScheduleCount, 1);
    },
  );

  test('keeps alarm content private unless detailed content is enabled', () {
    final schedule = scheduleWithAlarmAt(
      id: 'private',
      alarmTime: now.add(const Duration(hours: 1)),
      timeZoneId: 'Asia/Seoul',
    );

    final private = buildScheduledAlarmRecord(
      schedule,
      alarmOffset: const Duration(minutes: 5),
      provider: AlarmProvider.localNotification,
      currentTimeZoneId: 'UTC',
    );
    final detailed = buildScheduledAlarmRecord(
      schedule,
      alarmOffset: const Duration(minutes: 5),
      provider: AlarmProvider.localNotification,
      detailedNotificationContent: true,
      currentTimeZoneId: 'UTC',
    );

    expect(private.scheduleTitle, 'OnTime');
    expect(private.payload['detailedNotificationContent'], 'false');
    expect(private.payload, isNot(contains('notificationTimeZone')));
    expect(private.payload, isNot(contains('placeName')));
    expect(detailed.scheduleTitle, 'Schedule private');
    expect(detailed.payload['notificationTimeZone'], 'Asia/Seoul');
  });

  test('coalesces overlapping reconciliation requests', () async {
    alarmRepository.schedules = [
      scheduleWithAlarmAt(
        id: 'eligible',
        alarmTime: now.add(const Duration(hours: 1)),
      ),
    ];

    final results = await Future.wait([useCase(), useCase()]);

    expect(results[0], results[1]);
    expect(alarmRepository.alarmWindowRequestCount, 1);
    expect(schedulerService.scheduledNative, isEmpty);
    expect(fallbackService.scheduledFallback.length, 1);
  });

  test(
    'cancels stale record before rescheduling changed fingerprint',
    () async {
      final changed = scheduleWithAlarmAt(
        id: 'changed',
        alarmTime: now.add(const Duration(hours: 1)),
        preparationName: 'Updated',
      );
      final desiredRecord = buildScheduledAlarmRecord(
        changed,
        alarmOffset: const Duration(minutes: 5),
        provider: AlarmProvider.androidAlarmManager,
      );
      final staleRecord = ScheduledAlarmRecord(
        scheduleId: desiredRecord.scheduleId,
        alarmTime: desiredRecord.alarmTime,
        preparationStartTime: desiredRecord.preparationStartTime,
        scheduleFingerprint: 'old-fingerprint',
        nativeAlarmId: desiredRecord.nativeAlarmId,
        fallbackNotificationId: desiredRecord.fallbackNotificationId,
        provider: AlarmProvider.androidAlarmManager,
        scheduleTitle: desiredRecord.scheduleTitle,
        payload: desiredRecord.payload,
      );
      registryRepository.records = [staleRecord];
      alarmRepository.schedules = [changed];

      await useCase();

      expect(schedulerService.canceledNative.single.scheduleId, 'changed');
      expect(schedulerService.scheduledNative, isEmpty);
      expect(fallbackService.scheduledFallback.single.scheduleId, 'changed');
      expect(
        registryRepository.records.single.provider,
        AlarmProvider.localNotification,
      );
      expect(
        registryRepository.records.single.scheduleFingerprint,
        desiredRecord.scheduleFingerprint,
      );
    },
  );

  test(
    'replaces matching Android native registry record with notification',
    () async {
      final schedule = scheduleWithAlarmAt(
        id: 'already-armed',
        alarmTime: now.add(const Duration(hours: 1)),
      );
      final existing = buildScheduledAlarmRecord(
        schedule,
        alarmOffset: const Duration(minutes: 5),
        provider: AlarmProvider.androidAlarmManager,
      );
      registryRepository.records = [existing];
      alarmRepository.schedules = [schedule];

      final result = await useCase();

      expect(schedulerService.canceledNative, [existing]);
      expect(schedulerService.scheduledNative, isEmpty);
      expect(
        fallbackService.scheduledFallback.single.scheduleId,
        'already-armed',
      );
      expect(
        registryRepository.records.single.provider,
        AlarmProvider.localNotification,
      );
      expect(result.status, AlarmReconciliationStatus.armed);
      expect(result.armedScheduleIds, ['already-armed']);
      expect(result.nativeAlarmProvider, AlarmProvider.none);
      expect(result.fallbackProvider, AlarmProvider.localNotification);
    },
  );

  test(
    'keeps matching fallback registry record when fallback provider is available',
    () async {
      schedulerService.capabilities = const AlarmSchedulerCapabilities(
        supportsNativeAlarm: false,
        nativeAlarmProvider: AlarmProvider.none,
        fallbackProvider: AlarmProvider.localNotification,
      );
      schedulerService.nativePermission = AlarmPermissionState.unsupported;
      fallbackService.permission = AlarmPermissionState.granted;
      final schedule = scheduleWithAlarmAt(
        id: 'already-fallback',
        alarmTime: now.add(const Duration(hours: 1)),
      );
      final existing = buildScheduledAlarmRecord(
        schedule,
        alarmOffset: const Duration(minutes: 5),
        provider: AlarmProvider.localNotification,
      );
      registryRepository.records = [existing];
      alarmRepository.schedules = [schedule];

      final result = await useCase();

      expect(fallbackService.canceledFallback, isEmpty);
      expect(fallbackService.scheduledFallback, isEmpty);
      expect(registryRepository.records, [existing]);
      expect(result.status, AlarmReconciliationStatus.armed);
      expect(result.fallbackProvider, AlarmProvider.localNotification);
    },
  );

  test(
    'reschedules stale record with old alarm launch payload version',
    () async {
      final schedule = scheduleWithAlarmAt(
        id: 'old-payload',
        alarmTime: now.add(const Duration(hours: 1)),
      );
      final desiredRecord = buildScheduledAlarmRecord(
        schedule,
        alarmOffset: const Duration(minutes: 5),
        provider: AlarmProvider.androidAlarmManager,
      );
      final stalePayload = Map<String, String>.from(desiredRecord.payload)
        ..remove('alarmLaunchPayloadVersion');
      final staleRecord = ScheduledAlarmRecord(
        scheduleId: desiredRecord.scheduleId,
        alarmTime: desiredRecord.alarmTime,
        preparationStartTime: desiredRecord.preparationStartTime,
        scheduleFingerprint: desiredRecord.scheduleFingerprint,
        nativeAlarmId: desiredRecord.nativeAlarmId,
        fallbackNotificationId: desiredRecord.fallbackNotificationId,
        provider: AlarmProvider.androidAlarmManager,
        scheduleTitle: desiredRecord.scheduleTitle,
        payload: stalePayload,
      );
      registryRepository.records = [staleRecord];
      alarmRepository.schedules = [schedule];

      await useCase();

      expect(schedulerService.canceledNative.single.scheduleId, 'old-payload');
      expect(schedulerService.scheduledNative, isEmpty);
      expect(
        fallbackService.scheduledFallback.single.scheduleId,
        'old-payload',
      );
      expect(
        registryRepository.records.single.provider,
        AlarmProvider.localNotification,
      );
      expect(
        registryRepository.records.single.payload['alarmLaunchPayloadVersion'],
        alarmLaunchPayloadVersion,
      );
    },
  );

  test(
    'uses local notification fallback when native alarms are unsupported',
    () async {
      schedulerService.capabilities = const AlarmSchedulerCapabilities(
        supportsNativeAlarm: false,
        nativeAlarmProvider: AlarmProvider.none,
        fallbackProvider: AlarmProvider.localNotification,
      );
      schedulerService.nativePermission = AlarmPermissionState.unsupported;
      fallbackService.permission = AlarmPermissionState.granted;
      alarmRepository.schedules = [
        scheduleWithAlarmAt(
          id: 'fallback',
          alarmTime: now.add(const Duration(hours: 1)),
        ),
      ];

      final result = await useCase();

      expect(schedulerService.scheduledNative, isEmpty);
      expect(fallbackService.scheduledFallback.single.scheduleId, 'fallback');
      expect(
        registryRepository.records.single.provider,
        AlarmProvider.localNotification,
      );
      expect(result.status, AlarmReconciliationStatus.armed);
      expect(result.fallbackProvider, AlarmProvider.localNotification);
    },
  );

  test(
    'uses local notification fallback when exact alarm permission is denied',
    () async {
      schedulerService.nativePermission = AlarmPermissionState.denied;
      fallbackService.permission = AlarmPermissionState.granted;
      alarmRepository.schedules = [
        scheduleWithAlarmAt(
          id: 'fallback-permission',
          alarmTime: now.add(const Duration(hours: 1)),
        ),
      ];

      final result = await useCase();

      expect(schedulerService.scheduledNative, isEmpty);
      expect(
        fallbackService.scheduledFallback.single.scheduleId,
        'fallback-permission',
      );
      expect(
        registryRepository.records.single.provider,
        AlarmProvider.localNotification,
      );
      expect(result.status, AlarmReconciliationStatus.armed);
      expect(result.permissionIssue, isNull);
      expect(result.fallbackProvider, AlarmProvider.localNotification);
    },
  );

  test(
    'falls back to local notification when native scheduling fails',
    () async {
      schedulerService.throwOnScheduleIds.add('native-fails');
      fallbackService.permission = AlarmPermissionState.granted;
      alarmRepository.schedules = [
        scheduleWithAlarmAt(
          id: 'native-fails',
          alarmTime: now.add(const Duration(hours: 1)),
        ),
      ];

      final result = await useCase();

      expect(schedulerService.scheduledNative, isEmpty);
      expect(
        fallbackService.scheduledFallback.single.scheduleId,
        'native-fails',
      );
      expect(
        registryRepository.records.single.provider,
        AlarmProvider.localNotification,
      );
      expect(result.status, AlarmReconciliationStatus.armed);
    },
  );

  test(
    'reports notification permission when only fallback delivery is denied',
    () async {
      schedulerService.capabilities = const AlarmSchedulerCapabilities(
        supportsNativeAlarm: false,
        nativeAlarmProvider: AlarmProvider.none,
        fallbackProvider: AlarmProvider.localNotification,
      );
      fallbackService.permission = AlarmPermissionState.denied;
      alarmRepository.schedules = [
        scheduleWithAlarmAt(
          id: 'fallback-denied',
          alarmTime: now.add(const Duration(hours: 1)),
        ),
      ];

      final result = await useCase();

      expect(result.status, AlarmReconciliationStatus.permissionNeeded);
      expect(
        result.permissionIssue,
        AlarmPermissionIssue.notificationPermissionDenied,
      );
      expect(registryRepository.records, isEmpty);
    },
  );

  test(
    'reports permissionNeeded when exact alarm and fallback permissions are denied',
    () async {
      schedulerService.nativePermission = AlarmPermissionState.denied;
      fallbackService.permission = AlarmPermissionState.denied;
      alarmRepository.schedules = [
        scheduleWithAlarmAt(
          id: 'needs-exact-permission',
          alarmTime: now.add(const Duration(hours: 1)),
        ),
      ];

      final result = await useCase();

      expect(schedulerService.scheduledNative, isEmpty);
      expect(fallbackService.scheduledFallback, isEmpty);
      expect(registryRepository.records, isEmpty);
      expect(result.status, AlarmReconciliationStatus.permissionNeeded);
      expect(
        result.permissionIssue,
        AlarmPermissionIssue.notificationPermissionDenied,
      );
    },
  );

  test(
    'does not use notification fallback when fallback provider is disabled',
    () async {
      schedulerService.capabilities = const AlarmSchedulerCapabilities(
        supportsNativeAlarm: true,
        nativeAlarmProvider: AlarmProvider.androidAlarmManager,
        fallbackProvider: AlarmProvider.none,
      );
      schedulerService.nativePermission = AlarmPermissionState.denied;
      fallbackService.permission = AlarmPermissionState.granted;
      alarmRepository.schedules = [
        scheduleWithAlarmAt(
          id: 'native-only',
          alarmTime: now.add(const Duration(hours: 1)),
        ),
      ];

      final result = await useCase();

      expect(schedulerService.scheduledNative, isEmpty);
      expect(fallbackService.scheduledFallback, isEmpty);
      expect(result.status, AlarmReconciliationStatus.unsupported);
      expect(result.permissionIssue, isNull);
      expect(result.fallbackProvider, AlarmProvider.none);
    },
  );

  test(
    'settingsUnavailable reports without canceling existing registry',
    () async {
      alarmRepository.throwSettings = true;
      final existing = buildScheduledAlarmRecord(
        scheduleWithAlarmAt(
          id: 'existing',
          alarmTime: now.add(const Duration(hours: 1)),
        ),
        alarmOffset: const Duration(minutes: 5),
        provider: AlarmProvider.androidAlarmManager,
      );
      registryRepository.records = [existing];

      final result = await useCase();

      expect(result.status, AlarmReconciliationStatus.settingsUnavailable);
      expect(schedulerService.canceledNative, isEmpty);
      expect(registryRepository.records, [existing]);
    },
  );

  test('alarm window failure reports partial without throwing', () async {
    alarmRepository.throwAlarmWindow = true;

    final result = await useCase();

    expect(result.status, AlarmReconciliationStatus.partial);
    expect(
      result.failures.single.reason,
      AlarmFailureReason.preparationLoadFailed,
    );
    expect(
      result.failures.single.message,
      contains('alarm window unavailable'),
    );
    expect(registryRepository.records, isEmpty);
  });

  test(
    'global disabled cancels all local alarms and clears registry',
    () async {
      alarmRepository.settings = const AlarmSettings(alarmsEnabled: false);
      final native = buildScheduledAlarmRecord(
        scheduleWithAlarmAt(
          id: 'native',
          alarmTime: now.add(const Duration(hours: 1)),
        ),
        alarmOffset: const Duration(minutes: 5),
        provider: AlarmProvider.androidAlarmManager,
      );
      final fallback = buildScheduledAlarmRecord(
        scheduleWithAlarmAt(
          id: 'fallback',
          alarmTime: now.add(const Duration(hours: 2)),
        ),
        alarmOffset: const Duration(minutes: 5),
        provider: AlarmProvider.localNotification,
      );
      registryRepository.records = [native, fallback];

      final result = await useCase();

      expect(result.status, AlarmReconciliationStatus.disabled);
      expect(schedulerService.canceledNative, [native]);
      expect(fallbackService.canceledFallback, [fallback]);
      expect(registryRepository.records, isEmpty);
    },
  );

  test(
    'reports partial when scheduling a desired notification fails',
    () async {
      final failing = scheduleWithAlarmAt(
        id: 'failing',
        alarmTime: now.add(const Duration(hours: 1)),
      );
      alarmRepository.schedules = [failing];
      fallbackService.throwOnScheduleIds.add('failing');

      final result = await useCase();

      expect(result.status, AlarmReconciliationStatus.partial);
      expect(result.failures.single.scheduleId, 'failing');
      expect(result.failures.single.reason, AlarmFailureReason.platformError);
      expect(registryRepository.records, isEmpty);
    },
  );

  test(
    'notification permission is reported when fallback notification is unavailable',
    () async {
      final failing = scheduleWithAlarmAt(
        id: 'notification-unavailable',
        alarmTime: now.add(const Duration(hours: 1)),
      );
      alarmRepository.schedules = [failing];
      fallbackService.permission = AlarmPermissionState.denied;

      final result = await useCase();

      expect(result.status, AlarmReconciliationStatus.permissionNeeded);
      expect(
        result.permissionIssue,
        AlarmPermissionIssue.notificationPermissionDenied,
      );
      expect(result.failures, isEmpty);
    },
  );

  test(
    'fallback scheduling failures become permission or partial reports',
    () async {
      schedulerService.capabilities = const AlarmSchedulerCapabilities(
        supportsNativeAlarm: false,
        nativeAlarmProvider: AlarmProvider.none,
        fallbackProvider: AlarmProvider.localNotification,
      );
      fallbackService.permission = AlarmPermissionState.granted;
      alarmRepository.schedules = [
        scheduleWithAlarmAt(
          id: 'fallback-permission-fails',
          alarmTime: now.add(const Duration(hours: 1)),
        ),
      ];
      fallbackService.throwPermissionOnScheduleIds.add(
        'fallback-permission-fails',
      );

      final permissionResult = await useCase();

      expect(
        permissionResult.status,
        AlarmReconciliationStatus.permissionNeeded,
      );
      expect(
        permissionResult.permissionIssue,
        AlarmPermissionIssue.notificationPermissionDenied,
      );

      fallbackService.throwPermissionOnScheduleIds.clear();
      fallbackService.throwGenericOnScheduleIds.add(
        'fallback-permission-fails',
      );
      final partialResult = await useCase();

      expect(partialResult.status, AlarmReconciliationStatus.partial);
      expect(
        partialResult.failures.single.message,
        contains('fallback channel'),
      );
    },
  );

  test(
    'fallback alarm scheduling exceptions without permission issue are partial failures',
    () async {
      schedulerService.capabilities = const AlarmSchedulerCapabilities(
        supportsNativeAlarm: false,
        nativeAlarmProvider: AlarmProvider.none,
        fallbackProvider: AlarmProvider.localNotification,
      );
      fallbackService.permission = AlarmPermissionState.granted;
      alarmRepository.schedules = [
        scheduleWithAlarmAt(
          id: 'fallback-platform-fails',
          alarmTime: now.add(const Duration(hours: 1)),
        ),
      ];
      fallbackService.throwOnScheduleIds.add('fallback-platform-fails');

      final result = await useCase();

      expect(result.status, AlarmReconciliationStatus.partial);
      expect(result.permissionIssue, isNull);
      expect(result.failures.single.scheduleId, 'fallback-platform-fails');
      expect(result.failures.single.reason, AlarmFailureReason.platformError);
      expect(result.failures.single.message, 'fallback failed');
      expect(registryRepository.records, isEmpty);
    },
  );

  test(
    'unsupported local providers return unsupported without throwing',
    () async {
      schedulerService.capabilities = const AlarmSchedulerCapabilities(
        supportsNativeAlarm: false,
        nativeAlarmProvider: AlarmProvider.none,
        fallbackProvider: AlarmProvider.none,
      );
      schedulerService.nativePermission = AlarmPermissionState.unsupported;
      fallbackService.permission = AlarmPermissionState.unsupported;
      alarmRepository.schedules = [
        scheduleWithAlarmAt(
          id: 'unsupported',
          alarmTime: now.add(const Duration(hours: 1)),
        ),
      ];

      final result = await useCase();

      expect(result.status, AlarmReconciliationStatus.unsupported);
      expect(registryRepository.records, isEmpty);
    },
  );

  test(
    'permission check failures degrade to denied or unsupported states',
    () async {
      schedulerService.throwOnCheckPermission = true;
      fallbackService
        ..permission = AlarmPermissionState.granted
        ..throwOnCheckPermission = true;
      alarmRepository.schedules = [
        scheduleWithAlarmAt(
          id: 'permission-check-fails',
          alarmTime: now.add(const Duration(hours: 1)),
        ),
      ];

      final result = await useCase();

      expect(result.status, AlarmReconciliationStatus.permissionNeeded);
      expect(
        result.permissionIssue,
        AlarmPermissionIssue.notificationPermissionDenied,
      );
    },
  );

  test('cancel failures do not block registry replacement', () async {
    final staleNative = buildScheduledAlarmRecord(
      scheduleWithAlarmAt(
        id: 'stale-native',
        alarmTime: now.add(const Duration(hours: 1)),
      ),
      alarmOffset: const Duration(minutes: 5),
      provider: AlarmProvider.androidAlarmManager,
    );
    final staleFallback = buildScheduledAlarmRecord(
      scheduleWithAlarmAt(
        id: 'stale-fallback',
        alarmTime: now.add(const Duration(hours: 2)),
      ),
      alarmOffset: const Duration(minutes: 5),
      provider: AlarmProvider.localNotification,
    );
    schedulerService.throwOnCancelIds.add('stale-native');
    fallbackService.throwOnCancelIds.add('stale-fallback');
    registryRepository.records = [staleNative, staleFallback];

    final result = await useCase();

    expect(result.status, AlarmReconciliationStatus.armed);
    expect(registryRepository.records, isEmpty);
  });
}

ScheduleWithPreparationEntity scheduleWithAlarmAt({
  required String id,
  required DateTime alarmTime,
  ScheduleDoneStatus doneStatus = ScheduleDoneStatus.notEnded,
  String preparationName = 'Shower',
  String timeZoneId = 'UTC',
}) {
  const offset = Duration(minutes: 5);
  const moveTime = Duration(minutes: 10);
  const spareTime = Duration(minutes: 5);
  const preparationTime = Duration(minutes: 30);
  final preparationStartTime = alarmTime.add(offset);
  final scheduleTime = preparationStartTime.add(
    moveTime + spareTime + preparationTime,
  );
  return ScheduleWithPreparationEntity(
    id: id,
    place: const PlaceEntity(id: 'place-1', placeName: 'Office'),
    scheduleName: 'Schedule $id',
    timeZoneId: timeZoneId,
    scheduleTime: scheduleTime,
    moveTime: moveTime,
    isChanged: false,
    isStarted: false,
    scheduleSpareTime: spareTime,
    scheduleNote: '',
    doneStatus: doneStatus,
    preparation: PreparationWithTimeEntity.fromPreparation(
      PreparationEntity(
        preparationStepList: [
          PreparationStepEntity(
            id: 'step-$id',
            preparationName: preparationName,
            preparationTime: preparationTime,
          ),
        ],
      ),
    ),
  );
}
