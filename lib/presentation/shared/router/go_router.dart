import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/core/services/navigation_service.dart';
import 'package:on_time_front/presentation/alarm/screens/alarm_screen.dart';
import 'package:on_time_front/presentation/alarm/screens/schedule_start_screen.dart';
import 'package:on_time_front/presentation/app/bloc/auth/auth_bloc.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';
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
import 'package:on_time_front/presentation/shared/utils/stream_to_listenable.dart';
import 'package:on_time_front/presentation/startup/screens/startup_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey();

GoRouter goRouterConfig(
  AuthBloc authBloc,
  ScheduleBloc scheduleBloc,
  NotificationGateCubit notificationGateCubit,
) {
  return GoRouter(
    refreshListenable: StreamToListenable([
      scheduleBloc.stream,
      authBloc.stream,
      notificationGateCubit.stream,
    ]),
    navigatorKey: getIt.get<NavigationService>().navigatorKey,
    redirect: (BuildContext context, GoRouterState state) {
      final authStatus = authBloc.state.status;
      final notificationGateStatus = notificationGateCubit.state.status;
      final path = state.uri.path;
      final isStartupRoute = path == '/startup';
      final isPublicRoute = isStartupRoute || path == '/signIn';
      final isOnboardingRoute =
          path == '/onboarding' || path == '/onboarding/start';
      final isNotificationRoute = path == '/allowNotification';
      final isTransientRoute =
          isPublicRoute || isOnboardingRoute || isNotificationRoute;

      switch (authStatus) {
        case AuthStatus.loading:
          return isStartupRoute ? null : '/startup';
        case AuthStatus.unauthenticated:
          return path == '/signIn' ? null : '/signIn';
        case AuthStatus.authenticated:
          if (!notificationGateCubit.state.isResolved) {
            return isStartupRoute ? null : '/startup';
          }
          if (notificationGateStatus == NotificationGateStatus.required) {
            return isNotificationRoute ? null : '/allowNotification';
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
        builder: (context, state) => const StartupScreen(),
      ),
      GoRoute(
        path: '/allowNotification',
        builder: (context, state) {
          return NotificationAllowScreen();
        },
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => OnboardingScreen(),
        routes: [
          GoRoute(
            path: '/start',
            builder: (context, state) => OnboardingStartScreen(),
          )
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => BottomNavBarScaffold(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => HomeScreenTmp(),
          ),
          GoRoute(
            path: '/myPage',
            builder: (context, state) => MyPageScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/defaultPreparationSpareTimeEdit',
        builder: (context, state) => PreparationSpareTimeEditScreen(),
      ),
      GoRoute(path: '/signIn', builder: (context, state) => SignInMainScreen()),
      GoRoute(
        path: '/calendar',
        builder: (context, state) => CalendarScreen(
          initialDate: state.extra as DateTime?,
        ),
      ),
      GoRoute(
          path: '/scheduleCreate',
          builder: (context, state) => ScheduleCreateScreen()),
      GoRoute(
          path: '/scheduleEdit/:scheduleId',
          builder: (context, state) => ScheduleEditScreen(
              scheduleId: state.pathParameters['scheduleId']!)),
      GoRoute(
          path: '/preparationEdit',
          builder: (context, state) => const PreparationEditForm()),
      GoRoute(
        path: '/scheduleStart',
        name: 'scheduleStart',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return _ScheduleStartRouteGate(extra: extra);
        },
      ),
      GoRoute(
        path: '/alarmScreen',
        builder: (context, state) {
          return AlarmScreen();
        },
      ),
      GoRoute(
        path: '/earlyLate',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          final earlyLateTime = extra['earlyLateTime'] as int;
          final isLate = extra['isLate'] as bool;

          return EarlyLateScreen(
            earlyLateTime: earlyLateTime,
            isLate: isLate,
          );
        },
      ),
      GoRoute(
        path: '/moving',
        builder: (context, state) => MovingScreen(),
      ),
    ],
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
    final scheduleId = widget.extra?['scheduleId']?.toString();
    if (scheduleId == null || scheduleId.isEmpty) return;
    _requestedValidation = true;
    context.read<ScheduleBloc>().add(
          ScheduleAlarmPromptRequested(
            scheduleId: scheduleId,
            scheduleFingerprint:
                widget.extra?['scheduleFingerprint']?.toString(),
            startPreparation: scheduleStartLaunchActionFromRouteExtra(
                  widget.extra,
                ) ==
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

    final scheduleId = widget.extra?['scheduleId']?.toString();
    final scheduleFingerprint =
        widget.extra?['scheduleFingerprint']?.toString();
    final allowsStaleFingerprint = scheduleStartLaunchActionFromRouteExtra(
          widget.extra,
        ) ==
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

    final promptVariant =
        scheduleStartPromptVariantFromRouteExtra(widget.extra);
    return ScheduleStartScreen(promptVariant: promptVariant);
  }
}
