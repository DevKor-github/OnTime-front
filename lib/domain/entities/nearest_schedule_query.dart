import 'package:equatable/equatable.dart';
import 'schedule_time_resolution.dart';
import 'schedule_with_preparation_entity.dart';

final class NearestQueryKey extends Equatable {
  const NearestQueryKey({
    required this.generation,
    required this.epoch,
    required this.revision,
  });
  final int generation;
  final int epoch;
  final int revision;
  @override
  List<Object?> get props => [generation, epoch, revision];
}

final class NearestQueryAuthority extends Equatable {
  const NearestQueryAuthority({
    required this.key,
    required this.storeIncarnation,
    required this.dataRevision,
    required this.ruleDataIdentity,
    required this.evaluatedAtUtc,
    required this.verifiedAtUtc,
  });
  final NearestQueryKey key;
  final String storeIncarnation;
  final int dataRevision;
  final String ruleDataIdentity;
  final DateTime evaluatedAtUtc;
  final DateTime verifiedAtUtc;
  @override
  List<Object?> get props => [
    key,
    storeIncarnation,
    dataRevision,
    ruleDataIdentity,
    evaluatedAtUtc,
    verifiedAtUtc,
  ];
}

final class NearestVerifiedSchedule extends Equatable {
  const NearestVerifiedSchedule({
    required this.schedule,
    required this.resolution,
    required this.authority,
  });
  final ScheduleWithPreparationEntity schedule;
  final ScheduleTimeResolution resolution;
  final NearestQueryAuthority authority;
  @override
  List<Object?> get props => [schedule, resolution, authority];
}

final class NearestQueryProgress extends Equatable {
  const NearestQueryProgress({
    required this.visitedCandidates,
    required this.candidateBudget,
    required this.provenSegments,
    required this.totalSegments,
  });
  final int visitedCandidates;
  final int candidateBudget;
  final int provenSegments;
  final int totalSegments;
  @override
  List<Object?> get props => [
    visitedCandidates,
    candidateBudget,
    provenSegments,
    totalSegments,
  ];
}

enum NearestQueryFailureReason {
  storeReadFailed,
  preparationReadFailed,
  preparationMissing,
  recurrenceMetadataInvalid,
  currentStoreUnavailable,
}

enum NearestQueryLimitReason {
  interrupted,
  cancelled,
  searchBudgetExhausted,
  representableRangeExhausted,
}

enum NearestQueryIssueReason {
  unknownTimeZone,
  ambiguousOccurrence,
  nonexistentCivilTime,
  changedTimeRules,
  uncertainHistoricalTime,
  invalidTimeMetadata,
}

final class NearestQueryIssue extends Equatable {
  const NearestQueryIssue({
    required this.reason,
    this.scheduleId,
    this.segmentId,
  }) : assert(scheduleId != null || segmentId != null);
  final NearestQueryIssueReason reason;
  final String? scheduleId;
  final String? segmentId;
  @override
  List<Object?> get props => [reason, scheduleId, segmentId];
}

sealed class NearestScheduleQuery extends Equatable {
  const NearestScheduleQuery({
    required this.key,
    this.stale,
    this.issues = const [],
  });
  final NearestQueryKey? key;
  final NearestVerifiedSchedule? stale;
  final List<NearestQueryIssue> issues;
  @override
  List<Object?> get props => [key, stale, issues];
}

final class NearestQueryIdle extends NearestScheduleQuery {
  const NearestQueryIdle() : super(key: null);
}

final class NearestQueryLoading extends NearestScheduleQuery {
  const NearestQueryLoading({
    required NearestQueryKey key,
    required this.progress,
    super.stale,
    super.issues,
  }) : super(key: key);
  final NearestQueryProgress progress;
  @override
  List<Object?> get props => [...super.props, progress];
}

final class NearestQueryReady extends NearestScheduleQuery {
  NearestQueryReady({
    required this.value,
    List<NearestQueryIssue> issues = const [],
  }) : super(key: value.authority.key, issues: List.unmodifiable(issues));
  final NearestVerifiedSchedule value;
  @override
  List<Object?> get props => [...super.props, value];
}

final class NearestQueryEmpty extends NearestScheduleQuery {
  NearestQueryEmpty({
    required this.authority,
    List<NearestQueryIssue> issues = const [],
  }) : super(key: authority.key, issues: List.unmodifiable(issues));
  final NearestQueryAuthority authority;
  @override
  List<Object?> get props => [...super.props, authority];
}

final class NearestQueryError extends NearestScheduleQuery {
  const NearestQueryError({
    required NearestQueryKey key,
    required this.reason,
    super.stale,
    super.issues,
  }) : super(key: key);
  final NearestQueryFailureReason reason;
  @override
  List<Object?> get props => [...super.props, reason];
}

final class NearestQueryLimited extends NearestScheduleQuery {
  const NearestQueryLimited({
    required NearestQueryKey key,
    required this.reason,
    required this.progress,
    required this.canContinue,
    required this.canRetry,
    super.stale,
    super.issues,
  }) : super(key: key);
  final NearestQueryLimitReason reason;
  final NearestQueryProgress progress;
  final bool canContinue;
  final bool canRetry;
  @override
  List<Object?> get props => [
    ...super.props,
    reason,
    progress,
    canContinue,
    canRetry,
  ];
}
