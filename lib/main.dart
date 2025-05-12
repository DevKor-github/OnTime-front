import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:on_time_front/core/constants/environment_variable.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/core/services/device_info_service/shared.dart';
import 'package:on_time_front/core/services/notification_service.dart';
import 'package:on_time_front/firebase_options.dart';
import 'package:on_time_front/presentation/app/screens/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureDependencies();
  debugPrint(EnvironmentVariable.restApiUrl);
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } else {
    await Firebase.initializeApp();
  }
  NotificationService.instance.initialize();
  debugPrint(DeviceInfoService.isInStandaloneMode.toString());
  runApp(App());
}
