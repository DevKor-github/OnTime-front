import 'package:on_time_front/domain/entities/preparation_action_event_entity.dart';
import 'package:rxdart/rxdart.dart';
import 'package:on_time_front/domain/entities/early_start_session_entity.dart';
import 'package:on_time_front/presentation/alarm/screens/alarm_screen.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/core/services/navigation_service.dart';
import 'package:on_time_front/core/services/notification_tap_router.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/use-cases/get_nearest_upcoming_schedule_use_case.dart';
import 'package:on_time_front/domain/use-cases/schedule_preparation_session_use_case.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/alarm/screens/schedule_start_screen.dart';
import 'package:on_time_front/presentation/app/bloc/auth/auth_bloc.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';
import 'package:on_time_front/presentation/app/cubit/alarm_gate_cubit.dart';
import 'package:on_time_front/presentation/app/cubit/notification_gate_cubit.dart';
import 'package:on_time_front/presentation/calendar/bloc/monthly_schedules_bloc.dart';
import 'package:on_time_front/presentation/shared/router/go_router.dart';
import '../../../core/services/notification_tap_router_test.dart'
    show tapPayload, tapSchedule;
import 'package:on_time_front/presentation/shared/theme/theme.dart';

void main() {
  setUpAll(() async {
    final loader = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      loader.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.ttf'));
    }
    await loader.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final (viewport, oldId) in [
    for (final viewport in [const Size(390, 844), const Size(430, 932)])
      for (final oldId in ['B', 'old']) (viewport, oldId),
  ]) {
    testWidgets(
      'production router gates, exact target, dedupe and retap from old $oldId at ${viewport.width}',
      (tester) async {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await getIt.reset();
        final navigation = NavigationService();
        getIt.registerSingleton<NavigationService>(navigation);
        getIt.registerFactory<MonthlySchedulesBloc>(() => _Monthly());
        final auth = _Auth();
        final notifications = _Notifications();
        final alarms = _Alarms();
        final session = _Session();
        final nearest = _Nearest();
        final bloc = ScheduleBloc.test(nearest, navigation, session);
        final router = goRouterConfig(auth, notifications, alarms);
        final taps = NavigationNotificationTapRouter(navigation);
        var resolutions = 0;
        bool ready() =>
            appRedirectLocation(
                  authStatus: auth.state.status,
                  notificationGateState: notifications.state,
                  alarmGateState: alarms.state,
                  path: '/scheduleStart',
                ) ==
                null &&
            navigation.navigatorKey.currentContext != null;
        taps.configure(
          isReady: ready,
          resolve: (id, current) async {
            resolutions++;
            return SchedulePreparationPromptResult.ready(tapSchedule(id));
          },
        );
        router.routerDelegate.addListener(taps.retry);
        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(value: auth),
              BlocProvider<NotificationGateCubit>.value(value: notifications),
              BlocProvider<AlarmGateCubit>.value(value: alarms),
              BlocProvider<ScheduleBloc>.value(value: bloc),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              theme: themeData,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('en'),
            ),
          ),
        );
        final oldOwner = Object();
        bloc.presentNotificationPrompt(
          tapSchedule(oldId),
          oldOwner,
          () => true,
        );
        await tester.pump();
        bloc.releaseNotificationPrompt(oldOwner, resumeNearest: false);
        taps.routeLocalNotificationTap(tapPayload('A'));
        taps.routeLocalNotificationTap(tapPayload('B'));
        await tester.pump();
        expect(resolutions, 0);
        auth.set(
          const AuthState.loading().copyWith(status: AuthStatus.authenticated),
        );
        notifications.set(const NotificationGateState.required());
        await tester.pump();
        await tester.pump();
        expect(
          router.routeInformationProvider.value.uri.path,
          '/allowNotification',
        );
        expect(resolutions, 0);
        expect(tester.takeException(), isNull, reason: 'permission gate');
        // Denial/dismissal resolves the UI gate; it must not discard the old tap.
        notifications.set(const NotificationGateState.dismissed());
        alarms.set(const AlarmGateState.dismissed());
        await tester.pump();
        await tester.pump();
        taps.retry();
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull, reason: 'first confirmation');
        expect(find.byType(ScheduleStartScreen), findsOneWidget);
        expect(find.text('Schedule B'), findsOneWidget);
        expect(find.text('Schedule A'), findsNothing);
        expect(bloc.state.schedule?.id, 'B');
        expect(session.starts, 0);
        expect(resolutions, 1);
        taps.routeLocalNotificationTap(tapPayload('B'));
        await tester.pump();
        expect(resolutions, 1);
        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text("I'll stay"));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(ScheduleStartScreen), findsOneWidget);
        expect(
          router.routerDelegate.currentConfiguration.last.route.path,
          '/scheduleStart',
        );
        expect(session.starts, 0);
        // Background nearest subscription cannot replace the notification target.
        await tester.runAsync(() => Future<void>(() {}));
        await tester.pump();
        nearest.subject.add(tapSchedule('nearest-C'));
        bloc.add(ScheduleUpcomingReceived(tapSchedule('nearest-C')));
        await tester.pump();
        expect(bloc.state.schedule?.id, 'B');
        router.push('/privacyPolicy');
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull, reason: 'privacy page');
        router.pop();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(ScheduleStartScreen), findsNothing);
        expect(router.routeInformationProvider.value.uri.path, '/home');
        expect(bloc.state.schedule?.id, 'nearest-C');
        expect(find.text('Schedule nearest-C'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'home after pop');
        taps.routeLocalNotificationTap(tapPayload('B'));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(ScheduleStartScreen), findsOneWidget);
        expect(resolutions, 2);
        expect(session.starts, 0);
        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await LocalDataOperationGate.shared.run(
          () async {},
          replacesData: true,
        );
        await tester.tap(find.text("I'll stay"));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(ScheduleStartScreen), findsNothing);
        expect(session.starts, 0);
        taps.routeLocalNotificationTap(tapPayload('B'));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        taps.routeLocalNotificationTap(tapPayload('C'));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Schedule C'), findsOneWidget);
        expect(session.starts, 0);
        await tester.tap(find.text('Start Preparing'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(session.startedIds, ['C']);
        expect(bloc.state.schedule?.id, 'C');
        expect(find.byType(AlarmScreen), findsOneWidget);
        await tester.pump(const Duration(seconds: 2));
        await tester.runAsync(() => Future<void>(() {}));
        await tester.pump();
        nearest.subject.add(tapSchedule('nearest-C'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        expect(session.startedIds, ['C']);
        expect(bloc.state.schedule?.id, 'C');
        expect(bloc.notificationPreparationId, 'C');
        expect(find.byType(AlarmScreen), findsOneWidget);
        expect(find.text('Prepare C'), findsWidgets);
        expect(find.text('Prepare nearest-C'), findsNothing);
        final ownerC = bloc.notificationPreparationOwner;
        taps.routeLocalNotificationTap(tapPayload('D'));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Schedule D'), findsOneWidget);
        await tester.tap(find.text('Start Preparing'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        expect(session.startedIds, ['C', 'D']);
        expect(bloc.notificationPreparationId, 'D');
        expect(identical(ownerC, bloc.notificationPreparationOwner), isFalse);
        await tester.runAsync(() => Future<void>(() {}));
        await tester.pump();
        nearest.subject.add(tapSchedule('nearest-D'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        expect(bloc.state.schedule?.id, 'D');
        expect(find.text('Prepare D'), findsWidgets);
        expect(find.text('Prepare nearest-D'), findsNothing);
        router.go('/home');
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        // Page disposal releases the selected session after the transition;
        // allow its nearest stream subscription to replay on the next frame.
        await tester.pump();
        await tester.pump();
        await tester.runAsync(() => Future<void>(() {}));
        await tester.pump();
        expect(bloc.notificationPreparationId, isNull);
        expect(bloc.state.schedule?.id, 'nearest-D');
        await tester.pump();
        expect(find.text('Schedule nearest-D'), findsOneWidget);
        expect(session.startedIds, ['C', 'D']);
        taps.detach();
        router.routerDelegate.removeListener(taps.retry);
        await tester.pumpWidget(const SizedBox());
        router.dispose();
        await tester.runAsync(() async {
          await bloc.close();
          await auth.close();
          await notifications.close();
          await alarms.close();
          await nearest.subject.close();
          await getIt.reset();
        });
      },
    );
  }
}

class _Auth extends Cubit<AuthState> implements AuthBloc {
  _Auth() : super(const AuthState.loading());
  void set(AuthState value) => emit(value);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Notifications extends Cubit<NotificationGateState>
    implements NotificationGateCubit {
  _Notifications() : super(const NotificationGateState.initial());
  void set(NotificationGateState value) => emit(value);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Alarms extends Cubit<AlarmGateState> implements AlarmGateCubit {
  _Alarms() : super(const AlarmGateState.initial());
  void set(AlarmGateState value) => emit(value);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Monthly extends Cubit<MonthlySchedulesState>
    implements MonthlySchedulesBloc {
  _Monthly() : super(const MonthlySchedulesState());
  @override
  void add(MonthlySchedulesEvent event) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Nearest implements GetNearestUpcomingScheduleUseCase {
  final subject = BehaviorSubject<ScheduleWithPreparationEntity?>.seeded(null);
  @override
  Stream<ScheduleWithPreparationEntity?> call() => subject.stream;
}

class _Session implements SchedulePreparationSessionUseCase {
  final startedIds = <String>[];
  int get starts => startedIds.length;
  @override
  Future<PreparationStartReceipt> startEarlySession(
    ScheduleWithPreparationEntity schedule, {
    required DateTime startedAt,
    bool Function()? isCurrent,
  }) async {
    startedIds.add(schedule.id);
    return PreparationStartReceipt(startedAt: startedAt);
  }

  @override
  Future<EarlyStartSessionEntity?> getEarlyStartSession(String id) async =>
      null;
  @override
  Future<void> clearPersistedState(String id) async {}
  @override
  Future<ScheduleWithPreparationEntity> restoreTimedPreparationIfValid(
    ScheduleWithPreparationEntity schedule, {
    required DateTime now,
    RestoredSessionCallback? onRestoredSession,
    void Function()? onInvalidated,
  }) async => schedule;
  @override
  Future<void> saveTimedPreparationSnapshot(
    ScheduleWithPreparationEntity schedule, {
    DateTime? savedAt,
    DateTime? startedAt,
    List<PreparationActionEventEntity> actionEvents = const [],
    bool persist = true,
  }) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
