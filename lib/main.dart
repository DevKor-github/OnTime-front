import 'package:on_time_front/core/database/recovery/recovery_restore_service.dart';
import 'package:on_time_front/core/database/recovery/pair_files.dart';
import 'package:on_time_front/core/database/initial_store_guard.dart';
import 'package:on_time_front/core/startup/startup_dependency_scope.dart';
import 'package:on_time_front/core/startup/startup_failure.dart';
import 'package:on_time_front/core/database/restore_delivery_cleanup.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/core/database/restore_runtime_identity.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/installation_key_store.dart';
import 'package:on_time_front/core/backup/restore_staging.dart';
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
  StartupDependencyScope? dependencies;
  RecoveryRestoreService? recovery;
  Future<RecoveryRestoreService> recoveryService() async =>
      recovery ??= RecoveryRestoreService(
        await PairFiles.device(),
        repairCutover: LocalDataLifecycle.repairCutoverAfterVerifiedRestore,
      );
  final stage = ValueNotifier(StartupStage.locale);
  Future<T> runStage<T>(StartupStage next, Future<T> Function() action) {
    stage.value = next;
    return startupStage(next, action);
  }

  runApp(
    LocalStartupGate(
      stage: stage,
      recovery: recoveryService,
      prepare: () {
        final owner = dependencies ??= StartupDependencyScope(getIt);
        return owner.track(() async {
          await HardwareKeyboard.instance.syncKeyboardState().catchError(
            (_) {},
          );
          await runStage(StartupStage.locale, initializeDateFormatting);
          // Recovery owns its own cleanup evidence. A failed reset must not fall
          // into an unrelated best-effort cleanup that discards its registry.
          await runStage(
            StartupStage.lifecycle,
            () => bootstrapWithPrivacyCleanup(
              bootstrap: () => LocalDataLifecycle.bootstrap(
                preparePairs: () async =>
                    (await recoveryService()).prepareStartup(),
              ),
              cleanup: RuntimePrivacyMigration.clearLegacyWithoutDatabase,
              shouldCleanup: (error) =>
                  error is! LocalResetRecoveryRequired &&
                  error is! PairRecoveryRequired,
            ),
          );
          // The reset/cutover boundary above must complete before opening a DB.
          await runStage(
            StartupStage.temporaryFiles,
            RestoreStaging.cleanupAbandoned,
          );
          final keys = InstallationKeyStore();
          final database = AppDatabase(keys);
          try {
            await runStage(
              StartupStage.store,
              () => RestoreRuntimeIdentity.shared.prepareStartup(
                database,
                LocalDataOperationGate.shared,
                cleanupPlatform: () =>
                    cleanupRestoreDeliveries(AlarmOperationCoordinator.shared),
              ),
            );
          } finally {
            await StartupDependencyScope.releaseChecked(
              database,
              database.close,
            );
          }
          await runStage(StartupStage.store, () async {
            final pair = await (await PairFiles.device()).selected();
            if (pair.isLegacy) {
              await (await InitialStoreGuard.device(
                keys,
              )).completeVerifiedCreation();
            } else {
              await LocalDataLifecycle.repairCutoverAfterVerifiedRestore();
            }
          });
        });
      },
      cleanupAttempt: () async {
        stage.value = StartupStage.cleanup;
        await dependencies?.cleanup();
        dependencies = null;
      },
      beginReset: LocalResetWorkflow(
        RecoveryResetAdapter(LocalDataLifecycle.beginReset),
      ).call,
      retryReset: LocalResetWorkflow(
        RecoveryResetAdapter(LocalDataLifecycle.resumeReset),
      ).call,
      ready: () {
        stage.value = StartupStage.dependencies;
        try {
          return dependencies!.configure(() {
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
          });
        } catch (error) {
          throw StartupFailure(StartupStage.dependencies, error);
        }
      },
    ),
  );
}
