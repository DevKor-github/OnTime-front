import 'package:on_time_front/domain/entities/backup_operation.dart';

/// Pre-DI recovery needs neither active DB revision nor export/freshness.
abstract interface class RecoveryRestorePort {
  Future<BackupRestoreInput?> preview(String password);
  Future<BackupRestoreReceipt> activate(BackupRestoreInput input);
  Future<BackupRestoreReceipt> resume();
  Future<BackupRestoreReceipt> abort();
}
