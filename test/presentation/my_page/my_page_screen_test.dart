import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/core/constants/local_profile.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/core/services/alarm_scheduler_service.dart';
import 'package:on_time_front/core/services/detailed_notification_preference_service.dart';
import 'package:on_time_front/core/services/fallback_alarm_notification_service.dart';
import 'package:on_time_front/core/services/notification_service.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/repositories/alarm_registry_repository.dart';
import 'package:on_time_front/domain/repositories/alarm_repository.dart';
import 'package:on_time_front/domain/use-cases/cancel_all_alarms_use_case.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/my_page/my_page_screen.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late _FakeAlarmRepository alarmRepository;
  late _FakeAlarmRegistry alarmRegistry;
  late _FakeAlarmSchedulerService scheduler;
  late _FakeFallbackAlarmNotificationService fallback;
  late _FakeReconcileAlarmsUseCase reconcile;
  late _FakeCancelAllAlarmsUseCase cancelAll;

  setUp(() async {
    await getIt.reset();
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.userDao.putUser(
      const UserEntity(
        id: localProfileId,
        spareTime: Duration(minutes: 10),
        note: '',
      ),
    );
    alarmRepository = _FakeAlarmRepository();
    alarmRegistry = _FakeAlarmRegistry();
    scheduler = _FakeAlarmSchedulerService();
    fallback = _FakeFallbackAlarmNotificationService();
    reconcile = _FakeReconcileAlarmsUseCase(
      alarmRepository,
      alarmRegistry,
      scheduler,
      fallback,
    );
    cancelAll = _FakeCancelAllAlarmsUseCase(alarmRegistry, scheduler, fallback);
    getIt
      ..registerSingleton<DetailedNotificationPreferenceService>(
        DetailedNotificationPreferenceService(database),
      )
      ..registerSingleton<AlarmRepository>(alarmRepository)
      ..registerSingleton<AlarmRegistryRepository>(alarmRegistry)
      ..registerSingleton<AlarmSchedulerService>(scheduler)
      ..registerSingleton<FallbackAlarmNotificationService>(fallback)
      ..registerSingleton<ReconcileAlarmsUseCase>(reconcile)
      ..registerSingleton<CancelAllAlarmsUseCase>(cancelAll);
  });

  tearDown(() async {
    await database.close();
    await getIt.reset();
  });

  testWidgets('shows only local data and device settings', (tester) async {
    await _pumpMyPage(tester);

    expect(find.text('My Page'), findsOneWidget);
    expect(find.text('백업, 복원 및 로컬 데이터 초기화'), findsOneWidget);
    expect(find.text('알림에 일정 이름 표시'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
    expect(find.textContaining('email'), findsNothing);
    expect(find.text('No scheduled notifications'), findsOneWidget);
  });

  testWidgets('detailed notification opt-in persists locally and reconciles', (
    tester,
  ) async {
    await _pumpMyPage(tester);

    final detailSwitch = find.widgetWithText(SwitchListTile, '알림에 일정 이름 표시');
    expect(tester.widget<SwitchListTile>(detailSwitch).value, isFalse);

    await tester.tap(detailSwitch);
    await tester.pumpAndSettle();

    expect(
      (await database.userDao.getAlarmSettings(
        localProfileId,
      )).detailedNotificationContent,
      isTrue,
    );
    expect(reconcile.callCount, 1);
  });

  testWidgets('disabling schedule delivery cancels every local registration', (
    tester,
  ) async {
    await _pumpMyPage(tester);

    await tester.tap(find.byKey(const Key('alarmSettingsSwitch')));
    await tester.pumpAndSettle();

    expect(alarmRepository.updatedSettings, [false]);
    expect(cancelAll.callCount, 1);
    expect(reconcile.callCount, 0);
    expect(find.text('꺼짐'), findsOneWidget);
  });

  testWidgets('fallback permission enables local schedule notifications', (
    tester,
  ) async {
    alarmRepository.settings = const AlarmSettings(alarmsEnabled: false);
    scheduler.capabilities = AlarmSchedulerCapabilities.unsupported;
    fallback.permission = AlarmPermissionState.granted;

    await _pumpMyPage(tester);
    await tester.tap(find.byKey(const Key('alarmSettingsSwitch')));
    await tester.pumpAndSettle();

    expect(fallback.requestCount, 1);
    expect(alarmRepository.updatedSettings, [true]);
    expect(reconcile.callCount, 1);
  });

  testWidgets('armed local notification is reported without server status', (
    tester,
  ) async {
    alarmRegistry.records = [
      ScheduledAlarmRecord(
        scheduleId: 'schedule-1',
        alarmTime: DateTime(2026, 9, 1, 9),
        preparationStartTime: DateTime(2026, 9, 1, 9),
        scheduleFingerprint: 'fingerprint-1',
        fallbackNotificationId: 1,
        provider: AlarmProvider.localNotification,
        scheduleTitle: 'OnTime',
        payload: const {'scheduleId': 'schedule-1'},
      ),
    ];

    await _pumpMyPage(tester);

    expect(find.text('Notification'), findsOneWidget);
  });

  testWidgets('authorized notification permission reports it is already on', (
    tester,
  ) async {
    final notifications = _FakeNotificationService(
      currentStatus: AuthorizationStatus.authorized,
    );
    await _pumpMyPage(tester, notificationService: notifications);

    await tester.ensureVisible(find.text('Allow App Notifications'));
    await tester.tap(find.text('Allow App Notifications'));
    await tester.pumpAndSettle();

    expect(find.text('Notification Already Enabled'), findsOneWidget);
    expect(notifications.requestCount, 0);
  });

  testWidgets('new notification grant initializes local notifications', (
    tester,
  ) async {
    final notifications = _FakeNotificationService(
      currentStatus: AuthorizationStatus.notDetermined,
      requestedStatus: AuthorizationStatus.authorized,
    );
    await _pumpMyPage(tester, notificationService: notifications);

    await tester.ensureVisible(find.text('Allow App Notifications'));
    await tester.tap(find.text('Allow App Notifications'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();

    expect(notifications.requestCount, 1);
    expect(notifications.initializeCount, 1);
    expect(find.text('Notification Permission Granted'), findsOneWidget);
  });

  testWidgets('restricted notification state can open system settings', (
    tester,
  ) async {
    final notifications = _FakeNotificationService(
      currentStatus: AuthorizationStatus.provisional,
    );
    await _pumpMyPage(tester, notificationService: notifications);

    await tester.ensureVisible(find.text('Allow App Notifications'));
    await tester.tap(find.text('Allow App Notifications'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();

    expect(notifications.openSettingsCount, 1);
  });

  testWidgets('local data and bundled privacy destinations remain in-app', (
    tester,
  ) async {
    await _pumpMyPage(tester);

    await tester.tap(find.text('백업, 복원 및 로컬 데이터 초기화'));
    await tester.pumpAndSettle();
    expect(find.text('my data destination'), findsOneWidget);

    final BuildContext context = tester.element(
      find.text('my data destination'),
    );
    GoRouter.of(context).go('/myPage');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Privacy Policy'));
    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();
    expect(find.text('bundled privacy destination'), findsOneWidget);
  });
}

Future<void> _pumpMyPage(
  WidgetTester tester, {
  NotificationService? notificationService,
}) async {
  final router = GoRouter(
    initialLocation: '/myPage',
    routes: [
      GoRoute(
        path: '/myPage',
        builder: (_, _) =>
            MyPageScreen(notificationService: notificationService),
      ),
      GoRoute(
        path: '/myData',
        builder: (_, _) => const Scaffold(body: Text('my data destination')),
      ),
      GoRoute(
        path: '/privacyPolicy',
        builder: (_, _) =>
            const Scaffold(body: Text('bundled privacy destination')),
      ),
      GoRoute(
        path: '/defaultPreparationSpareTimeEdit',
        builder: (_, _) => const Scaffold(body: Text('preparation editor')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: themeData,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeAlarmRepository implements AlarmRepository {
  AlarmSettings settings = const AlarmSettings(alarmsEnabled: true);
  final updatedSettings = <bool>[];

  @override
  Future<AlarmSettings> getAlarmSettings() async => settings;

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
  ) async => const [];
}

class _FakeAlarmRegistry implements AlarmRegistryRepository {
  List<ScheduledAlarmRecord> records = const [];

  @override
  Future<List<ScheduledAlarmRecord>> loadAll() async => records;

  @override
  Future<void> deleteAll() async => records = const [];

  @override
  Future<void> deleteByScheduleId(String scheduleId) async {}

  @override
  Future<void> replaceAll(List<ScheduledAlarmRecord> records) async {
    this.records = records;
  }

  @override
  Future<void> upsert(ScheduledAlarmRecord record) async {}
}

class _FakeAlarmSchedulerService extends AlarmSchedulerService {
  AlarmSchedulerCapabilities capabilities = const AlarmSchedulerCapabilities(
    supportsNativeAlarm: false,
    nativeAlarmProvider: AlarmProvider.none,
  );
  AlarmPermissionState permission = AlarmPermissionState.unsupported;
  int requestCount = 0;

  @override
  Future<AlarmSchedulerCapabilities> getCapabilities() async => capabilities;

  @override
  Future<AlarmPermissionState> checkPermission() async => permission;

  @override
  Future<AlarmPermissionState> requestPermission() async {
    requestCount += 1;
    return permission;
  }
}

class _FakeFallbackAlarmNotificationService
    implements FallbackAlarmNotificationService {
  AlarmPermissionState permission = AlarmPermissionState.granted;
  int requestCount = 0;

  @override
  Future<AlarmPermissionState> checkPermission() async => permission;

  @override
  Future<AlarmPermissionState> requestPermission() async {
    requestCount += 1;
    return permission;
  }

  @override
  Future<void> cancelFallbackAlarm(ScheduledAlarmRecord record) async {}

  @override
  Future<void> scheduleFallbackAlarm(ScheduledAlarmRecord record) async {}
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
      nativeAlarmProvider: AlarmProvider.none,
      fallbackProvider: AlarmProvider.localNotification,
      armedScheduleIds: const [],
      skippedScheduleCount: 0,
      failures: const [],
      scheduleWindowStart: DateTime(2026),
      scheduleWindowEnd: DateTime(2027),
      alarmCoverageStart: DateTime(2026),
      alarmCoverageEnd: DateTime(2027),
    );
  }
}

class _FakeCancelAllAlarmsUseCase extends CancelAllAlarmsUseCase {
  // ignore: use_super_parameters
  _FakeCancelAllAlarmsUseCase(
    AlarmRegistryRepository registryRepository,
    AlarmSchedulerService schedulerService,
    FallbackAlarmNotificationService fallbackNotificationService,
  ) : super(registryRepository, schedulerService, fallbackNotificationService);

  int callCount = 0;

  @override
  Future<void> call() async {
    callCount += 1;
  }
}

class _FakeNotificationService implements NotificationService {
  _FakeNotificationService({
    required this.currentStatus,
    this.requestedStatus = AuthorizationStatus.denied,
  });

  AuthorizationStatus currentStatus;
  final AuthorizationStatus requestedStatus;
  int requestCount = 0;
  int initializeCount = 0;
  int openSettingsCount = 0;

  @override
  Future<AuthorizationStatus> checkNotificationPermission() async =>
      currentStatus;

  @override
  Future<void> initialize() async {
    initializeCount += 1;
  }

  @override
  Future<bool> openNotificationSettings() async {
    openSettingsCount += 1;
    return true;
  }

  @override
  Future<AuthorizationStatus> requestPermission() async {
    requestCount += 1;
    currentStatus = requestedStatus;
    return requestedStatus;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
