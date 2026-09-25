import 'backup_restore_selection.dart';

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
    this.cutoffLiteral,
    required this.sourceAppVersion,
    required this.sourcePlatform,
    required this.scheduleCount,
    required this.templateCount,
    required this.defaultPreparationStepCount,
    this.timezoneChangeCount = 0,
    this.uncertainHistoryCount = 0,
    this.uncertainHistoryExamples = const [],
  });

  final DateTime cutoff;
  final String? cutoffLiteral;
  final String sourceAppVersion;
  final String sourcePlatform;
  final int scheduleCount;
  final int templateCount;
  final int defaultPreparationStepCount;
  final int timezoneChangeCount;
  final int uncertainHistoryCount;
  final List<BackupHistoryUncertainty> uncertainHistoryExamples;
}

enum BackupHistoryUncertaintyReason {
  historicalProvenance,
  unavailableHistoricalZone,
  protectedStartZone,
  historicalOrdinal,
}

class BackupHistoryUncertainty {
  const BackupHistoryUncertainty({
    this.name,
    required this.civil,
    required this.zone,
    this.reason = BackupHistoryUncertaintyReason.historicalProvenance,
  });
  final String? name;
  final DateTime civil;
  final String zone;
  final BackupHistoryUncertaintyReason reason;
}

abstract class BackupRestoreInput extends BackupRestoreSelection {
  BackupRestorePreview get preview;
  @override
  Future<void> dispose() async {}
  Future<BackupTimeZoneImpactPage> timeZoneImpacts({String? cursor}) async =>
      const BackupTimeZoneImpactPage([]);
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

enum BackupCommitDisposition { notCommitted, committed, undetermined }

/// The replacement call failed and its durable outcome could not be read back.
/// Only a fresh startup authority may resolve this outcome; do not import again.
class BackupRestoreCommitUncertain implements Exception {
  const BackupRestoreCommitUncertain({required this.generation});
  final int generation;
}

enum RecoveryFollowUp { awaitingNewProcess, verifyingPair, cleanupPending }

class BackupRestoreReceipt {
  factory BackupRestoreReceipt({
    required BackupCommitDisposition disposition,
    required int generation,
    bool followUpPending = false,
    DataOperationFailure? failure,
  }) {
    if (disposition == BackupCommitDisposition.undetermined) {
      throw ArgumentError(
        'Use the uncertain receipt for unknown commit authority',
      );
    }
    return BackupRestoreReceipt._(
      disposition,
      generation,
      followUpPending,
      failure,
    );
  }
  const BackupRestoreReceipt._(
    this.disposition,
    this.generation,
    this.followUpPending,
    this.failure,
  ) : recoveryFollowUp = null;

  const BackupRestoreReceipt.uncertain({required this.generation})
    : disposition = BackupCommitDisposition.undetermined,
      followUpPending = true,
      failure = null,
      recoveryFollowUp = null;

  const BackupRestoreReceipt.recovery({
    required this.generation,
    required RecoveryFollowUp phase,
  }) : disposition = BackupCommitDisposition.committed,
       followUpPending = true,
       failure = null,
       recoveryFollowUp = phase;

  final BackupCommitDisposition disposition;
  final RecoveryFollowUp? recoveryFollowUp;
  // A nullable compatibility observation cannot accidentally make unknown false.
  bool? get committed => switch (disposition) {
    BackupCommitDisposition.committed => true,
    BackupCommitDisposition.notCommitted => false,
    BackupCommitDisposition.undetermined => null,
  };
  final int generation;
  final bool followUpPending;
  final DataOperationFailure? failure;
}

/// The encrypted candidate could not be released. This is not a DB commit or
/// notification-delivery receipt. Causes are retained for controlled diagnostics.
final class RestoreStagingCleanupFailure implements Exception {
  const RestoreStagingCleanupFailure({
    this.originalError,
    required this.cleanupError,
    this.retryCleanup,
  });
  final Object? originalError;
  final Object cleanupError;
  final Future<void> Function()? retryCleanup;
}

/// The preserved source became usable while a damaged-store preview was open.
/// The user must confirm a new preview through the normal A09 restore workflow.
final class RecoveryOriginalAvailable implements Exception {
  const RecoveryOriginalAvailable();
}

class BackupTimeZoneImpact {
  const BackupTimeZoneImpact({
    required this.name,
    required this.civil,
    required this.zone,
    required this.previousOffset,
    required this.newOffset,
  });
  final String name;
  final DateTime civil;
  final String zone;
  final int? previousOffset;
  final int newOffset;
}

class BackupTimeZoneImpactPage {
  const BackupTimeZoneImpactPage(this.items, {this.nextCursor});
  final List<BackupTimeZoneImpact> items;
  final String? nextCursor;
}
