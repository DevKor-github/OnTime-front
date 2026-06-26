import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/services/alarm_scheduler_service.dart';
import 'package:on_time_front/core/services/fallback_alarm_notification_service.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/repositories/alarm_repository.dart';
import 'package:on_time_front/domain/use-cases/cancel_all_alarms_use_case.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';
import 'package:on_time_front/presentation/app/cubit/alarm_gate_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'refreshPermission marks unsupported devices as resolved without prompt',
    () async {
      final cubit = _buildCubit(
        scheduler: _FakeAlarmSchedulerService(
          checkPermissionState: AlarmPermissionState.unsupported,
        ),
      );
      addTearDown(cubit.close);

      await cubit.refreshPermission();

      expect(cubit.state, const AlarmGateState.unsupported());
      expect(cubit.state.isResolved, isTrue);
      expect(cubit.state.shouldPrompt, isFalse);
    },
  );

  test(
    'refreshPermission clears dismissal and enables alarms when granted',
    () async {
      SharedPreferences.setMockInitialValues({'alarm_prompt_dismissed': true});
      final repository = _FakeAlarmRepository();
      final reconcile = _FakeReconcileAlarmsUseCase();
      final cubit = _buildCubit(
        scheduler: _FakeAlarmSchedulerService(
          checkPermissionState: AlarmPermissionState.granted,
        ),
        repository: repository,
        reconcile: reconcile,
      );
      addTearDown(cubit.close);

      await cubit.refreshPermission(enableAlarmsOnGrant: true);

      final prefs = await SharedPreferences.getInstance();
      expect(cubit.state, const AlarmGateState.allowed());
      expect(prefs.getBool('alarm_prompt_dismissed'), isNull);
      expect(repository.updatedAlarmSettings, [true]);
      expect(reconcile.callCount, 1);
    },
  );

  test(
    'refreshPermission allows local notification fallback when native alarms are unsupported',
    () async {
      final repository = _FakeAlarmRepository();
      final reconcile = _FakeReconcileAlarmsUseCase();
      final cubit = _buildCubit(
        scheduler: _FakeAlarmSchedulerService(
          capabilities: const AlarmSchedulerCapabilities(
            supportsNativeAlarm: false,
            nativeAlarmProvider: AlarmProvider.none,
            fallbackProvider: AlarmProvider.localNotification,
          ),
        ),
        fallback: _FakeFallbackAlarmNotificationService(
          checkPermissionState: AlarmPermissionState.granted,
        ),
        repository: repository,
        reconcile: reconcile,
      );
      addTearDown(cubit.close);

      await cubit.refreshPermission(enableAlarmsOnGrant: true);

      expect(cubit.state, const AlarmGateState.allowed());
      expect(repository.updatedAlarmSettings, [true]);
      expect(reconcile.callCount, 1);
    },
  );

  test(
    'refreshPermission prompts and disables alarms when permission is denied',
    () async {
      final repository = _FakeAlarmRepository();
      final cancelAll = _FakeCancelAllAlarmsUseCase();
      final cubit = _buildCubit(
        scheduler: _FakeAlarmSchedulerService(
          checkPermissionState: AlarmPermissionState.denied,
        ),
        repository: repository,
        cancelAll: cancelAll,
      );
      addTearDown(cubit.close);

      await cubit.refreshPermission(disableAlarmsWhenPermissionMissing: true);

      expect(cubit.state, const AlarmGateState.required());
      expect(cubit.state.shouldPrompt, isTrue);
      expect(repository.updatedAlarmSettings, [false]);
      expect(cancelAll.callCount, 1);
    },
  );

  test('refreshPermission keeps a dismissed denied prompt dismissed', () async {
    SharedPreferences.setMockInitialValues({'alarm_prompt_dismissed': true});
    final cubit = _buildCubit(
      scheduler: _FakeAlarmSchedulerService(
        checkPermissionState: AlarmPermissionState.denied,
      ),
    );
    addTearDown(cubit.close);

    await cubit.refreshPermission();

    expect(cubit.state, const AlarmGateState.dismissed());
    expect(cubit.state.shouldPrompt, isFalse);
  });

  test(
    'requestPermission grants access, clears dismissal, and enables alarms',
    () async {
      SharedPreferences.setMockInitialValues({'alarm_prompt_dismissed': true});
      final repository = _FakeAlarmRepository();
      final reconcile = _FakeReconcileAlarmsUseCase();
      final cubit = _buildCubit(
        scheduler: _FakeAlarmSchedulerService(
          requestPermissionState: AlarmPermissionState.granted,
        ),
        repository: repository,
        reconcile: reconcile,
      );
      addTearDown(cubit.close);

      final permission = await cubit.requestPermission();

      final prefs = await SharedPreferences.getInstance();
      expect(permission, AlarmPermissionState.granted);
      expect(cubit.state, const AlarmGateState.allowed());
      expect(prefs.getBool('alarm_prompt_dismissed'), isNull);
      expect(repository.updatedAlarmSettings, [true]);
      expect(reconcile.callCount, 1);
    },
  );

  test(
    'requestPermission requests local notification fallback when native alarms are unsupported',
    () async {
      final repository = _FakeAlarmRepository();
      final reconcile = _FakeReconcileAlarmsUseCase();
      final fallback = _FakeFallbackAlarmNotificationService(
        requestPermissionState: AlarmPermissionState.granted,
      );
      final scheduler = _FakeAlarmSchedulerService(
        capabilities: const AlarmSchedulerCapabilities(
          supportsNativeAlarm: false,
          nativeAlarmProvider: AlarmProvider.none,
          fallbackProvider: AlarmProvider.localNotification,
        ),
      );
      final cubit = _buildCubit(
        scheduler: scheduler,
        fallback: fallback,
        repository: repository,
        reconcile: reconcile,
      );
      addTearDown(cubit.close);

      final permission = await cubit.requestPermission();

      expect(permission, AlarmPermissionState.granted);
      expect(cubit.state, const AlarmGateState.allowed());
      expect(scheduler.requestCount, 0);
      expect(fallback.requestCount, 1);
      expect(repository.updatedAlarmSettings, [true]);
      expect(reconcile.callCount, 1);
    },
  );

  test(
    'refreshPermission does not disable alarms when fallback permission is granted',
    () async {
      final repository = _FakeAlarmRepository();
      final cancelAll = _FakeCancelAllAlarmsUseCase();
      final cubit = _buildCubit(
        scheduler: _FakeAlarmSchedulerService(
          checkPermissionState: AlarmPermissionState.denied,
          capabilities: const AlarmSchedulerCapabilities(
            supportsNativeAlarm: true,
            nativeAlarmProvider: AlarmProvider.iosAlarmKit,
            fallbackProvider: AlarmProvider.localNotification,
          ),
        ),
        fallback: _FakeFallbackAlarmNotificationService(
          checkPermissionState: AlarmPermissionState.granted,
        ),
        repository: repository,
        cancelAll: cancelAll,
      );
      addTearDown(cubit.close);

      await cubit.refreshPermission(disableAlarmsWhenPermissionMissing: true);

      expect(cubit.state, const AlarmGateState.allowed());
      expect(repository.updatedAlarmSettings, isEmpty);
      expect(cancelAll.callCount, 0);
    },
  );

  test(
    'requestPermission denial disables alarms and keeps prompt required',
    () async {
      final repository = _FakeAlarmRepository();
      final cancelAll = _FakeCancelAllAlarmsUseCase();
      final cubit = _buildCubit(
        scheduler: _FakeAlarmSchedulerService(
          requestPermissionState: AlarmPermissionState.denied,
        ),
        repository: repository,
        cancelAll: cancelAll,
      );
      addTearDown(cubit.close);

      final permission = await cubit.requestPermission();

      expect(permission, AlarmPermissionState.denied);
      expect(cubit.state, const AlarmGateState.required());
      expect(repository.updatedAlarmSettings, [false]);
      expect(cancelAll.callCount, 1);
    },
  );

  test('dismissPrompt stores dismissal and disables alarms', () async {
    final repository = _FakeAlarmRepository();
    final cancelAll = _FakeCancelAllAlarmsUseCase();
    final cubit = _buildCubit(repository: repository, cancelAll: cancelAll);
    addTearDown(cubit.close);

    await cubit.dismissPrompt();

    final prefs = await SharedPreferences.getInstance();
    expect(cubit.state, const AlarmGateState.dismissed());
    expect(prefs.getBool('alarm_prompt_dismissed'), isTrue);
    expect(repository.updatedAlarmSettings, [false]);
    expect(cancelAll.callCount, 1);
  });

  test(
    'best-effort alarm enable still allows permission state to resolve',
    () async {
      final cubit = _buildCubit(
        scheduler: _FakeAlarmSchedulerService(
          checkPermissionState: AlarmPermissionState.granted,
        ),
        repository: _FakeAlarmRepository(throwOnUpdate: true),
      );
      addTearDown(cubit.close);

      await cubit.refreshPermission(enableAlarmsOnGrant: true);

      expect(cubit.state, const AlarmGateState.allowed());
    },
  );

  test(
    'best-effort alarm disable still records dismissal when cleanup fails',
    () async {
      final cubit = _buildCubit(
        repository: _FakeAlarmRepository(throwOnUpdate: true),
      );
      addTearDown(cubit.close);

      await cubit.dismissPrompt();

      final prefs = await SharedPreferences.getInstance();
      expect(cubit.state, const AlarmGateState.dismissed());
      expect(prefs.getBool('alarm_prompt_dismissed'), isTrue);
    },
  );
}

