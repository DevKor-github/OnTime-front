import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/core/services/alarm_scheduler_service.dart';
import 'package:on_time_front/core/services/fallback_alarm_notification_service.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/repositories/alarm_registry_repository.dart';
import 'package:on_time_front/domain/repositories/alarm_repository.dart';
import 'package:on_time_front/domain/use-cases/cancel_all_alarms_use_case.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/alarm_allow/screens/alarm_allow_screen.dart';
import 'package:on_time_front/presentation/app/cubit/alarm_gate_cubit.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows English precise notification permission rationale', (
    tester,
  ) async {
    final harness = await _pumpAlarmAllowScreen(
      tester,
      locale: const Locale('en'),
      permissionAfterRequest: AlarmPermissionState.denied,
    );
    addTearDown(harness.dispose);

    expect(
      find.text(
        'OnTime needs this permission to notify you at the exact time to start preparing.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('granted precise notification permission enables notifications', (
    tester,
  ) async {
    final harness = await _pumpAlarmAllowScreen(
      tester,
      permissionAfterRequest: AlarmPermissionState.granted,
    );
    addTearDown(harness.dispose);

    await tester.tap(find.text('Allow precise notifications'));
    await tester.pumpAndSettle();

    expect(harness.scheduler.requestCount, 1);
    expect(harness.repository.updatedSettings, [true]);
    expect(harness.reconcileUseCase.callCount, 1);
    expect(find.text('home'), findsOneWidget);
    expect(harness.gateCubit.state.status, AlarmGateStatus.allowed);
  });

  testWidgets('uses alarm language for iOS AlarmKit capability', (
    tester,
  ) async {
    final harness = await _pumpAlarmAllowScreen(
      tester,
      locale: const Locale('en'),
      capabilities: const AlarmSchedulerCapabilities(
        supportsNativeAlarm: true,
        nativeAlarmProvider: AlarmProvider.iosAlarmKit,
        fallbackProvider: AlarmProvider.localNotification,
      ),
      permissionAfterRequest: AlarmPermissionState.denied,
    );
    addTearDown(harness.dispose);

    expect(find.text('Please allow alarms'), findsOneWidget);
    expect(find.text('Allow alarms'), findsOneWidget);
  });

  testWidgets('dismiss keeps notification delivery when fallback is available', (
    tester,
  ) async {
    final harness = await _pumpAlarmAllowScreen(
      tester,
      permissionAfterRequest: AlarmPermissionState.denied,
    );
    addTearDown(harness.dispose);

    await tester.tap(find.text("I'll do it later."));
    await tester.pumpAndSettle();

    expect(harness.repository.updatedSettings, isEmpty);
    expect(harness.cancelAllUseCase.callCount, 0);
    expect(find.text('home'), findsOneWidget);
    expect(harness.gateCubit.state.status, AlarmGateStatus.dismissed);
  });
}

