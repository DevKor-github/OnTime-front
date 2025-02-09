import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/main.dart';
import 'package:on_time_front/presentation/app/bloc/app_bloc.dart';
import 'package:on_time_front/presentation/calendar/screens/calendar_screen.dart';
import 'package:on_time_front/presentation/home/screens/home_screen.dart';
import 'package:on_time_front/presentation/login/screens/sign_in_main_screen.dart';
import 'package:on_time_front/presentation/onboarding/onboarding_screen.dart';
import 'package:on_time_front/presentation/alarm/screens/alarm_screen.dart';
import 'package:on_time_front/presentation/alarm/screens/early_late_screen.dart';
import 'package:on_time_front/presentation/schedule_create/compoenent/preparation_edit_form.dart';
import 'package:on_time_front/presentation/schedule_create/screens/schedule_create_screen.dart';
import 'package:on_time_front/presentation/schedule_create/screens/schedule_edit_screen.dart';
import 'package:on_time_front/presentation/shared/utils/stream_to_listenable.dart';

GoRouter goRouterConfig(AppBloc bloc) {
  return GoRouter(
    refreshListenable: StreamToListenable([bloc.stream]),
    redirect: (BuildContext context, GoRouterState state) {
      final status = bloc.state.status;

      switch (status) {
        case AppStatus.unauthenticated:
          return '/signIn';
        case AppStatus.authenticated:
          return '/home';
        case AppStatus.onboardingNotCompleted:
          return '/onboarding';
      }
    },
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => OnboardingScreen(),
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
