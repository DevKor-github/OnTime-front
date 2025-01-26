import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_time_front/presentation/preparation/screens/schedule_list_test.dart';
import 'package:on_time_front/shared/theme/theme.dart';
// import 'package:on_time_front/widgets/login_buttons/login_test_screen.dart';

void main() async {
  runApp(const ProviderScope(child: MyApp()));
  WidgetsFlutterBinding.ensureInitialized();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: themeData,
      home: Scaffold(
        backgroundColor: Colors.grey,
        body: ScheduleListTest(),
      ),
    );
  }
}
