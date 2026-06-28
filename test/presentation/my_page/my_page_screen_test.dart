import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mockito/mockito.dart';
import 'package:on_time_front/core/constants/external_links.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/core/services/alarm_scheduler_service.dart';
import 'package:on_time_front/core/services/fallback_alarm_notification_service.dart';
import 'package:on_time_front/core/services/notification_service.dart';
import 'package:on_time_front/core/services/product_analytics_service.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/entities/analytics_preference.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/repositories/analytics_preference_repository.dart';
import 'package:on_time_front/domain/repositories/alarm_registry_repository.dart';
import 'package:on_time_front/domain/repositories/alarm_repository.dart';
import 'package:on_time_front/domain/use-cases/load_analytics_preference_use_case.dart';
import 'package:on_time_front/domain/use-cases/update_analytics_preference_use_case.dart';
import 'package:on_time_front/domain/use-cases/cancel_all_alarms_use_case.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/app/bloc/auth/auth_bloc.dart';
import 'package:on_time_front/presentation/app/cubit/analytics_preference_cubit.dart';
import 'package:on_time_front/presentation/my_page/my_page_screen.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await getIt.reset();
    final alarmRepository = _FakeAlarmRepository();
    final alarmRegistry = _FakeAlarmRegistry();
    final alarmScheduler = _FakeAlarmSchedulerService();
    final fallbackAlarmNotificationService =
        _FakeFallbackAlarmNotificationService();
    getIt
      ..registerSingleton<AlarmRepository>(alarmRepository)
      ..registerSingleton<AlarmRegistryRepository>(alarmRegistry)
      ..registerSingleton<AlarmSchedulerService>(alarmScheduler)
      ..registerSingleton<FallbackAlarmNotificationService>(
        fallbackAlarmNotificationService,
      )
      ..registerSingleton<CancelAllAlarmsUseCase>(
        _FakeCancelAllAlarmsUseCase(
          alarmRepository,
          alarmRegistry,
          alarmScheduler,
          fallbackAlarmNotificationService,
        ),
      )
      ..registerSingleton<ReconcileAlarmsUseCase>(
        _FakeReconcileAlarmsUseCase(
          alarmRepository,
          alarmRegistry,
          alarmScheduler,
          fallbackAlarmNotificationService,
        ),
      );
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('shows English privacy policy setting', (tester) async {
    await _pumpMyPage(tester, locale: const Locale('en'));

    expect(find.text('Privacy Policy'), findsOneWidget);
  });

  testWidgets('shows Korean privacy policy setting', (tester) async {
    await _pumpMyPage(tester, locale: const Locale('ko'));

    expect(find.text('개인정보 처리방침'), findsOneWidget);
  });

  testWidgets('shows loaded Help improve OnTime preference switch', (
    tester,
  ) async {
    final analyticsRepository = _FakeAnalyticsPreferenceRepository()
      ..localPreference = const AnalyticsPreference(enabled: true)
      ..accountPreference = const AnalyticsPreference(enabled: true);
    final analyticsCubit = AnalyticsPreferenceCubit(
      loadPreferenceUseCase: LoadAnalyticsPreferenceUseCase(
        analyticsRepository,
      ),
      updatePreferenceUseCase: UpdateAnalyticsPreferenceUseCase(
        analyticsRepository,
      ),
      analyticsService: ProductAnalyticsService(
        client: _FakeAnalyticsProviderClient(),
        collectionAllowedInBuild: true,
      ),
    );

    await _pumpMyPage(
      tester,
      locale: const Locale('en'),
      authState: AuthState(user: _authenticatedUser),
      analyticsPreferenceCubit: analyticsCubit,
    );

    expect(find.text('Help improve OnTime'), findsOneWidget);
    expect(
      tester.widget<Switch>(find.byKey(const Key('analyticsPreferenceSwitch'))),
      isA<Switch>().having((switchWidget) => switchWidget.value, 'value', true),
    );
  });

  testWidgets('opens hosted privacy policy URL from setting', (tester) async {
    final openedUris = <Uri>[];

    await _pumpMyPage(
      tester,
      locale: const Locale('en'),
      openPrivacyPolicy: (uri) async {
        openedUris.add(uri);
        return true;
      },
    );

    await tester.ensureVisible(find.text('Privacy Policy'));
    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();

    expect(openedUris, [ExternalLinks.privacyPolicyUri]);
  });

  testWidgets('shows an error dialog when privacy policy cannot open', (
    tester,
  ) async {
    await _pumpMyPage(
      tester,
      locale: const Locale('en'),
      openPrivacyPolicy: (_) async => false,
    );

    await tester.ensureVisible(find.text('Privacy Policy'));
    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();

    expect(find.text('Error'), findsOneWidget);
    expect(find.textContaining('privacy policy'), findsOneWidget);
  });

  testWidgets('shows already-enabled dialog when notifications are allowed', (
    tester,
  ) async {
    final notificationService = _FakeNotificationService(
      currentStatus: AuthorizationStatus.authorized,
    );

    await _pumpMyPage(
      tester,
      locale: const Locale('en'),
      notificationService: notificationService,
    );

    await tester.ensureVisible(find.text('Allow App Notifications'));
    await tester.tap(find.text('Allow App Notifications'));
    await tester.pumpAndSettle();

    expect(find.text('Notification Already Enabled'), findsOneWidget);
    expect(notificationService.requestCount, 0);
    expect(notificationService.initializeCount, 0);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Notification Already Enabled'), findsNothing);
  });

  testWidgets('cancels notification permission request from rationale dialog', (
    tester,
  ) async {
    final notificationService = _FakeNotificationService(
      currentStatus: AuthorizationStatus.denied,
    );

    await _pumpMyPage(
      tester,
      locale: const Locale('en'),
      notificationService: notificationService,
    );

    await tester.ensureVisible(find.text('Allow App Notifications'));
    await tester.tap(find.text('Allow App Notifications'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(notificationService.requestCount, 0);
    expect(notificationService.initializeCount, 0);
    expect(notificationService.openSettingsCount, 0);
  });

  testWidgets(
    'granting notification permission initializes notifications and confirms',
    (tester) async {
      final notificationService = _FakeNotificationService(
        currentStatus: AuthorizationStatus.notDetermined,
        requestedStatus: AuthorizationStatus.authorized,
      );

      await _pumpMyPage(
        tester,
        locale: const Locale('en'),
        notificationService: notificationService,
      );

      await tester.ensureVisible(find.text('Allow App Notifications'));
      await tester.tap(find.text('Allow App Notifications'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Allow'));
      await tester.pumpAndSettle();

      expect(notificationService.requestCount, 1);
      expect(notificationService.initializeCount, 1);
      expect(find.text('Notification Permission Granted'), findsOneWidget);
    },
  );

  testWidgets('denied notification permission can open app settings', (
    tester,
  ) async {
    final notificationService = _FakeNotificationService(
      currentStatus: AuthorizationStatus.denied,
      requestedStatus: AuthorizationStatus.denied,
    );

    await _pumpMyPage(
      tester,
      locale: const Locale('en'),
      notificationService: notificationService,
    );

    await tester.ensureVisible(find.text('Allow App Notifications'));
    await tester.tap(find.text('Allow App Notifications'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();

    expect(notificationService.requestCount, 1);
    expect(notificationService.initializeCount, 0);
    expect(notificationService.openSettingsCount, 1);
  });

  testWidgets('provisional notification permission opens settings dialog', (
    tester,
  ) async {
    final notificationService = _FakeNotificationService(
      currentStatus: AuthorizationStatus.provisional,
    );

    await _pumpMyPage(
      tester,
      locale: const Locale('en'),
      notificationService: notificationService,
    );

    await tester.ensureVisible(find.text('Allow App Notifications'));
    await tester.tap(find.text('Allow App Notifications'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();

    expect(notificationService.requestCount, 0);
    expect(notificationService.openSettingsCount, 1);
  });

  testWidgets(
    'enables schedule notifications when Android exact timing is denied',
    (tester) async {
      final alarmRepository =
          getIt.get<AlarmRepository>() as _FakeAlarmRepository;
      final alarmScheduler =
          getIt.get<AlarmSchedulerService>() as _FakeAlarmSchedulerService;
      final fallbackService =
          getIt.get<FallbackAlarmNotificationService>()
              as _FakeFallbackAlarmNotificationService;
      final reconcileUseCase =
          getIt.get<ReconcileAlarmsUseCase>() as _FakeReconcileAlarmsUseCase;
      alarmRepository.settings = const AlarmSettings(alarmsEnabled: false);
      alarmScheduler
        ..capabilities = const AlarmSchedulerCapabilities(
          supportsNativeAlarm: true,
          nativeAlarmProvider: AlarmProvider.androidAlarmManager,
        )
        ..permission = AlarmPermissionState.denied;
      fallbackService.permission = AlarmPermissionState.granted;

      await _pumpMyPage(tester, locale: const Locale('en'));

      await tester.tap(find.byKey(const Key('alarmSettingsSwitch')));
      await tester.pumpAndSettle();

      expect(find.text('Precise notification permission needed'), findsNothing);
      expect(alarmScheduler.requestCount, 0);
      expect(alarmRepository.updatedSettings, [true]);
      expect(fallbackService.requestCount, 1);
      expect(reconcileUseCase.callCount, 1);
      expect(
        tester
            .widget<Switch>(find.byKey(const Key('alarmSettingsSwitch')))
            .value,
        isTrue,
      );
    },
  );

  testWidgets(
    'enabling alarms can recover approved native alarm permission through settings',
    (tester) async {
      final alarmRepository =
          getIt.get<AlarmRepository>() as _FakeAlarmRepository;
      final alarmScheduler =
          getIt.get<AlarmSchedulerService>() as _FakeAlarmSchedulerService;
      final fallbackService =
          getIt.get<FallbackAlarmNotificationService>()
              as _FakeFallbackAlarmNotificationService;
      final reconcileUseCase =
          getIt.get<ReconcileAlarmsUseCase>() as _FakeReconcileAlarmsUseCase;
      alarmRepository.settings = const AlarmSettings(alarmsEnabled: false);
      alarmScheduler
        ..capabilities = const AlarmSchedulerCapabilities(
          supportsNativeAlarm: true,
          nativeAlarmProvider: AlarmProvider.iosAlarmKit,
        )
        ..permission = AlarmPermissionState.denied
        ..permissionAfterRequest = AlarmPermissionState.granted;
      fallbackService.permission = AlarmPermissionState.granted;

      await _pumpMyPage(tester, locale: const Locale('en'));

      await tester.tap(find.byKey(const Key('alarmSettingsSwitch')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      expect(alarmScheduler.requestCount, 1);
      expect(alarmRepository.updatedSettings, [true]);
      expect(fallbackService.requestCount, 1);
      expect(reconcileUseCase.callCount, 1);
      expect(
        tester
            .widget<Switch>(find.byKey(const Key('alarmSettingsSwitch')))
            .value,
        isTrue,
      );
    },
  );

  testWidgets('shows authenticated user account information', (tester) async {
    await _pumpMyPage(
      tester,
      locale: const Locale('en'),
      authState: AuthState(
        user: const UserEntity(
          id: 'user-1',
          email: 'user@example.com',
          name: 'User Name',
          spareTime: Duration(minutes: 10),
          note: '',
          score: 4.5,
          isOnboardingCompleted: true,
        ),
      ),
    );

    expect(find.text('User Name'), findsOneWidget);
    expect(find.text('user@example.com'), findsOneWidget);
  });

  testWidgets('logout setting shows confirmation and dispatches sign out', (
    tester,
  ) async {
    final authBloc = _StubAuthBloc(AuthState());

    await _pumpMyPage(tester, locale: const Locale('en'), authBloc: authBloc);

    await tester.ensureVisible(find.text('Log out'));
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Do you want to log out?'), findsOneWidget);

    await tester.tap(find.text('Log out').last);
    await tester.pumpAndSettle();

    expect(authBloc.addedEvents.single, isA<AuthSignOutPressed>());
  });

  testWidgets('shows precise notification status for Android alarm manager', (
    tester,
  ) async {
    final alarmRepository =
        getIt.get<AlarmRepository>() as _FakeAlarmRepository;
    final alarmRegistry =
        getIt.get<AlarmRegistryRepository>() as _FakeAlarmRegistry;
    alarmRepository.settings = const AlarmSettings(alarmsEnabled: true);
    alarmRegistry.records = [
      _alarmRecord(provider: AlarmProvider.androidAlarmManager),
    ];

    await _pumpMyPage(tester, locale: const Locale('ko'));

    expect(find.text('정확한 알림'), findsOneWidget);
    expect(
      tester.widget<Switch>(find.byKey(const Key('alarmSettingsSwitch'))).value,
      isTrue,
    );
  });

  testWidgets('shows alarm status for iOS AlarmKit records', (tester) async {
    final alarmRepository =
        getIt.get<AlarmRepository>() as _FakeAlarmRepository;
    final alarmRegistry =
        getIt.get<AlarmRegistryRepository>() as _FakeAlarmRegistry;
    alarmRepository.settings = const AlarmSettings(alarmsEnabled: true);
    alarmRegistry.records = [_alarmRecord(provider: AlarmProvider.iosAlarmKit)];

    await _pumpMyPage(tester, locale: const Locale('ko'));

    expect(find.text('알람'), findsOneWidget);
  });

  testWidgets(
    'shows fallback notification status when fallback records exist',
    (tester) async {
      final alarmRepository =
          getIt.get<AlarmRepository>() as _FakeAlarmRepository;
      final alarmRegistry =
          getIt.get<AlarmRegistryRepository>() as _FakeAlarmRegistry;
      alarmRepository.settings = const AlarmSettings(alarmsEnabled: true);
      alarmRegistry.records = [
        _alarmRecord(provider: AlarmProvider.localNotification),
      ];

      await _pumpMyPage(tester, locale: const Locale('ko'));

      expect(find.text('알림'), findsOneWidget);
    },
  );

  testWidgets(
    'shows notification permission needed when no delivery can be used',
    (tester) async {
      final alarmRepository =
          getIt.get<AlarmRepository>() as _FakeAlarmRepository;
      final fallbackService =
          getIt.get<FallbackAlarmNotificationService>()
              as _FakeFallbackAlarmNotificationService;
      alarmRepository.settings = const AlarmSettings(alarmsEnabled: true);
      fallbackService.permission = AlarmPermissionState.denied;

      await _pumpMyPage(tester, locale: const Locale('ko'));

      expect(find.text('알림 권한 필요'), findsOneWidget);
    },
  );

  testWidgets(
    'shows permission-needed status when all alarm permissions fail',
    (tester) async {
      final alarmRepository =
          getIt.get<AlarmRepository>() as _FakeAlarmRepository;
      final alarmScheduler =
          getIt.get<AlarmSchedulerService>() as _FakeAlarmSchedulerService;
      final fallbackService =
          getIt.get<FallbackAlarmNotificationService>()
              as _FakeFallbackAlarmNotificationService;
      alarmRepository.settings = const AlarmSettings(alarmsEnabled: true);
      alarmScheduler
        ..capabilities = const AlarmSchedulerCapabilities(
          supportsNativeAlarm: true,
          nativeAlarmProvider: AlarmProvider.androidAlarmManager,
        )
        ..permission = AlarmPermissionState.denied;
      fallbackService.permission = AlarmPermissionState.denied;

      await _pumpMyPage(tester, locale: const Locale('ko'));

      expect(find.text('알림 권한 필요'), findsOneWidget);
    },
  );

  testWidgets('unauthenticated users do not render account identity', (
    tester,
  ) async {
    await _pumpMyPage(tester, locale: const Locale('en'));

    expect(find.text('User Name'), findsNothing);
    expect(find.text('user@example.com'), findsNothing);
  });

  testWidgets('shows load error when alarm settings cannot be read', (
    tester,
  ) async {
    final alarmRepository =
        getIt.get<AlarmRepository>() as _FakeAlarmRepository;
    alarmRepository.throwSettings = true;

    await _pumpMyPage(tester, locale: const Locale('ko'));

    expect(find.text('상태를 불러올 수 없음'), findsOneWidget);
  });

  testWidgets('enabling alarms with permission reconciles alarm schedule', (
    tester,
  ) async {
    final alarmRepository =
        getIt.get<AlarmRepository>() as _FakeAlarmRepository;
    final alarmScheduler =
        getIt.get<AlarmSchedulerService>() as _FakeAlarmSchedulerService;
    final fallbackService =
        getIt.get<FallbackAlarmNotificationService>()
            as _FakeFallbackAlarmNotificationService;
    final reconcileUseCase =
        getIt.get<ReconcileAlarmsUseCase>() as _FakeReconcileAlarmsUseCase;
    alarmRepository.settings = const AlarmSettings(alarmsEnabled: false);
    alarmScheduler
      ..capabilities = const AlarmSchedulerCapabilities(
        supportsNativeAlarm: true,
        nativeAlarmProvider: AlarmProvider.androidAlarmManager,
      )
      ..permission = AlarmPermissionState.granted;
    fallbackService.permission = AlarmPermissionState.granted;

    await _pumpMyPage(tester, locale: const Locale('ko'));
    await tester.tap(find.byKey(const Key('alarmSettingsSwitch')));
    await tester.pumpAndSettle();

    expect(alarmRepository.updatedSettings, [true]);
    expect(fallbackService.requestCount, 1);
    expect(reconcileUseCase.callCount, 1);
    expect(
      tester.widget<Switch>(find.byKey(const Key('alarmSettingsSwitch'))).value,
      isTrue,
    );
  });

  testWidgets(
    'disabling alarms updates settings and cancels registered alarms',
    (tester) async {
      final alarmRepository =
          getIt.get<AlarmRepository>() as _FakeAlarmRepository;
      final cancelAllUseCase =
          getIt.get<CancelAllAlarmsUseCase>() as _FakeCancelAllAlarmsUseCase;
      alarmRepository.settings = const AlarmSettings(alarmsEnabled: true);

      await _pumpMyPage(tester, locale: const Locale('ko'));
      await tester.tap(find.byKey(const Key('alarmSettingsSwitch')));
      await tester.pumpAndSettle();

      expect(alarmRepository.updatedSettings, [false]);
      expect(cancelAllUseCase.callCount, 1);
      expect(
        tester
            .widget<Switch>(find.byKey(const Key('alarmSettingsSwitch')))
            .value,
        isFalse,
      );
    },
  );
}

Future<void> _pumpMyPage(
  WidgetTester tester, {
  required Locale locale,
  PrivacyPolicyLauncher? openPrivacyPolicy,
  NotificationService? notificationService,
  AnalyticsPreferenceCubit? analyticsPreferenceCubit,
  AuthState authState = const AuthState.loading(),
  _StubAuthBloc? authBloc,
}) async {
  final bloc = authBloc ?? _StubAuthBloc(authState);
  final analyticsCubit =
      analyticsPreferenceCubit ?? _buildAnalyticsPreferenceCubit();
  addTearDown(analyticsCubit.close);
  await tester.pumpWidget(
    MaterialApp(
      theme: themeData,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider<AuthBloc>.value(
        value: bloc,
        child: MyPageScreen(
          openPrivacyPolicy: openPrivacyPolicy,
          notificationService: notificationService,
          analyticsPreferenceCubit: analyticsCubit,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

AnalyticsPreferenceCubit _buildAnalyticsPreferenceCubit({
  _FakeAnalyticsPreferenceRepository? repository,
}) {
  final analyticsRepository =
      repository ?? _FakeAnalyticsPreferenceRepository();
  return AnalyticsPreferenceCubit(
    loadPreferenceUseCase: LoadAnalyticsPreferenceUseCase(analyticsRepository),
    updatePreferenceUseCase: UpdateAnalyticsPreferenceUseCase(
      analyticsRepository,
    ),
    analyticsService: ProductAnalyticsService(
      client: _FakeAnalyticsProviderClient(),
      collectionAllowedInBuild: true,
    ),
  );
}

class _StubAuthBloc extends Mock implements AuthBloc {
  _StubAuthBloc(this._state);

  final AuthState _state;
  final addedEvents = <AuthEvent>[];

  @override
  AuthState get state => _state;

  @override
  Stream<AuthState> get stream => const Stream.empty();

  @override
  bool get isClosed => false;

  @override
  void add(AuthEvent event) {
    addedEvents.add(event);
  }
}

const _authenticatedUser = UserEntity(
  id: 'user-1',
  email: 'user@example.com',
  name: 'User',
  spareTime: Duration(minutes: 10),
  note: '',
  score: 0,
  isOnboardingCompleted: true,
);

class _FakeAnalyticsPreferenceRepository
    implements AnalyticsPreferenceRepository {
  AnalyticsPreference localPreference = const AnalyticsPreference(
    enabled: false,
  );
  AnalyticsPreference accountPreference = const AnalyticsPreference(
    enabled: false,
  );

  @override
  Future<AnalyticsPreference> loadLocalPreference() async => localPreference;

  @override
  Future<void> saveLocalPreference(bool enabled) async {
    localPreference = AnalyticsPreference(enabled: enabled);
  }

  @override
  Future<AnalyticsPreference> loadAccountPreference() async =>
      accountPreference;

  @override
  Future<AnalyticsPreference> updateAccountPreference(bool enabled) async {
    accountPreference = AnalyticsPreference(enabled: enabled);
    return accountPreference;
  }
}

class _FakeAnalyticsProviderClient implements AnalyticsProviderClient {
  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {}

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {}

  @override
  Future<void> setUserId(String? userId) async {}
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
  Future<AuthorizationStatus> checkNotificationPermission() async {
    return currentStatus;
  }

  @override
  Future<AuthorizationStatus> requestPermission() async {
    requestCount += 1;
    currentStatus = requestedStatus;
    return requestedStatus;
  }

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
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAlarmRepository implements AlarmRepository {
  AlarmSettings settings = const AlarmSettings(alarmsEnabled: false);
  final updatedSettings = <bool>[];
  bool throwSettings = false;

  @override
  Future<String> getDeviceId() => throw UnimplementedError();

  @override
  Future<AlarmDeviceInfo> buildCurrentDeviceInfo() =>
      throw UnimplementedError();

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
  Future<void> registerCurrentDevice(AlarmDeviceInfo deviceInfo) {
    throw UnimplementedError();
  }

  @override
  Future<void> unregisterCurrentDevice(String deviceId) {
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
}

class _FakeAlarmRegistry implements AlarmRegistryRepository {
  List<ScheduledAlarmRecord> records = const [];

  @override
  Future<List<ScheduledAlarmRecord>> loadAll() async => records;

  @override
  Future<void> upsert(ScheduledAlarmRecord record) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteByScheduleId(String scheduleId) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteAll() {
    throw UnimplementedError();
  }

  @override
  Future<void> replaceAll(List<ScheduledAlarmRecord> records) {
    throw UnimplementedError();
  }
}

class _FakeAlarmSchedulerService extends AlarmSchedulerService {
  AlarmSchedulerCapabilities capabilities =
      AlarmSchedulerCapabilities.unsupported;
  AlarmPermissionState permission = AlarmPermissionState.unsupported;
  AlarmPermissionState? permissionAfterRequest;
  int requestCount = 0;

  @override
  Future<AlarmSchedulerCapabilities> getCapabilities() async {
    return capabilities;
  }

  @override
  Future<AlarmPermissionState> checkPermission() async {
    return permission;
  }

  @override
  Future<AlarmPermissionState> requestPermission() async {
    requestCount += 1;
    final nextPermission = permissionAfterRequest;
    if (nextPermission != null) {
      permission = nextPermission;
    }
    return permission;
  }
}

class _FakeFallbackAlarmNotificationService
    implements FallbackAlarmNotificationService {
  AlarmPermissionState permission = AlarmPermissionState.unsupported;
  int requestCount = 0;

  @override
  Future<AlarmPermissionState> checkPermission() async {
    return permission;
  }

  @override
  Future<AlarmPermissionState> requestPermission() async {
    requestCount += 1;
    return permission;
  }

  @override
  Future<void> scheduleFallbackAlarm(ScheduledAlarmRecord record) {
    throw UnimplementedError();
  }

  @override
  Future<void> cancelFallbackAlarm(ScheduledAlarmRecord record) {
    throw UnimplementedError();
  }
}

ScheduledAlarmRecord _alarmRecord({required AlarmProvider provider}) {
  return ScheduledAlarmRecord(
    scheduleId: 'schedule-1',
    alarmTime: DateTime(2026, 5, 15, 8),
    preparationStartTime: DateTime(2026, 5, 15, 8, 5),
    scheduleFingerprint: 'fingerprint',
    nativeAlarmId: 1,
    fallbackNotificationId: 1,
    provider: provider,
    scheduleTitle: 'Morning meeting',
    payload: const {'type': 'schedule_alarm'},
  );
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
