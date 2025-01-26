import 'package:flutter/material.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/presentation/shared/router/go_router.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

void main() async {
  configureDependencies();
  runApp(MyApp());
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
