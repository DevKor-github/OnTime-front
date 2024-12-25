import 'package:go_router/go_router.dart';
import 'package:on_time_front/presentation/home/home_screen.dart';
import 'package:on_time_front/presentation/onboarding/onboarding_screen.dart';

final goRouterConfig = GoRouter(
  initialLocation: '/onboarding',
  routes: [
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => OnboardingScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => HomeScreen(),
    ),
  ],
);
