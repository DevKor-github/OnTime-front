import 'package:on_time_front/core/database/bootstrap_privacy_boundary.dart';
import 'package:on_time_front/core/services/runtime_privacy_migration.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/core/database/local_data_lifecycle.dart';
import 'package:on_time_front/core/logging/app_logger.dart';
import 'package:on_time_front/core/services/device_info_service/shared.dart';
import 'package:on_time_front/core/services/notification_service.dart';
import 'package:on_time_front/core/services/notification_tap_router.dart';
import 'package:on_time_front/presentation/app/screens/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.configureFlutterDebugPrint();
  await HardwareKeyboard.instance.syncKeyboardState().catchError((_) {});
  await initializeDateFormatting();
  await bootstrapWithPrivacyCleanup(
    bootstrap: LocalDataLifecycle.bootstrap,
    cleanup: RuntimePrivacyMigration.clearLegacyWithoutDatabase,
  );
  configureDependencies();
  NotificationService.instance.configureDelegate(
    notificationTapRouter: getIt.get<NotificationTapRouter>(),
  );

  AppLogger.debug(
    'Device standalone mode=${DeviceInfoService.isInStandaloneMode}',
  );
  runApp(App());
}
