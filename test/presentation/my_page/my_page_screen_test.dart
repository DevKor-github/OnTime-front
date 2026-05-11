import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:on_time_front/core/constants/external_links.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/core/services/alarm_scheduler_service.dart';
import 'package:on_time_front/core/services/fallback_alarm_notification_service.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/repositories/alarm_registry_repository.dart';
import 'package:on_time_front/domain/repositories/alarm_repository.dart';
import 'package:on_time_front/domain/use-cases/cancel_all_alarms_use_case.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/app/bloc/auth/auth_bloc.dart';
import 'package:on_time_front/presentation/my_page/my_page_screen.dart';
import 'package:on_time_front/presentation/notification_allow/screens/notification_allow_screen.dart';
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

  testWidgets('shows notification permission switch on My Page', (
    tester,
  ) async {
    await _pumpMyPage(tester, locale: const Locale('en'));

    expect(find.text('Allow App Notifications'), findsOneWidget);
    expect(
      tester
          .widget<Switch>(
            find.byKey(const Key('notification_permission_switch')),
          )
          .value,
      isFalse,
    );
  });

  testWidgets('turning notification switch on requests permission', (
    tester,
  ) async {
    final notificationGateway = _FakeNotificationPermissionGateway(
      currentStatus: AuthorizationStatus.denied,
      requestedStatus: AuthorizationStatus.authorized,
    );

    await _pumpMyPage(
      tester,
      locale: const Locale('en'),
      notificationPermissionGateway: notificationGateway,
    );

    await tester.tap(find.byKey(const Key('notification_permission_switch')));
    await tester.pumpAndSettle();

    expect(notificationGateway.requestCount, 1);
    expect(notificationGateway.initializeCount, 1);
    expect(
      tester
          .widget<Switch>(
            find.byKey(const Key('notification_permission_switch')),
          )
          .value,
      isTrue,
    );
  });

  testWidgets('turning notification switch off opens settings path', (
    tester,
  ) async {
    final notificationGateway = _FakeNotificationPermissionGateway(
      currentStatus: AuthorizationStatus.authorized,
    );

    await _pumpMyPage(
      tester,
      locale: const Locale('en'),
      notificationPermissionGateway: notificationGateway,
    );

    await tester.tap(find.byKey(const Key('notification_permission_switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();

    expect(notificationGateway.openSettingsCount, 1);
  });

  testWidgets('keeps alarms disabled when exact alarm permission is missing', (
    tester,
  ) async {
    final alarmRepository =
        getIt.get<AlarmRepository>() as _FakeAlarmRepository;
    final alarmScheduler =
        getIt.get<AlarmSchedulerService>() as _FakeAlarmSchedulerService;
    final cancelAllUseCase =
        getIt.get<CancelAllAlarmsUseCase>() as _FakeCancelAllAlarmsUseCase;
    alarmRepository.settings = const AlarmSettings(alarmsEnabled: false);
    alarmScheduler
      ..capabilities = const AlarmSchedulerCapabilities(
        supportsNativeAlarm: true,
        nativeAlarmProvider: AlarmProvider.androidAlarmManager,
      )
      ..permission = AlarmPermissionState.denied;

    await _pumpMyPage(tester, locale: const Locale('en'));

    await tester.tap(find.byKey(const Key('alarm_permission_switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.text("I'll do it later."));
    await tester.pumpAndSettle();

    expect(alarmRepository.updatedSettings, [false]);
    expect(cancelAllUseCase.callCount, 1);
    expect(
      tester
          .widget<Switch>(find.byKey(const Key('alarm_permission_switch')))
          .value,
      isFalse,
    );
  });
}

Future<void> _pumpMyPage(
  WidgetTester tester, {
  required Locale locale,
  PrivacyPolicyLauncher? openPrivacyPolicy,
  NotificationPermissionGateway? notificationPermissionGateway,
}) async {
  final notificationGateway =
      notificationPermissionGateway ?? _FakeNotificationPermissionGateway();
  await tester.pumpWidget(
    MaterialApp(
      theme: themeData,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider<AuthBloc>.value(
        value: _StubAuthBloc(),
        child: MyPageScreen(
          openPrivacyPolicy: openPrivacyPolicy,
          notificationPermissionGateway: notificationGateway,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeNotificationPermissionGateway
    implements NotificationPermissionGateway {
  _FakeNotificationPermissionGateway({
    this.currentStatus = AuthorizationStatus.denied,
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
  Future<void> initializeNotifications() async {
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
}

class _StubAuthBloc extends Mock implements AuthBloc {
  @override
  AuthState get state => const AuthState.loading();

  @override
  Stream<AuthState> get stream => const Stream.empty();

  @override
  bool get isClosed => false;
}

class _FakeAlarmRepository implements AlarmRepository {
  AlarmSettings settings = const AlarmSettings(alarmsEnabled: false);
  final updatedSettings = <bool>[];

  @override
  Future<String> getDeviceId() => throw UnimplementedError();

  @override
  Future<AlarmDeviceInfo> buildCurrentDeviceInfo() =>
      throw UnimplementedError();

  @override
  Future<AlarmSettings> getAlarmSettings() async {
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
  @override
  Future<List<ScheduledAlarmRecord>> loadAll() async => const [];

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
    return permission;
  }
}

class _FakeFallbackAlarmNotificationService
    implements FallbackAlarmNotificationService {
  @override
  Future<AlarmPermissionState> checkPermission() async {
    return AlarmPermissionState.unsupported;
  }

  @override
  Future<AlarmPermissionState> requestPermission() {
    throw UnimplementedError();
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

  @override
  Future<AlarmReconciliationResult> call() async {
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
