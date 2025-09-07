import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/core/services/navigation_service.dart';
import 'package:on_time_front/core/services/notification_service.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/presentation/alarm/screens/alarm_screen.dart';
import 'package:on_time_front/presentation/alarm/screens/schedule_start_screen.dart';
import 'package:on_time_front/presentation/app/bloc/auth/auth_bloc.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';
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
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/screens/preparation_edit_form.dart';
import 'package:on_time_front/presentation/schedule_create/screens/schedule_create_screen.dart';
import 'package:on_time_front/presentation/schedule_create/screens/schedule_edit_screen.dart';
import 'package:on_time_front/presentation/shared/components/bottom_nav_bar_scaffold.dart';
import 'package:on_time_front/presentation/shared/utils/stream_to_listenable.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey();

GoRouter goRouterConfig(AuthBloc authBloc, ScheduleBloc scheduleBloc) {
  return GoRouter(
    refreshListenable:
        StreamToListenable([scheduleBloc.stream, authBloc.stream]),
    navigatorKey: getIt.get<NavigationService>().navigatorKey,
    redirect: (BuildContext context, GoRouterState state) async {
      print('state.fullPath: ${state.fullPath}');
      final authStatus = authBloc.state.status;
      final scheduleStatus = scheduleBloc.state.status;
      final bool onSignInScreen = state.fullPath == '/signIn';
      final bool onOnbaordingStartScreen =
          state.fullPath == '/onboarding/start';
      final bool onOnboardingScreen = state.fullPath == '/onboarding';

      switch (authStatus) {
        case AuthStatus.unauthenticated:
          return '/signIn';
        case AuthStatus.authenticated:
          if (onSignInScreen || onOnboardingScreen || onOnbaordingStartScreen) {
            final permission = await NotificationService.instance
                .checkNotificationPermission();
            if (permission != AuthorizationStatus.authorized) {
              return '/allowNotification';
            }
            return '/home';
          } else if (scheduleStatus == ScheduleStatus.starting) {
            return '/scheduleStart';
          } else {
            return null;
          }
        case AuthStatus.onboardingNotCompleted:
          if (onOnboardingScreen || onOnbaordingStartScreen) {
            return null;
          } else {
            return '/onboarding/start';
          }
      }
    },
    initialLocation: '/home',
    routes: [
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
      GoRoute(path: '/calendar', builder: (context, state) => CalendarScreen()),
      GoRoute(
          path: '/scheduleCreate',
          builder: (context, state) => ScheduleCreateScreen()),
      GoRoute(
          path: '/scheduleEdit/:scheduleId',
          builder: (context, state) => ScheduleEditScreen(
              scheduleId: state.pathParameters['scheduleId']!)),
      GoRoute(
          path: '/preparationEdit',
          builder: (context, state) => PreparationEditForm(
              preparationEntity: state.extra as PreparationEntity)),
      GoRoute(
        path: '/scheduleStart',
        name: 'scheduleStart',
        builder: (context, state) {
          return ScheduleStartScreen(schedule: state.extra as ScheduleEntity);
        },
      ),
      GoRoute(
        path: '/alarmScreen',
        builder: (context, state) {
          final schedule = state.extra as ScheduleEntity;
          return AlarmScreen(schedule: schedule);
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
