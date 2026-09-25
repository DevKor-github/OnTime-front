import 'package:equatable/equatable.dart';
import 'civil_time_occurrence.dart';

enum ScheduleTimeResolutionStatus {
  resolved,
  historicalUncertain,
  unknownZone,
  nonexistent,
  ambiguous,
  changed,
  invalid,
}

final class ScheduleTimeUnresolved implements Exception {
  const ScheduleTimeUnresolved(this.status);
  final ScheduleTimeResolutionStatus status;
}

/// Interpretation only; start, notification and restore permission are separate.
final class ScheduleTimeResolution extends Equatable {
  ScheduleTimeResolution({
    required this.status,
    this.instantUtc,
    this.proposedInstantUtc,
    this.isHistorical = false,
    List<CivilTimeOccurrence> occurrences = const [],
  }) : occurrences = List.unmodifiable(occurrences);

  final ScheduleTimeResolutionStatus status;
  final DateTime? instantUtc;
  final DateTime? proposedInstantUtc;
  final bool isHistorical;
  final List<CivilTimeOccurrence> occurrences;

  @override
  List<Object?> get props => [
    status,
    instantUtc,
    proposedInstantUtc,
    isHistorical,
    occurrences,
  ];
}
