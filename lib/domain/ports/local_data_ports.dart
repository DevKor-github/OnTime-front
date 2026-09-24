import 'package:on_time_front/domain/entities/backup_operation.dart';
import 'package:on_time_front/domain/entities/local_reset_result.dart';

abstract interface class BackupOperationsPort {
  int get generation;
  Future<BackupFreshnessStatus> freshness();
  Future<BackupExportResult> export(String password);
  Future<BackupRestoreInput?> preview(String password);
  Future<int> apply(BackupRestoreInput input);
}

abstract interface class RestoreDeliveryPort {
  Future<bool> reconcile();
}

abstract interface class LocalResetPort {
  Future<LocalResetResult> reset();
}
