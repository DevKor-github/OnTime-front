import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/presentation/app/bloc/app_bloc.dart';
import 'package:on_time_front/presentation/calendar/screens/calendar_screen.dart';
import 'package:on_time_front/presentation/home/screens/home_screen.dart';
import 'package:on_time_front/presentation/login/screens/sign_in_main_screen.dart';
import 'package:on_time_front/presentation/onboarding/screens/onboarding_screen.dart';
import 'package:on_time_front/presentation/onboarding/screens/onboarding_start_screen.dart';
import 'package:on_time_front/presentation/schedule_create/compoenent/preparation_edit_form.dart';
import 'package:on_time_front/presentation/schedule_create/screens/schedule_create_screen.dart';
import 'package:on_time_front/presentation/schedule_create/screens/schedule_edit_screen.dart';
import 'package:on_time_front/presentation/shared/utils/stream_to_listenable.dart';

GoRouter goRouterConfig(AppBloc bloc) {
  return GoRouter(
    refreshListenable: StreamToListenable([bloc.stream]),
    redirect: (BuildContext context, GoRouterState state) {
      final status = bloc.state.status;
      final bool onSignInScreen = state.fullPath == '/signIn';
      final bool onOnbaordingStartScreen =
          state.fullPath == '/onboarding/start';
      final bool onOnboardingScreen = state.fullPath == '/onboarding';
      return null;
      switch (status) {
        case AppStatus.unauthenticated:
          return '/signIn';
        case AppStatus.authenticated:
          if (onSignInScreen || onOnboardingScreen || onOnbaordingStartScreen) {
            return '/home';
          } else {
            return null;
          }
        case AppStatus.onboardingNotCompleted:
          if (onOnboardingScreen || onOnbaordingStartScreen) {
            return null;
          } else {
            return '/onboarding/start';
          }
      }
    },
    initialLocation: '/onboarding',
    routes: [
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
      GoRoute(
        path: '/home',
        builder: (context, state) => HomeScreen(),
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
    ],
  );
}
