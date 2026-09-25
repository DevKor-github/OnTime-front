import 'backup_time_review.dart';
import 'schedule_entity.dart';
import 'schedule_time_resolution.dart';
import 'time_correction_conflict.dart';
import '../recurrence/recurrence_rule.dart';
import '../recurrence/recurring_time_correction.dart';

/// A candidate-owned plan anchor. A segment with no materialized rows has no
/// invented schedule ID or ordinal, and this value is never persisted as a row.
class BackupRecurringTimeAnchor {
  const BackupRecurringTimeAnchor({
    required this.segmentId,
    required this.originalSlot,
    this.scheduleId,
    this.originalOrdinal,
  });
  final String segmentId;
  final DateTime originalSlot;
  final String? scheduleId;
  final int? originalOrdinal;
}

class BackupRecurringTimeDraft {
  BackupRecurringTimeDraft({
    required this.identity,
    required this.revision,
    required this.rulesIdentity,
    required this.issueId,
    required this.rule,
    required this.endExplicitlyChosen,
    this.replaceWholeSourceInterval = false,
    Set<String> excludedConflictSlots = const {},
  }) : excludedConflictSlots = Set.unmodifiable(excludedConflictSlots);
  final String identity;
  final int revision;
  final String rulesIdentity;
  final String issueId;
  final RecurrenceRule rule;
  final bool endExplicitlyChosen;
  final bool replaceWholeSourceInterval;
  final Set<String> excludedConflictSlots;
}

class BackupRecurringTimePlan {
  BackupRecurringTimePlan({
    required this.draft,
    required this.issue,
    required this.anchor,
    required this.originalRule,
    required this.originalSchedule,
    required this.originalFrom,
    required this.originalBefore,
    required this.closeAt,
    required this.mapping,
    required this.conflicts,
    required Map<String, ScheduleTimeResolutionStatus> unresolvedOverrides,
  }) : unresolvedOverrides = Map.unmodifiable(unresolvedOverrides);
  final BackupRecurringTimeDraft draft;
  final BackupTimeReviewIssue issue;
  final BackupRecurringTimeAnchor anchor;
  final RecurrenceRule originalRule;
  final ScheduleEntity originalSchedule;
  final DateTime originalFrom;
  final DateTime? originalBefore;
  final DateTime closeAt;
  final RecurringTimeCorrectionMapping mapping;
  final TimeCorrectionConflictProof conflicts;
  final Map<String, ScheduleTimeResolutionStatus> unresolvedOverrides;

  bool get replacesWholeSourceInterval => draft.replaceWholeSourceInterval;
}

class BackupRecurringTimeChoice {
  BackupRecurringTimeChoice({
    required this.plan,
    required Set<String> confirmedDetachedIds,
    required Set<String> confirmedUnmatchedExclusions,
    Set<String> acknowledgedPossibleIds = const {},
    this.confirmedWholeSourceReplacement = false,
  }) : confirmedDetachedIds = Set.unmodifiable(confirmedDetachedIds),
       confirmedUnmatchedExclusions = Set.unmodifiable(
         confirmedUnmatchedExclusions,
       ),
       acknowledgedPossibleIds = Set.unmodifiable(acknowledgedPossibleIds);
  final BackupRecurringTimePlan plan;
  final Set<String> confirmedDetachedIds;
  final Set<String> confirmedUnmatchedExclusions;
  final Set<String> acknowledgedPossibleIds;
  final bool confirmedWholeSourceReplacement;
}

/// Only an authenticated candidate owner can implement these operations. A
/// successful choice changes its candidate revision, never the active store.
abstract interface class BackupRecurringTimeReviewPort {
  Future<RecurrenceRule> recurrenceRule(String issueId);
  Future<BackupRecurringTimePlan> reviewRecurrence(
    BackupRecurringTimeDraft draft,
  );
  Future<void> chooseRecurrence(BackupRecurringTimeChoice choice);
}

/// Closing at the materialized anchor would leave an unresolved future prefix.
/// The user must review and explicitly acknowledge replacing this one source
/// segment from its original generation boundary.
class BackupRecurringWholeReplacementRequired implements Exception {
  const BackupRecurringWholeReplacementRequired();
}