AlarmGateCubit _buildCubit({
  _FakeAlarmSchedulerService? scheduler,
  _FakeFallbackAlarmNotificationService? fallback,
  _FakeAlarmRepository? repository,
  _FakeReconcileAlarmsUseCase? reconcile,
  _FakeCancelAllAlarmsUseCase? cancelAll,
}) {
  return AlarmGateCubit(
    alarmSchedulerService: scheduler ?? _FakeAlarmSchedulerService(),
    fallbackAlarmNotificationService:
        fallback ?? _FakeFallbackAlarmNotificationService(),
    alarmRepository: repository ?? _FakeAlarmRepository(),
    reconcileAlarmsUseCase: reconcile ?? _FakeReconcileAlarmsUseCase(),
    cancelAllAlarmsUseCase: cancelAll ?? _FakeCancelAllAlarmsUseCase(),
  );
}

class _FakeAlarmSchedulerService extends AlarmSchedulerService {
  _FakeAlarmSchedulerService({
    this.checkPermissionState = AlarmPermissionState.denied,
    this.requestPermissionState = AlarmPermissionState.denied,
    this.capabilities = const AlarmSchedulerCapabilities(
      supportsNativeAlarm: true,
      nativeAlarmProvider: AlarmProvider.androidAlarmManager,
      fallbackProvider: AlarmProvider.none,
    ),
  });

