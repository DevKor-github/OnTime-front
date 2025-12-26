import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
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
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } else {
    await Firebase.initializeApp();
  }

  // Crashlytics is not supported on web, and we avoid noisy reporting in debug.
  if (!kIsWeb && !kDebugMode) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  debugPrint(DeviceInfoService.isInStandaloneMode.toString());
  runApp(App());
}
