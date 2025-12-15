import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:on_time_front/core/constants/environment_variable.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/core/services/device_info_service/shared.dart';
import 'package:on_time_front/core/services/notification_service.dart';
import 'package:on_time_front/firebase_options.dart';
import 'package:on_time_front/presentation/app/screens/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  configureDependencies();
  debugPrint(EnvironmentVariable.restApiUrl);
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } else {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  debugPrint('[FCM Main] Firebase 초기화 완료');

  final permission =
      await NotificationService.instance.checkNotificationPermission();
  debugPrint('[FCM Main] Notification Permission: $permission');

  if (permission == AuthorizationStatus.authorized) {
    await NotificationService.instance.initialize();
  } else {
    debugPrint('[FCM Main] 알림 권한이 없어 NotificationService를 초기화하지 않습니다');
  }

  debugPrint(DeviceInfoService.isInStandaloneMode.toString());
  runApp(App());
}
