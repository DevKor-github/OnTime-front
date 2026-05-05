import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:on_time_front/core/services/alarm_scheduler_service.dart';
import 'package:on_time_front/core/services/fallback_alarm_notification_service.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/repositories/alarm_registry_repository.dart';
import 'package:on_time_front/domain/repositories/alarm_repository.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';

class FakeAlarmRepository implements AlarmRepository {
  AlarmSettings settings = const AlarmSettings(alarmsEnabled: true);
  bool throwSettings = false;
  List<ScheduleWithPreparationEntity> schedules = [];
  DateTime? requestedWindowStart;
  DateTime? requestedWindowEnd;
  final statusReports = <AlarmStatusReport>[];
  final registeredDevices = <AlarmDeviceInfo>[];
  final updatedSettings = <bool>[];
  bool throwDeviceSessionNotActiveOnStatus = false;
  int alarmWindowRequestCount = 0;

  @override
  Future<String> getDeviceId() async => 'device-1';

  @override
  Future<AlarmDeviceInfo> buildCurrentDeviceInfo() async {
    return const AlarmDeviceInfo(
      deviceId: 'device-1',
      platform: 'android',
      appVersion: '1.0.0',
      osVersion: 'android',
      supportsNativeAlarm: true,
      nativeAlarmProvider: AlarmProvider.androidAlarmManager,
      fallbackProvider: AlarmProvider.localNotification,
    );
  }

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
  Future<void> registerCurrentDevice(AlarmDeviceInfo deviceInfo) async {
    registeredDevices.add(deviceInfo);
  }

  @override
  Future<void> unregisterCurrentDevice(String deviceId) async {}

  @override
  Future<List<ScheduleWithPreparationEntity>> getAlarmWindow(
    DateTime startDate,
    DateTime endDate,
  ) async {
    alarmWindowRequestCount += 1;
    requestedWindowStart = startDate;
    requestedWindowEnd = endDate;
    return schedules;
  }

  @override
  Future<void> postAlarmStatus(AlarmStatusReport report) async {
    if (throwDeviceSessionNotActiveOnStatus) {
      throw const DeviceSessionNotActiveException();
    }
    statusReports.add(report);
  }
}

class FakeAlarmRegistryRepository implements AlarmRegistryRepository {
  List<ScheduledAlarmRecord> records = [];

  @override
  Future<List<ScheduledAlarmRecord>> loadAll() async => List.of(records);

  @override
  Future<void> upsert(ScheduledAlarmRecord record) async {
    records = records
        .where((existing) => existing.scheduleId != record.scheduleId)
        .toList()
      ..add(record);
  }

  @override
  Future<void> deleteByScheduleId(String scheduleId) async {
    records =
        records.where((record) => record.scheduleId != scheduleId).toList();
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
  final scheduledNative = <ScheduledAlarmRecord>[];
  final canceledNative = <ScheduledAlarmRecord>[];
  final throwOnScheduleIds = <String>{};

  @override
  Future<AlarmSchedulerCapabilities> getCapabilities() async => capabilities;

  @override
  Future<AlarmPermissionState> checkPermission() async => nativePermission;

  @override
  Future<AlarmPermissionState> requestPermission() async => nativePermission;

  @override
  Future<void> scheduleNativeAlarm(ScheduledAlarmRecord record) async {
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
    canceledNative.add(record);
  }

  @override
  Future<void> cancelAllNativeAlarms(
    List<ScheduledAlarmRecord> records,
  ) async {
    canceledNative.addAll(records);
  }

  @override
  Future<void> initializeLaunchHandling(
    AlarmLaunchPayloadHandler onPayload,
  ) async {}
}

class FakeFallbackAlarmNotificationService
    implements FallbackAlarmNotificationService {
  AlarmPermissionState permission = AlarmPermissionState.denied;
  final scheduledFallback = <ScheduledAlarmRecord>[];
  final canceledFallback = <ScheduledAlarmRecord>[];

  @override
  Future<AlarmPermissionState> checkPermission() async => permission;

  @override
  Future<AlarmPermissionState> requestPermission() async => permission;

  @override
  Future<void> scheduleFallbackAlarm(ScheduledAlarmRecord record) async {
    scheduledFallback.add(record);
  }

  @override
  Future<void> cancelFallbackAlarm(ScheduledAlarmRecord record) async {
    canceledFallback.add(record);
  }
}

class FakeUserRepository implements UserRepository {
  bool signedOut = false;

  @override
  Stream<UserEntity> get userStream => const Stream.empty();

  @override
  GoogleSignIn get googleSignIn => throw UnimplementedError();

  @override
  Future<void> signOut() async {
    signedOut = true;
  }

  @override
  Future<void> deleteAppleUser() => throw UnimplementedError();

  @override
  Future<void> deleteGoogleUser() => throw UnimplementedError();

  @override
  Future<void> deleteUser() => throw UnimplementedError();

  @override
  Future<void> disconnectGoogleSignIn() => throw UnimplementedError();

  @override
  Future<void> getUser() => throw UnimplementedError();

