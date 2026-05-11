import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/core/services/notification_service.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/app/cubit/notification_gate_cubit.dart';
import 'package:on_time_front/presentation/notification_allow/screens/notification_allow_screen.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows English schedule preparation reminder rationale', (
    tester,
  ) async {
    final harness = await _pumpNotificationAllowScreen(
      tester,
      locale: const Locale('en'),
      permissionGateway: _FakePermissionGateway(
        currentStatus: AuthorizationStatus.notDetermined,
      ),
    );
    addTearDown(harness.dispose);

    expect(
      find.text(
        'OnTime sends schedule preparation reminders so you can get ready on time.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows Korean schedule preparation reminder rationale', (
    tester,
  ) async {
    final harness = await _pumpNotificationAllowScreen(
      tester,
      locale: const Locale('ko'),
      permissionGateway: _FakePermissionGateway(
        currentStatus: AuthorizationStatus.notDetermined,
      ),
    );
    addTearDown(harness.dispose);

    expect(find.text('약속 준비 리마인더를 보내\n제시간에 준비할 수 있게 도와드려요.'), findsOneWidget);
  });

  testWidgets('granted permission marks gate allowed and continues home', (
    tester,
  ) async {
    final gateService = _FakeNotificationService();
    final harness = await _pumpNotificationAllowScreen(
      tester,
      permissionGateway: _FakePermissionGateway(
        currentStatus: AuthorizationStatus.authorized,
      ),
      gateService: gateService,
    );
    addTearDown(harness.dispose);

    await tester.tap(find.text('Allow notifications'));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(gateService.initializeCount, greaterThanOrEqualTo(1));
    expect(harness.gateCubit.state.status, NotificationGateStatus.allowed);
  });

  testWidgets('not determined permission can be granted from system prompt', (
    tester,
  ) async {
    final gateService = _FakeNotificationService();
    final permissionGateway = _FakePermissionGateway(
      currentStatus: AuthorizationStatus.notDetermined,
      requestedStatus: AuthorizationStatus.authorized,
    );
    final harness = await _pumpNotificationAllowScreen(
      tester,
      permissionGateway: permissionGateway,
      gateService: gateService,
    );
    addTearDown(harness.dispose);

    await tester.tap(find.text('Allow notifications'));
    await tester.pumpAndSettle();

    expect(permissionGateway.requestCount, 1);
    expect(find.text('home'), findsOneWidget);
    expect(harness.gateCubit.state.status, NotificationGateStatus.allowed);
  });

  testWidgets('denied permission retries request without opening settings', (
    tester,
  ) async {
    final permissionGateway = _FakePermissionGateway(
      currentStatus: AuthorizationStatus.denied,
    );
    final harness = await _pumpNotificationAllowScreen(
      tester,
      permissionGateway: permissionGateway,
    );
    addTearDown(harness.dispose);

    await tester.tap(find.text('Allow notifications'));
    await tester.pumpAndSettle();

    expect(permissionGateway.requestCount, 1);
    expect(permissionGateway.openSettingsCount, 0);
    expect(find.text('home'), findsOneWidget);
    expect(harness.gateCubit.state.status, NotificationGateStatus.dismissed);
  });

  testWidgets('manual settings grant still continues home on app resume', (
    tester,
  ) async {
    final gateService = _FakeNotificationService();
    final permissionGateway = _FakePermissionGateway(
      currentStatus: AuthorizationStatus.denied,
    );
    final harness = await _pumpNotificationAllowScreen(
      tester,
      permissionGateway: permissionGateway,
      gateService: gateService,
    );
    addTearDown(harness.dispose);

    permissionGateway.currentStatus = AuthorizationStatus.authorized;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(gateService.initializeCount, greaterThanOrEqualTo(1));
    expect(harness.gateCubit.state.status, NotificationGateStatus.allowed);
  });

  testWidgets('request denial lets user dismiss prompt and continue home', (
    tester,
  ) async {
    final permissionGateway = _FakePermissionGateway(
      currentStatus: AuthorizationStatus.notDetermined,
      requestedStatus: AuthorizationStatus.denied,
    );
    final harness = await _pumpNotificationAllowScreen(
      tester,
      permissionGateway: permissionGateway,
    );
    addTearDown(harness.dispose);

    await tester.tap(find.text('Allow notifications'));
    await tester.pumpAndSettle();

    expect(permissionGateway.requestCount, 1);
    expect(find.text('home'), findsOneWidget);
    expect(harness.gateCubit.state.status, NotificationGateStatus.dismissed);
  });
}

Future<_NotificationAllowHarness> _pumpNotificationAllowScreen(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  required NotificationPermissionGateway permissionGateway,
  _FakeNotificationService? gateService,
}) async {
  final notificationService = gateService ?? _FakeNotificationService();
  final gateCubit = NotificationGateCubit(
    notificationService: notificationService,
  );
  final router = GoRouter(
    initialLocation: '/allowNotification',
    routes: [
      GoRoute(
        path: '/allowNotification',
        builder: (context, state) => BlocProvider<NotificationGateCubit>.value(
          value: gateCubit,
          child: NotificationAllowScreen(permissionGateway: permissionGateway),
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

  return _NotificationAllowHarness(gateCubit: gateCubit, router: router);
}

class _NotificationAllowHarness {
  _NotificationAllowHarness({required this.gateCubit, required this.router});

  final NotificationGateCubit gateCubit;
  final GoRouter router;

  void dispose() {
    gateCubit.close();
    router.dispose();
  }
}

class _FakePermissionGateway implements NotificationPermissionGateway {
  _FakePermissionGateway({
    required this.currentStatus,
    this.requestedStatus = AuthorizationStatus.denied,
  });

  AuthorizationStatus currentStatus;
  final AuthorizationStatus requestedStatus;
  int requestCount = 0;
  int openSettingsCount = 0;

  @override
  Future<AuthorizationStatus> checkNotificationPermission() async {
    return currentStatus;
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

class _FakeNotificationService implements NotificationService {
  _FakeNotificationService();

  int initializeCount = 0;

  @override
  Future<AuthorizationStatus> checkNotificationPermission() async {
    return AuthorizationStatus.notDetermined;
  }

  @override
  Future<void> initialize() async {
    initializeCount += 1;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
