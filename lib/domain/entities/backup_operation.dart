enum BackupFreshness { neverExported, noChanges, unexportedChanges }

enum BackupExportResult { cancelled, saved, savedFreshnessUpdateFailed }

class BackupFreshnessStatus {
  const BackupFreshnessStatus({
    required this.freshness,
    this.lastExportedAt,
    this.reminderDue = false,
  });

  final BackupFreshness freshness;
  final DateTime? lastExportedAt;
  final bool reminderDue;
}

class BackupRestorePreview {
  const BackupRestorePreview({
    required this.cutoff,
    required this.sourceAppVersion,
    required this.sourcePlatform,
    required this.scheduleCount,
    required this.templateCount,
    required this.defaultPreparationStepCount,
  });

  final DateTime cutoff;
  final String sourceAppVersion;
  final String sourcePlatform;
  final int scheduleCount;
  final int templateCount;
  final int defaultPreparationStepCount;
}

abstract class BackupRestoreInput {
  BackupRestorePreview get preview;
}

enum DataOperationFailure {
  busy,
  unavailable,
  invalidBackup,
  stalePreview,
  failed,
}

class DataOperationException implements Exception {
  const DataOperationException(
    this.failure, {
    this.followUpPending = false,
    this.generation,
  });
  final DataOperationFailure failure;
  final int? generation;
  final bool followUpPending;
}

class BackupRestoreReceipt {
  const BackupRestoreReceipt({
    required this.committed,
    required this.generation,
    this.followUpPending = false,
    this.failure,
  });
  final bool committed;
  final int generation;
  final bool followUpPending;
  final DataOperationFailure? failure;
}