Future<_AlarmAllowHarness> _pumpAlarmAllowScreen(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  required AlarmPermissionState permissionAfterRequest,
  AlarmSchedulerCapabilities capabilities = const AlarmSchedulerCapabilities(
    supportsNativeAlarm: true,
    nativeAlarmProvider: AlarmProvider.androidAlarmManager,
    fallbackProvider: AlarmProvider.localNotification,
  ),
}) async {
  final repository = _FakeAlarmRepository();
  final registry = _FakeAlarmRegistry();
  final scheduler = _FakeAlarmSchedulerService(
    capabilities: capabilities,
    permissionAfterRequest: permissionAfterRequest,
  );
  final fallback = _FakeFallbackAlarmNotificationService();
  final reconcileUseCase = _FakeReconcileAlarmsUseCase(
    repository,
    registry,
    scheduler,
    fallback,
  );
  final cancelAllUseCase = _FakeCancelAllAlarmsUseCase(
    repository,
    registry,
    scheduler,
    fallback,
  );
  final gateCubit = AlarmGateCubit(
    alarmSchedulerService: scheduler,
    fallbackAlarmNotificationService: fallback,
    alarmRepository: repository,
    reconcileAlarmsUseCase: reconcileUseCase,
    cancelAllAlarmsUseCase: cancelAllUseCase,
  );
  final router = GoRouter(
    initialLocation: '/allowAlarm',
    routes: [
      GoRoute(
        path: '/allowAlarm',
        builder: (context, state) => BlocProvider<AlarmGateCubit>.value(
          value: gateCubit,
          child: const AlarmAllowScreen(),
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(body: Text('home')),
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(
      theme: themeData,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
  await tester.pumpAndSettle();

  return _AlarmAllowHarness(
    gateCubit: gateCubit,
    router: router,
    repository: repository,
    scheduler: scheduler,
    reconcileUseCase: reconcileUseCase,
    cancelAllUseCase: cancelAllUseCase,
  );
}

class _AlarmAllowHarness {
  _AlarmAllowHarness({
    required this.gateCubit,
    required this.router,
    required this.repository,
    required this.scheduler,
    required this.reconcileUseCase,
    required this.cancelAllUseCase,
  });

  final AlarmGateCubit gateCubit;
  final GoRouter router;
  final _FakeAlarmRepository repository;
  final _FakeAlarmSchedulerService scheduler;
  final _FakeReconcileAlarmsUseCase reconcileUseCase;
  final _FakeCancelAllAlarmsUseCase cancelAllUseCase;

  void dispose() {
    gateCubit.close();
    router.dispose();
  }
}

class _FakeAlarmSchedulerService extends AlarmSchedulerService {
  _FakeAlarmSchedulerService({
    required this.capabilities,
    required this.permissionAfterRequest,
  });

  final AlarmSchedulerCapabilities capabilities;
  AlarmPermissionState permissionAfterRequest;
  int requestCount = 0;

  @override
  Future<AlarmSchedulerCapabilities> getCapabilities() async {
    return capabilities;
  }

  @override
  Future<AlarmPermissionState> checkPermission() async {
    return permissionAfterRequest;
  }

  @override
  Future<AlarmPermissionState> requestPermission() async {
    requestCount += 1;
    return permissionAfterRequest;
  }
}

class _FakeReconcileAlarmsUseCase extends ReconcileAlarmsUseCase {
  // ignore: use_super_parameters
  _FakeReconcileAlarmsUseCase(
    AlarmRepository alarmRepository,
    AlarmRegistryRepository registryRepository,
    AlarmSchedulerService schedulerService,
    FallbackAlarmNotificationService fallbackNotificationService,
  ) : super.test(
        alarmRepository,
        registryRepository,
        schedulerService,
        fallbackNotificationService,
        nowProvider: () => DateTime(2026),
      );

  int callCount = 0;

  @override
  Future<AlarmReconciliationResult> call() async {
    callCount += 1;
    return AlarmReconciliationResult(
      status: AlarmReconciliationStatus.armed,
      nativeAlarmProvider: AlarmProvider.androidAlarmManager,
      fallbackProvider: AlarmProvider.localNotification,
      armedScheduleIds: const [],
      skippedScheduleCount: 0,
      failures: const [],
      scheduleWindowStart: DateTime(2026),
      scheduleWindowEnd: DateTime(2026),
      alarmCoverageStart: DateTime(2026),
      alarmCoverageEnd: DateTime(2026),
    );
  }
}

class _FakeCancelAllAlarmsUseCase extends CancelAllAlarmsUseCase {
  // ignore: use_super_parameters
  _FakeCancelAllAlarmsUseCase(
    AlarmRepository alarmRepository,
    AlarmRegistryRepository registryRepository,
    AlarmSchedulerService schedulerService,
    FallbackAlarmNotificationService fallbackNotificationService,
  ) : super(
        alarmRepository,
        registryRepository,
        schedulerService,
        fallbackNotificationService,
      );

  int callCount = 0;

  @override
  Future<void> call({bool unregisterDevice = false}) async {
    callCount += 1;
  }
}

class _FakeAlarmRepository implements AlarmRepository {
  final updatedSettings = <bool>[];

  @override
  Future<AlarmSettings> getAlarmSettings() async {
    return const AlarmSettings(alarmsEnabled: true);
  }

  @override
  Future<AlarmSettings> updateAlarmSettings({
    required bool alarmsEnabled,
  }) async {
    updatedSettings.add(alarmsEnabled);
    return AlarmSettings(alarmsEnabled: alarmsEnabled);
  }

  @override
  Future<String> getDeviceId() async => 'device-id';

  @override
  Future<AlarmDeviceInfo> buildCurrentDeviceInfo() async {
    return const AlarmDeviceInfo(
      deviceId: 'device-id',
      platform: 'test',
      appVersion: '1.0.0',
      osVersion: 'test',
      supportsNativeAlarm: true,
      nativeAlarmProvider: AlarmProvider.androidAlarmManager,
      fallbackProvider: AlarmProvider.localNotification,
    );
  }

  @override
  Future<List<ScheduleWithPreparationEntity>> getAlarmWindow(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return const [];
  }

  @override
  Future<void> postAlarmStatus(AlarmStatusReport report) async {}

  @override
  Future<void> registerCurrentDevice(AlarmDeviceInfo deviceInfo) async {}

  @override
  Future<void> unregisterCurrentDevice(String deviceId) async {}
}

class _FakeAlarmRegistry implements AlarmRegistryRepository {
  @override
  Future<List<ScheduledAlarmRecord>> loadAll() async => const [];

  @override
  Future<void> upsert(ScheduledAlarmRecord record) async {}

  @override
  Future<void> deleteByScheduleId(String scheduleId) async {}

  @override
  Future<void> deleteAll() async {}

  @override
  Future<void> replaceAll(List<ScheduledAlarmRecord> records) async {}
}

class _FakeFallbackAlarmNotificationService
    implements FallbackAlarmNotificationService {
  @override
  Future<AlarmPermissionState> checkPermission() async {
    return AlarmPermissionState.granted;
  }

  @override
  Future<AlarmPermissionState> requestPermission() async {
    return AlarmPermissionState.granted;
  }

  @override
  Future<void> scheduleFallbackAlarm(ScheduledAlarmRecord record) async {}

  @override
  Future<void> cancelFallbackAlarm(ScheduledAlarmRecord record) async {}
}
