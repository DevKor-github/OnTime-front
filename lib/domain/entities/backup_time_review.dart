import 'time_correction_conflict.dart';
import 'backup_restore_selection.dart';
import 'civil_date_time.dart';
import 'civil_time_occurrence.dart';

enum BackupTimeFieldKind {
  scheduleOccurrence,
  scheduleStartedAt,
  scheduleFinishedAt,
  templateCreatedAt,
  templateUpdatedAt,
  recurrenceRule,
}

enum BackupTimeIssueReason {
  unknownZone,
  nonexistentCivil,
  repeatedCivil,
  changedOffset,
  missingInstantOffset,
  recurrenceOrder,
}

/// Diagnostic state for an authenticated candidate, never a ready preview.
class BackupTimeReviewSummary {
  const BackupTimeReviewSummary({
    required this.identity,
    required this.revision,
    required this.validationNowUtc,
    required this.rulesIdentity,
    required this.issueCount,
    required this.independentStructureChecked,
  });
  final String identity;
  final int revision;
  final DateTime validationNowUtc;
  final String rulesIdentity;
  final int issueCount;

  /// This does not claim that time-dependent relations or activation checks
  /// have passed. Every edit requires a fresh complete validation pass.
  final bool independentStructureChecked;
}

class BackupTimeReviewIssue {
  const BackupTimeReviewIssue({
    required this.id,
    required this.kind,
    required this.reason,
    required this.fieldPath,
    required this.name,
    required this.originalLiteral,
    required this.currentLiteral,
    required this.civil,
    this.zone,
    this.selectedOffsetSeconds,
  });
  final String id;
  final BackupTimeFieldKind kind;
  final BackupTimeIssueReason reason;
  final String fieldPath;
  final String name;
  final String originalLiteral;
  final String currentLiteral;
  final CivilDateTime civil;
  final String? zone;
  final int? selectedOffsetSeconds;
}

class BackupTimeReviewIssuePage {
  BackupTimeReviewIssuePage(
    List<BackupTimeReviewIssue> items, {
    this.nextCursor,
  }) : items = List.unmodifiable(items);
  final List<BackupTimeReviewIssue> items;
  final String? nextCursor;
}

/// The owner binds the opaque issue ID to its own exact field path. Clients
/// cannot submit arbitrary JSON paths, IDs, graph edges, or field names.
class BackupTimeDraft {
  const BackupTimeDraft({
    required this.identity,
    required this.revision,
    required this.rulesIdentity,
    required this.issueId,
    required this.civil,
    required this.zone,
  });
  final String identity;
  final int revision;
  final String rulesIdentity;
  final String issueId;
  final CivilDateTime civil;
  final String zone;
}

class BackupTimeFieldReview {
  BackupTimeFieldReview({
    required this.draft,
    required this.issue,
    required List<CivilTimeOccurrence> choices,
    this.nextValidCivil,
    this.previousInstantUtc,
    Map<int, TimeCorrectionConflictProof> conflictsByOffset = const {},
  }) : choices = List.unmodifiable(choices),
       conflictsByOffset = Map.unmodifiable(conflictsByOffset);
  final BackupTimeDraft draft;
  final BackupTimeReviewIssue issue;
  final List<CivilTimeOccurrence> choices;
  final CivilDateTime? nextValidCivil;
  final DateTime? previousInstantUtc;
  final Map<int, TimeCorrectionConflictProof> conflictsByOffset;
}

class BackupTimeChoice {
  BackupTimeChoice({
    required this.review,
    required this.offsetSeconds,
    Set<String> acknowledgedPossibleIds = const {},
  }) : acknowledgedPossibleIds = Set.unmodifiable(acknowledgedPossibleIds);
  final BackupTimeFieldReview review;
  final int offsetSeconds;
  final Set<String> acknowledgedPossibleIds;
}

/// Same-lease authenticated time review. It owns no AppDatabase and exposes no
/// BackupRestorePreview. Revalidation may return another review state or a new
/// ready input; it cannot reuse an earlier ready input's identity.
abstract class BackupTimeReviewInput extends BackupRestoreSelection {
  BackupTimeReviewSummary get summary;
  Future<BackupTimeReviewIssuePage> issues({String? cursor});
  Future<BackupTimeFieldReview> review(BackupTimeDraft draft);
  Future<void> choose(BackupTimeChoice choice);
  Future<BackupRestoreSelection> revalidate();
}

class BackupTimeReviewStale implements Exception {
  const BackupTimeReviewStale();
}

class BackupTimeChoiceConflict implements Exception {
  const BackupTimeChoiceConflict(this.proof);
  final TimeCorrectionConflictProof proof;
}