  final AlarmPermissionState checkPermissionState;
  final AlarmPermissionState requestPermissionState;
  final AlarmSchedulerCapabilities capabilities;
  int requestCount = 0;

  @override
  Future<AlarmSchedulerCapabilities> getCapabilities() async => capabilities;

  @override
  Future<AlarmPermissionState> checkPermission() async => checkPermissionState;

  @override
  Future<AlarmPermissionState> requestPermission() async {
    requestCount += 1;
    return requestPermissionState;
  }
}

class _FakeFallbackAlarmNotificationService
    implements FallbackAlarmNotificationService {
  _FakeFallbackAlarmNotificationService({
    this.checkPermissionState = AlarmPermissionState.denied,
    this.requestPermissionState = AlarmPermissionState.denied,
  });

  final AlarmPermissionState checkPermissionState;
  final AlarmPermissionState requestPermissionState;
  int requestCount = 0;

  @override
  Future<AlarmPermissionState> checkPermission() async => checkPermissionState;

  @override
  Future<AlarmPermissionState> requestPermission() async {
    requestCount += 1;
    return requestPermissionState;
  }

  @override
  Future<void> scheduleFallbackAlarm(ScheduledAlarmRecord record) async {}

  @override
  Future<void> cancelFallbackAlarm(ScheduledAlarmRecord record) async {}
}

class _FakeAlarmRepository implements AlarmRepository {
  _FakeAlarmRepository({this.throwOnUpdate = false});

  final bool throwOnUpdate;
  final updatedAlarmSettings = <bool>[];

  @override
  Future<AlarmSettings> updateAlarmSettings({
    required bool alarmsEnabled,
  }) async {
    if (throwOnUpdate) {
      throw Exception('settings unavailable');
    }
    updatedAlarmSettings.add(alarmsEnabled);
    return AlarmSettings(alarmsEnabled: alarmsEnabled);
  }

  @override
  Future<String> getDeviceId() async => 'device-1';

  @override
  Future<AlarmDeviceInfo> buildCurrentDeviceInfo() {
    throw UnimplementedError();
  }

  @override
  Future<AlarmSettings> getAlarmSettings() {
    throw UnimplementedError();
  }

  @override
  Future<List<ScheduleWithPreparationEntity>> getAlarmWindow(
    DateTime startDate,
    DateTime endDate,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> postAlarmStatus(AlarmStatusReport report) {
    throw UnimplementedError();
  }

  @override
  Future<void> registerCurrentDevice(AlarmDeviceInfo deviceInfo) {
    throw UnimplementedError();
  }

  @override
  Future<void> unregisterCurrentDevice(String deviceId) {
    throw UnimplementedError();
  }
}

class _FakeReconcileAlarmsUseCase implements ReconcileAlarmsUseCase {
  int callCount = 0;

  @override
  Future<AlarmReconciliationResult> call() async {
    callCount += 1;
    final now = DateTime(2026, 5, 15);
    return AlarmReconciliationResult(
      status: AlarmReconciliationStatus.armed,
      nativeAlarmProvider: AlarmProvider.androidAlarmManager,
      fallbackProvider: AlarmProvider.localNotification,
      armedScheduleIds: const [],
      skippedScheduleCount: 0,
      failures: const [],
      scheduleWindowStart: now,
      scheduleWindowEnd: now,
      alarmCoverageStart: now,
      alarmCoverageEnd: now,
    );
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCancelAllAlarmsUseCase implements CancelAllAlarmsUseCase {
  int callCount = 0;

  @override
  Future<void> call({bool unregisterDevice = false}) async {
    callCount += 1;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
