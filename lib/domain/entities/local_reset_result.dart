enum ResetStep { deliveries, database, preferences, key, credentials, launch }

/// A typed receipt says which facts were verified, never exposes raw errors.
final class LocalResetResult {
  const LocalResetResult({
    required this.intentRecorded,
    required this.completed,
    this.isComplete = false,
    this.waitingForPlatform = false,
    this.recoveryRequired = true,
  });
  final bool intentRecorded;
  final Set<ResetStep> completed;
  final bool isComplete;
  final bool waitingForPlatform;
  final bool recoveryRequired;
  bool get dataDeleted => completed.containsAll({
    ResetStep.database,
    ResetStep.preferences,
    ResetStep.key,
    ResetStep.credentials,
  });
}
