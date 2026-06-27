import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/core/services/navigation_service.dart';
import 'package:on_time_front/presentation/alarm/screens/alarm_screen.dart';
import 'package:on_time_front/presentation/alarm/screens/schedule_start_screen.dart';
import 'package:on_time_front/presentation/alarm_allow/screens/alarm_allow_screen.dart';
import 'package:on_time_front/presentation/app/bloc/auth/auth_bloc.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';
import 'package:on_time_front/presentation/app/cubit/alarm_gate_cubit.dart';
import 'package:on_time_front/presentation/app/cubit/notification_gate_cubit.dart';
import 'package:on_time_front/presentation/early_late/screens/early_late_screen.dart';
import 'package:on_time_front/presentation/calendar/screens/calendar_screen.dart';
import 'package:on_time_front/presentation/home/screens/home_screen_tmp.dart';
import 'package:on_time_front/presentation/login/screens/sign_in_main_screen.dart';
import 'package:on_time_front/presentation/moving/screens/moving_screen.dart';
import 'package:on_time_front/presentation/my_page/my_page_screen.dart';
import 'package:on_time_front/presentation/my_page/preparation_spare_time_edit/preparation_spare_time_edit_screen.dart';
import 'package:on_time_front/presentation/notification_allow/screens/notification_allow_screen.dart';
import 'package:on_time_front/presentation/onboarding/screens/onboarding_screen.dart';
import 'package:on_time_front/presentation/onboarding/screens/onboarding_start_screen.dart';
import 'package:on_time_front/presentation/shared/components/loading_screen.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/screens/preparation_edit_form.dart';
import 'package:on_time_front/presentation/schedule_create/screens/schedule_create_screen.dart';
import 'package:on_time_front/presentation/schedule_create/screens/schedule_edit_screen.dart';
import 'package:on_time_front/presentation/shared/components/bottom_nav_bar_scaffold.dart';
import 'package:on_time_front/presentation/shared/router/app_route_transition.dart';
import 'package:on_time_front/presentation/shared/router/route_arguments.dart';
import 'package:on_time_front/presentation/shared/utils/stream_to_listenable.dart';
import 'package:on_time_front/presentation/startup/screens/startup_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey();

