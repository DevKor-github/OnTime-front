import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_time_front/presentation/home/home_screen.dart';
import 'package:on_time_front/presentation/onboarding/onboarding_screen.dart';
import 'package:on_time_front/presentation/shared/router/go_router.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

void main() async {
  runApp(const ProviderScope(child: MyApp()));
  WidgetsFlutterBinding.ensureInitialized();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: goRouterConfig,
      theme: themeData,
    );
  }
}
