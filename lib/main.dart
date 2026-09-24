import 'package:on_time_front/core/database/bootstrap_privacy_boundary.dart';
import 'package:on_time_front/core/services/runtime_privacy_migration.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/core/database/local_data_lifecycle.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/domain/use-cases/local_data_workflows.dart';
import 'package:on_time_front/data/adapters/local_data_workflow_adapters.dart';
import 'package:on_time_front/core/logging/app_logger.dart';
import 'package:on_time_front/core/services/device_info_service/shared.dart';
import 'package:on_time_front/core/services/notification_service.dart';
import 'package:on_time_front/core/services/notification_tap_router.dart';
import 'package:on_time_front/presentation/app/screens/app.dart';
import 'package:on_time_front/presentation/startup/screens/local_startup_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.configureFlutterDebugPrint();
  runApp(
    LocalStartupGate(
      prepare: () async {
        await HardwareKeyboard.instance.syncKeyboardState().catchError((_) {});
        await initializeDateFormatting();
        // Recovery owns its own cleanup evidence. A failed reset must not fall
        // into an unrelated best-effort cleanup that discards its registry.
        await bootstrapWithPrivacyCleanup(
          bootstrap: LocalDataLifecycle.bootstrap,
          cleanup: RuntimePrivacyMigration.clearLegacyWithoutDatabase,
          shouldCleanup: (error) => error is! LocalResetRecoveryRequired,
        );
      },
      retryReset: LocalResetWorkflow(
        RecoveryResetAdapter(LocalDataLifecycle.resumeReset),
      ).call,
      ready: () {
        configureDependencies();
        NotificationService.instance.configureDelegate(
          notificationTapRouter: getIt.get<NotificationTapRouter>(),
        );
        AppLogger.debug(
          'Device standalone mode=${DeviceInfoService.isInStandaloneMode}',
        );
        return ResetAwareApp(
          gate: LocalDataOperationGate.shared,
          reset: () => getIt<LocalResetWorkflow>()(),
          child: const App(),
        );
      },
    ),
  );
}