  @override
  Future<String?> getUserSocialType() => throw UnimplementedError();

  @override
  Future<void> postFeedback(String message) => throw UnimplementedError();

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> signInWithApple({
    required String idToken,
    required String authCode,
    required String fullName,
    String? email,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> signInWithGoogle(GoogleSignInAccount account) =>
      throw UnimplementedError();

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
  }) =>
      throw UnimplementedError();
}

void main() {
  late DateTime now;
  late FakeAlarmRepository alarmRepository;
  late FakeAlarmRegistryRepository registryRepository;
  late FakeAlarmSchedulerService schedulerService;
  late FakeFallbackAlarmNotificationService fallbackService;
  late FakeUserRepository userRepository;
  late ReconcileAlarmsUseCase useCase;

  setUp(() {
    now = DateTime(2026, 5, 5, 9, 0);
    alarmRepository = FakeAlarmRepository();
    registryRepository = FakeAlarmRegistryRepository();
    schedulerService = FakeAlarmSchedulerService();
    fallbackService = FakeFallbackAlarmNotificationService();
    userRepository = FakeUserRepository();
    useCase = ReconcileAlarmsUseCase.test(
      alarmRepository,
      registryRepository,
      schedulerService,
      fallbackService,
      nowProvider: () => now,
      userRepository: userRepository,
    );
  });

  test('requests padded window and schedules only eligible 7-day alarms',
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
      alarmTime: now.add(const Duration(days: 7, minutes: 1)),
    );
    final ended = scheduleWithAlarmAt(
      id: 'ended',
      alarmTime: now.add(const Duration(hours: 2)),
      doneStatus: ScheduleDoneStatus.normalEnd,
    );
    alarmRepository.schedules = [
      eligible,
      past,
      outsideCoverage,
      ended,
    ];

    final result = await useCase();

    expect(alarmRepository.requestedWindowStart, now);
    expect(
      alarmRepository.requestedWindowEnd,
      now.add(const Duration(days: 8)),
    );
    expect(
      schedulerService.scheduledNative.map((record) => record.scheduleId),
      ['eligible'],
    );
    expect(result.armedScheduleIds, ['eligible']);
    expect(result.nativeAlarmProvider, AlarmProvider.androidAlarmManager);
    expect(result.fallbackProvider, AlarmProvider.none);
    expect(alarmRepository.statusReports.single.nativeAlarmProvider,
        AlarmProvider.androidAlarmManager);
    expect(alarmRepository.statusReports.single.fallbackProvider,
        AlarmProvider.none);
    expect(result.skippedScheduleCount, 3);
    expect(result.alarmCoverageEnd, now.add(const Duration(days: 7)));
    expect(registryRepository.records.single.scheduleId, 'eligible');
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
    expect(alarmRepository.registeredDevices.length, 1);
    expect(alarmRepository.statusReports.length, 1);
    expect(schedulerService.scheduledNative.length, 1);
  });

  test('cancels stale record before rescheduling changed fingerprint',
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
    expect(schedulerService.scheduledNative.single.scheduleId, 'changed');
    expect(
      registryRepository.records.single.scheduleFingerprint,
      desiredRecord.scheduleFingerprint,
    );
  });

  test('uses local notification fallback when native alarms are unsupported',
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
  });

  test('settingsUnavailable reports without canceling existing registry',
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
    expect(alarmRepository.statusReports.single.status,
        AlarmReconciliationStatus.settingsUnavailable);
  });

  test('global disabled cancels all local alarms and clears registry',
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
  });

  test('reports partial when scheduling a desired alarm fails', () async {
    final failing = scheduleWithAlarmAt(
      id: 'failing',
      alarmTime: now.add(const Duration(hours: 1)),
    );
    alarmRepository.schedules = [failing];
    schedulerService.throwOnScheduleIds.add('failing');
    fallbackService.permission = AlarmPermissionState.denied;

    final result = await useCase();

    expect(result.status, AlarmReconciliationStatus.partial);
    expect(result.failures.single.scheduleId, 'failing');
    expect(result.failures.single.reason, AlarmFailureReason.platformError);
    expect(registryRepository.records, isEmpty);
  });

  test('session invalidation cancels alarms, clears registry, and signs out',
      () async {
    final existing = buildScheduledAlarmRecord(
      scheduleWithAlarmAt(
        id: 'old-device',
        alarmTime: now.add(const Duration(hours: 1)),
      ),
      alarmOffset: const Duration(minutes: 5),
      provider: AlarmProvider.androidAlarmManager,
    );
    registryRepository.records = [existing];
    alarmRepository.throwDeviceSessionNotActiveOnStatus = true;

    await useCase();

    expect(schedulerService.canceledNative, [existing]);
    expect(registryRepository.records, isEmpty);
    expect(userRepository.signedOut, isTrue);
  });
}

ScheduleWithPreparationEntity scheduleWithAlarmAt({
  required String id,
  required DateTime alarmTime,
  ScheduleDoneStatus doneStatus = ScheduleDoneStatus.notEnded,
  String preparationName = 'Shower',
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