GoRouter goRouterConfig(
  AuthBloc authBloc,
  ScheduleBloc scheduleBloc,
  NotificationGateCubit notificationGateCubit,
  AlarmGateCubit alarmGateCubit,
) {
  return GoRouter(
    refreshListenable: StreamToListenable([
      scheduleBloc.stream,
      authBloc.stream,
      notificationGateCubit.stream,
      alarmGateCubit.stream,
    ]),
    navigatorKey: getIt.get<NavigationService>().navigatorKey,
    redirect: (BuildContext context, GoRouterState state) {
      final authStatus = authBloc.state.status;
      final notificationGateStatus = notificationGateCubit.state.status;
      final alarmGateStatus = alarmGateCubit.state.status;
      final path = state.uri.path;
      final isStartupRoute = path == '/startup';
      final isPublicRoute = isStartupRoute || path == '/signIn';
      final isOnboardingRoute =
          path == '/onboarding' || path == '/onboarding/start';
      final isNotificationRoute = path == '/allowNotification';
      final isAlarmRoute = path == '/allowAlarm';
      final isTransientRoute =
          isPublicRoute ||
          isOnboardingRoute ||
          isNotificationRoute ||
          isAlarmRoute;

      switch (authStatus) {
        case AuthStatus.loading:
          return isStartupRoute ? null : '/startup';
        case AuthStatus.unauthenticated:
          return path == '/signIn' ? null : '/signIn';
        case AuthStatus.authenticated:
          if (!notificationGateCubit.state.isResolved ||
              !alarmGateCubit.state.isResolved) {
            return isStartupRoute ? null : '/startup';
          }
          if (notificationGateStatus == NotificationGateStatus.required) {
            return isNotificationRoute ? null : '/allowNotification';
          }
          if (alarmGateStatus == AlarmGateStatus.required) {
            return isAlarmRoute ? null : '/allowAlarm';
          }
          return isTransientRoute ? '/home' : null;
        case AuthStatus.onboardingNotCompleted:
          return isOnboardingRoute ? null : '/onboarding/start';
      }
    },
    initialLocation: '/startup',
    routes: [
      GoRoute(
        path: '/startup',
        pageBuilder: (context, state) => _buildAppRoutePage(
          state: state,
          transition: AppRouteTransition.fade,
          child: const StartupScreen(),
        ),
      ),
      GoRoute(
        path: '/allowNotification',
        pageBuilder: (context, state) => _buildAppRoutePage(
          state: state,
          transition: AppRouteTransition.fade,
          child: NotificationAllowScreen(),
        ),
      ),
      GoRoute(
        path: '/allowAlarm',
        pageBuilder: (context, state) => _buildAppRoutePage(
          state: state,
          transition: AppRouteTransition.fade,
          child: const AlarmAllowScreen(),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => _buildAppRoutePage(
          state: state,
          transition: AppRouteTransition.fade,
          child: OnboardingScreen(),
        ),
        routes: [
          GoRoute(
            path: '/start',
            pageBuilder: (context, state) => _buildAppRoutePage(
              state: state,
              transition: AppRouteTransition.fade,
              child: OnboardingStartScreen(),
            ),
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => BottomNavBarScaffold(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => _buildAppRoutePage(
              state: state,
              transition: AppRouteTransition.bottomNavFromLeft,
              child: HomeScreenTmp(),
            ),
          ),
          GoRoute(
            path: '/myPage',
            pageBuilder: (context, state) => _buildAppRoutePage(
              state: state,
              transition: AppRouteTransition.bottomNavFromRight,
              child: MyPageScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/defaultPreparationSpareTimeEdit',
        pageBuilder: (context, state) => _buildAppRoutePage(
          state: state,
          child: PreparationSpareTimeEditScreen(),
        ),
      ),
      GoRoute(
        path: '/signIn',
        pageBuilder: (context, state) => _buildAppRoutePage(
          state: state,
          transition: AppRouteTransition.fade,
          child: SignInMainScreen(),
        ),
      ),
      GoRoute(
        path: '/calendar',
        pageBuilder: (context, state) => _buildAppRoutePage(
          state: state,
          child: CalendarScreen(
            initialDate: calendarInitialDateFromState(state),
          ),
        ),
      ),
      GoRoute(
        path: '/scheduleCreate',
        pageBuilder: (context, state) =>
            _buildAppRoutePage(state: state, child: ScheduleCreateScreen()),
      ),
      GoRoute(
        path: '/scheduleEdit/:scheduleId',
        pageBuilder: (context, state) => _buildAppRoutePage(
          state: state,
          child: ScheduleEditScreen(
            scheduleId: state.pathParameters['scheduleId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/preparationEdit',
        pageBuilder: (context, state) => _buildAppRoutePage(
          state: state,
          child: const PreparationEditForm(),
        ),
      ),
      GoRoute(
        path: '/scheduleStart',
        name: 'scheduleStart',
        pageBuilder: (context, state) {
          final extra = scheduleStartRouteExtraFromState(state);
          return _buildAppRoutePage(
            state: state,
            transition: AppRouteTransition.scheduleFlow,
            child: _ScheduleStartRouteGate(extra: extra),
          );
        },
      ),
      GoRoute(
        path: '/alarmScreen',
        pageBuilder: (context, state) => _buildAppRoutePage(
          state: state,
          transition: AppRouteTransition.scheduleFlow,
          child: AlarmScreen(),
        ),
      ),
      GoRoute(
        path: '/earlyLate',
        redirect: (context, state) {
          return earlyLateRouteArgumentsFromState(state) == null
              ? '/home'
              : null;
        },
        pageBuilder: (context, state) {
          final arguments = earlyLateRouteArgumentsFromState(state);
          if (arguments == null) {
            return _buildAppRoutePage(
              state: state,
              transition: AppRouteTransition.scheduleFlow,
              child: const LoadingScreen(),
            );
          }

          return _buildAppRoutePage(
            state: state,
            transition: AppRouteTransition.scheduleFlow,
            child: EarlyLateScreen(
              earlyLateTime: arguments.earlyLateTime,
              isLate: arguments.isLate,
            ),
          );
        },
      ),
      GoRoute(
        path: '/moving',
        pageBuilder: (context, state) =>
            _buildAppRoutePage(state: state, child: MovingScreen()),
      ),
    ],
  );
}

CustomTransitionPage<void> _buildAppRoutePage({
  required GoRouterState state,
  AppRouteTransition transition = AppRouteTransition.standard,
  required Widget child,
}) {
  return buildAppRoutePage<void>(
    key: state.pageKey,
    transition: transition,
    child: child,
  );
}

class _ScheduleStartRouteGate extends StatefulWidget {
  final Map<String, dynamic>? extra;

  const _ScheduleStartRouteGate({required this.extra});

  @override
  State<_ScheduleStartRouteGate> createState() =>
      _ScheduleStartRouteGateState();
}

class _ScheduleStartRouteGateState extends State<_ScheduleStartRouteGate> {
  bool _requestedValidation = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requestedValidation) return;
    final scheduleId = routeStringValue(widget.extra?['scheduleId']);
    if (scheduleId == null || scheduleId.isEmpty) return;
    _requestedValidation = true;
    context.read<ScheduleBloc>().add(
      ScheduleAlarmPromptRequested(
        scheduleId: scheduleId,
        scheduleFingerprint: routeStringValue(
          widget.extra?['scheduleFingerprint'],
        ),
        startPreparation:
            scheduleStartLaunchActionFromRouteExtra(widget.extra) ==
            ScheduleStartLaunchAction.startPreparation,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheduleState = context.watch<ScheduleBloc>().state;
    if (scheduleState.isEarlyStarted) {
      return const AlarmScreen();
    }

    final scheduleId = routeStringValue(widget.extra?['scheduleId']);
    final scheduleFingerprint = routeStringValue(
      widget.extra?['scheduleFingerprint'],
    );
    final allowsStaleFingerprint =
        scheduleStartLaunchActionFromRouteExtra(widget.extra) ==
        ScheduleStartLaunchAction.startPreparation;
    final schedule = scheduleState.schedule;
    if (schedule == null) {
      return const LoadingScreen();
    }
    if (scheduleId != null && schedule.id != scheduleId) {
      return const LoadingScreen();
    }
    if (scheduleFingerprint != null &&
        schedule.cacheFingerprint != scheduleFingerprint &&
        !allowsStaleFingerprint) {
      return const LoadingScreen();
    }

    final promptVariant = scheduleStartPromptVariantFromRouteExtra(
      widget.extra,
    );
    return ScheduleStartScreen(promptVariant: promptVariant);
  }
}
