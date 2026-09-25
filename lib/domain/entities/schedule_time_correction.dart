import 'civil_date_time.dart';
import 'schedule_save.dart';
import 'schedule_time_resolution.dart';
import 'time_correction_conflict.dart';

/// Read-only evidence for a dedicated time review, never a write capability.
final class ScheduleTimeCorrectionReview {
  const ScheduleTimeCorrectionReview({
    required this.snapshot,
    required this.resolution,
    required this.ruleIdentity,
    required this.validationNowUtc,
    this.blockedBy,
  });

  final ScheduleEditSnapshot snapshot;
  final ScheduleTimeResolution resolution;
  final String ruleIdentity;
  final DateTime validationNowUtc;
  final ScheduleSaveFailure? blockedBy;
}

/// The only editable values in a single-occurrence time correction.
/// Names, places, preparations, history and recurrence ownership are absent.
final class ScheduleTimeCorrectionCommand {
  ScheduleTimeCorrectionCommand({
    required this.review,
    required this.civil,
    required this.timeZoneId,
    required this.offsetSeconds,
    required this.mutationId,
    Set<String> acknowledgedUncertainIds = const {},
  }) : acknowledgedUncertainIds = Set.unmodifiable(acknowledgedUncertainIds);

  final ScheduleTimeCorrectionReview review;
  final CivilDateTime civil;
  final String timeZoneId;
  final int offsetSeconds;
  final String mutationId;
  final Set<String> acknowledgedUncertainIds;
}

final class ScheduleTimeCorrectionConflict implements Exception {
  const ScheduleTimeCorrectionConflict(this.proof);
  final TimeCorrectionConflictProof proof;
}
