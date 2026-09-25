/// Shared ownership of temporary encrypted backup files across normal restore,
/// pre-DI recovery and export. Cleanup must never delete another live attempt.
abstract final class BackupPrivateFiles {
  static final livePaths = <String>{};
}
