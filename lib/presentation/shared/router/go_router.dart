import 'package:go_router/go_router.dart';
import 'package:on_time_front/presentation/calendar/screens/calendar_screen.dart';
import 'package:on_time_front/presentation/home/screens/home_screen.dart';
import 'package:on_time_front/presentation/onboarding/onboarding_screen.dart';

final goRouterConfig = GoRouter(
  initialLocation: '/calendar',
  routes: [
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => OnboardingScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => HomeScreen(),
    ),
    GoRoute(path: '/calendar', builder: (context, state) => CalendarScreen()),
  ],
);
