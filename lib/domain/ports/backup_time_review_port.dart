import '../entities/backup_restore_selection.dart';

/// Optional authenticated selection capability shared by normal restore and
/// pre-DI recovery. A selected review has no activation authority.
abstract interface class BackupTimeReviewPort {
  Future<BackupRestoreSelection?> selectForRestore(String password);
}
