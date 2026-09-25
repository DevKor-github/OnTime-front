/// An installation-owned selected backup resource, without activation authority.
/// Only a separately verified BackupRestoreInput may be passed to apply.
abstract class BackupRestoreSelection {
  Future<void> dispose() async {}
}
