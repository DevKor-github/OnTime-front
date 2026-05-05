import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:on_time_front/core/constants/environment_variable.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/core/services/device_info_service/shared.dart';
import 'package:on_time_front/firebase_options.dart';
import 'package:on_time_front/presentation/app/screens/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  configureDependencies();
  debugPrint(EnvironmentVariable.restApiUrl);
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('[FCM Main] Firebase 초기화 완료');

  debugPrint(DeviceInfoService.isInStandaloneMode.toString());
  runApp(App());
}
