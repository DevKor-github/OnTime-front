/// A failed pre-confirmation cleanup has no restore activation authority.
abstract interface class RecoveryPreclaimCleanupPort {
  Future<void> retryPreclaimCleanup(int generation);
}
