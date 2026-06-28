import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/core/logging/app_logger.dart';
import 'package:on_time_front/core/services/device_info_service/shared.dart';
import 'package:on_time_front/core/services/notification_service.dart';
import 'package:on_time_front/core/services/notification_tap_router.dart';
import 'package:on_time_front/core/services/notification_token_registrar.dart';
import 'package:on_time_front/firebase_options.dart';
import 'package:on_time_front/presentation/app/screens/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.configureFlutterDebugPrint();
  await HardwareKeyboard.instance.syncKeyboardState().catchError((_) {});
  await initializeDateFormatting();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  AppLogger.debug('[FCM Main] Firebase initialized');
  configureDependencies();
  NotificationService.instance.configureDelegates(
    fcmTokenRegistrar: getIt.get<FcmTokenRegistrar>(),
    notificationTapRouter: getIt.get<NotificationTapRouter>(),
  );

  AppLogger.debug(
    'Device standalone mode=${DeviceInfoService.isInStandaloneMode}',
  );
  runApp(App());
}
