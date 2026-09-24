import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/domain/entities/delivery_observation.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:on_time_front/presentation/shared/components/notification_timing_education.dart';
import 'package:on_time_front/domain/entities/scheduled_notification_content.dart';
import 'package:on_time_front/presentation/shared/components/bottom_nav_bar_scaffold.dart';
import '../../helpers/refresh_capture.dart';
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
  setUpAll(loadRefreshFonts);

  late AppDatabase database;
  late _FakeAlarmRepository alarmRepository;
  late _FakeAlarmRegistry alarmRegistry;
  late _FakeAlarmSchedulerService scheduler;
  late _FakeFallbackAlarmNotificationService fallback;
  late _FakeReconcileAlarmsUseCase reconcile;
  late _FakeCancelAllAlarmsUseCase cancelAll;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
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

  testWidgets('Korean settings match the phone layout', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpMyPage(tester, locale: const Locale('ko'));
    await captureRefresh(tester, 'mypage-entry');
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows only local data and device settings', (tester) async {
    await _pumpMyPage(tester);

    expect(find.text('My Page'), findsOneWidget);
    expect(find.text('Back up my data'), findsOneWidget);
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
    expect(reconcile.callCount, 2);
  });

  testWidgets(
    'committed detailed preference survives delivery invalidation without unhandled error',
    (tester) async {
      await _pumpMyPage(tester);
      reconcile.fail = true;
      final detail = find.widgetWithText(SwitchListTile, '알림에 일정 이름 표시');
      await tester.tap(detail);
      await tester.pumpAndSettle();
      expect(
        (await database.userDao.getAlarmSettings(
          localProfileId,
        )).detailedNotificationContent,
        true,
      );
      expect(tester.widget<SwitchListTile>(detail).value, true);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'OFF cancellation failure keeps committed preference and shows cleanup status',
    (tester) async {
      await _pumpMyPage(tester);
      cancelAll.fail = true;
      reconcile.disabledStatus = AlarmReconciliationStatus.partial;
      await tester.tap(find.byKey(const Key('alarmSettingsSwitch')));
      await tester.pumpAndSettle();
      expect(alarmRepository.settings.alarmsEnabled, false);
      expect(find.text('Off · cancellation needs checking'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('disabling schedule delivery cancels every local registration', (
    tester,
  ) async {
    await _pumpMyPage(tester);

    await tester.tap(find.byKey(const Key('alarmSettingsSwitch')));
    await tester.pumpAndSettle();

    expect(alarmRepository.updatedSettings, [false]);
    expect(cancelAll.callCount, 1);
    expect(find.text('꺼짐'), findsOneWidget);
  });

  testWidgets(
    'disabled delivery still shows unconfirmed cleanup and clears after recovery',
    (tester) async {
      alarmRepository.settings = const AlarmSettings(alarmsEnabled: false);
      reconcile.disabledStatus = AlarmReconciliationStatus.partial;
      await _pumpMyPage(tester);
      expect(find.text('Off · cancellation needs checking'), findsOneWidget);
      expect(find.text('꺼짐'), findsNothing);
      reconcile.disabledStatus = AlarmReconciliationStatus.disabled;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Off · cancellation needs checking'), findsNothing);
      expect(find.text('꺼짐'), findsOneWidget);
    },
  );

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
    expect(reconcile.callCount, 2);
  });

  testWidgets('armed local notification is reported without server status', (
    tester,
  ) async {
    final content = ScheduledNotificationContent(
      scheduleTitle: 'OnTime',
      detailed: false,
      languageCode: 'en',
    );
    reconcile.armedIds = ['schedule-1'];
    alarmRegistry.records = [
      ScheduledAlarmRecord(
        scheduleId: 'schedule-1',
        alarmTime: DateTime(2035, 9, 1, 9),
        preparationStartTime: DateTime(2035, 9, 1, 9),
        scheduleFingerprint: 'fingerprint-1',
        fallbackNotificationId: 1,
        provider: AlarmProvider.localNotification,
        scheduleTitle: 'OnTime',
        payload: const {'scheduleId': 'schedule-1'},
        notificationTiming: NotificationTiming.platformDefault,
        contentDigest: content.digest,
        contentVersion: ScheduledNotificationContent.schemaVersion,
        contentLanguageCode: 'en',
      ),
    ];

    await _pumpMyPage(tester);

    expect(find.text('Notification'), findsOneWidget);
  });

  testWidgets(
    'timing education is optional once and settings require explicit choice',
    (tester) async {
      alarmRepository.settings = const AlarmSettings(alarmsEnabled: false);
      fallback.timingPermission = AlarmPermissionState.denied;
      await _pumpMyPage(tester);
      expect(fallback.timingRequestCount, 0);
      await tester.tap(find.byKey(const Key('alarmSettingsSwitch')));
      await tester.pumpAndSettle();
      expect(alarmRepository.settings.alarmsEnabled, isTrue);
      expect(reconcile.callCount, 2);
      expect(
        find.text('Improve preparation notification timing'),
        findsOneWidget,
      );
      expect(fallback.timingRequestCount, 0);
      await tester.tap(find.text("I'll do it later."));
      await tester.pumpAndSettle();
      expect(fallback.timingRequestCount, 0);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          NotificationTimingEducation.preferenceKey,
        ),
        isTrue,
      );
      await tester.tap(find.byKey(const Key('alarmSettingsSwitch')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('alarmSettingsSwitch')));
      await tester.pumpAndSettle();
      expect(
        find.text('Improve preparation notification timing'),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('notificationTimingSettings')));
      await tester.pumpAndSettle();
      expect(fallback.timingRequestCount, 1);
      expect(find.text('No scheduled notifications'), findsOneWidget);
      expect(
        find.text('Approximate timing · precise timing can be enabled'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'education setting choice rereads state without claiming a grant',
    (tester) async {
      alarmRepository.settings = const AlarmSettings(alarmsEnabled: false);
      fallback.timingPermission = AlarmPermissionState.denied;
      await _pumpMyPage(tester);
      await tester.tap(find.byKey(const Key('alarmSettingsSwitch')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();
      expect(fallback.timingRequestCount, 1);
      expect(
        find.text('Approximate timing · precise timing can be enabled'),
        findsOneWidget,
      );
      expect(find.text('Precise notification'), findsNothing);
    },
  );

  testWidgets(
    'current timing grant does not hide partial scheduling or display denial',
    (tester) async {
      fallback.timingPermission = AlarmPermissionState.granted;
      reconcile.status = AlarmReconciliationStatus.partial;
      await _pumpMyPage(tester);
      expect(
        find.text('Notification scheduling incomplete or needs checking'),
        findsOneWidget,
      );
      expect(find.text('Precise timing available'), findsOneWidget);
      expect(find.text('Precise notification'), findsNothing);
      fallback.permission = AlarmPermissionState.denied;
      await tester.tap(find.byKey(const Key('notificationTimingSettings')));
      await tester.pumpAndSettle();
      expect(find.text('Notification permission needed'), findsOneWidget);
    },
  );

  testWidgets(
    'late education cannot appear after leaving the eligible route or consume once marker',
    (tester) async {
      fallback.timingPermission = AlarmPermissionState.denied;
      await _pumpMyPage(tester);
      final pageContext = tester.element(find.byType(MyPageScreen));
      final router = GoRouter.of(pageContext);
      fallback.timingCheck = Completer<AlarmPermissionState>();
      final offered = NotificationTimingEducation.offerOnce(
        pageContext,
        isCurrent: () =>
            router.routeInformationProvider.value.uri.path == '/myPage',
      );
      await tester.pump();
      router.go('/myData');
      await tester.pumpAndSettle();
      fallback.timingCheck!.complete(AlarmPermissionState.denied);
      expect(await offered, isFalse);
      await tester.pumpAndSettle();
      expect(
        find.text('Improve preparation notification timing'),
        findsNothing,
      );
      expect(find.text('my data destination'), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          NotificationTimingEducation.preferenceKey,
        ),
        isNull,
      );
      expect(fallback.timingRequestCount, 0);
    },
  );

  testWidgets(
    'data replacement during timing lookup cannot consume education or open settings',
    (tester) async {
      fallback.timingPermission = AlarmPermissionState.denied;
      await _pumpMyPage(tester);
      fallback.timingCheck = Completer<AlarmPermissionState>();
      final offered = NotificationTimingEducation.offerOnce(
        tester.element(find.byType(MyPageScreen)),
      );
      await tester.pump();
      await LocalDataOperationGate.shared.run(() async {}, replacesData: true);
      fallback.timingCheck!.complete(AlarmPermissionState.denied);
      expect(await offered, isFalse);
      await tester.pumpAndSettle();
      expect(
        find.text('Improve preparation notification timing'),
        findsNothing,
      );
      expect(
        (await SharedPreferences.getInstance()).getBool(
          NotificationTimingEducation.preferenceKey,
        ),
        isNull,
      );
      expect(fallback.timingRequestCount, 0);
    },
  );

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

    await tester.ensureVisible(find.text('Back up my data'));
    await tester.tap(find.text('Back up my data'));
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
  Locale locale = const Locale('en'),
}) async {
  final router = GoRouter(
    initialLocation: '/myPage',
    routes: [
      GoRoute(
        path: '/myPage',
        builder: (_, _) => locale.languageCode == 'ko'
            ? BottomNavBarScaffold(
                child: MyPageScreen(notificationService: notificationService),
              )
            : MyPageScreen(notificationService: notificationService),
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
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(padding: const EdgeInsets.only(top: 44, bottom: 34)),
        child: child!,
      ),
      locale: locale,
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
  @override
  Future<DeliveryObservation> observePending() async =>
      const DeliveryObservation.unknown();
  AlarmPermissionState timingPermission = AlarmPermissionState.unsupported;
  int timingRequestCount = 0;
  Completer<AlarmPermissionState>? timingCheck;

  @override
  Future<AlarmPermissionState> checkExactTimingPermission() async =>
      timingCheck == null ? timingPermission : await timingCheck!.future;

  @override
  Future<AlarmPermissionState> requestExactTimingPermission() async {
    timingRequestCount++;
    return timingPermission;
  }

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
  Future<NotificationTiming> scheduleFallbackAlarm(
    ScheduledAlarmRecord record,
  ) async => NotificationTiming.platformDefault;
}

class _FakeReconcileAlarmsUseCase extends ReconcileAlarmsUseCase {
  // ignore: use_super_parameters
  _FakeReconcileAlarmsUseCase(
    AlarmRepository alarmRepository,
    AlarmRegistryRepository registryRepository,
    AlarmSchedulerService schedulerService,
    FallbackAlarmNotificationService fallbackNotificationService,
  ) : repository = alarmRepository,
      super.test(
        alarmRepository,
        registryRepository,
        schedulerService,
        fallbackNotificationService,
        nowProvider: () => DateTime(2026),
      );

  final AlarmRepository repository;
  AlarmReconciliationStatus disabledStatus = AlarmReconciliationStatus.disabled;
  int callCount = 0;
  List<String> armedIds = [];
  AlarmReconciliationStatus status = AlarmReconciliationStatus.armed;
  bool fail = false;

  @override
  Future<AlarmReconciliationResult> call() async {
    callCount += 1;
    if (fail) throw const AlarmOperationInvalidated();
    return AlarmReconciliationResult(
      status: (await repository.getAlarmSettings()).alarmsEnabled
          ? status
          : disabledStatus,
      nativeAlarmProvider: AlarmProvider.none,
      fallbackProvider: AlarmProvider.localNotification,
      armedScheduleIds: armedIds,
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
  bool fail = false;

  @override
  Future<void> call() async {
    callCount += 1;
    if (fail) throw const AlarmCleanupIncomplete();
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
