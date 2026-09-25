import '../../domain/entities/schedule_time_resolution.dart';
export '../../domain/entities/schedule_time_resolution.dart';
import '../../domain/entities/civil_date_time.dart';
import '../../domain/entities/schedule_entity.dart';
import '../../domain/recurrence/recurrence_reference_policy.dart';
import 'civil_time_resolver.dart';
import 'time_zone_rules.dart';

abstract final class ScheduleTimeResolver {
  static ScheduleTimeResolution resolve(
    ScheduleEntity schedule, {
    required DateTime nowUtc,
    List<CivilTimeOccurrence> Function(DateTime civilCarrier, String zone)?
    lookup,
  }) {
    try {
      final civil = CivilDateTime.fromFields(schedule.scheduleTime);
      final offset = schedule.occurrenceOffsetSeconds;
      final stored = offset == null ? null : civil.atOffset(offset);
      final now = nowUtc.toUtc();
      final history =
          RecurrenceReferencePolicy.hasProtectedFacts(schedule) ||
          (stored?.isBefore(now) ??
              civil
                  .toUtcCarrier()
                  .add(const Duration(hours: 24))
                  .isBefore(now));
      if (!TimeZoneRules.contains(schedule.timeZoneId)) {
        return ScheduleTimeResolution(
          status: ScheduleTimeResolutionStatus.unknownZone,
          isHistorical: history,
        );
      }
      if (history) {
        return ScheduleTimeResolution(
          status: stored == null
              ? ScheduleTimeResolutionStatus.historicalUncertain
              : ScheduleTimeResolutionStatus.resolved,
          instantUtc: stored,
          isHistorical: true,
        );
      }
      final occurrences = List<CivilTimeOccurrence>.of(
        (lookup ?? CivilTimeResolver.resolve)(
          civil.toUtcCarrier(),
          schedule.timeZoneId,
        ),
      )..sort((a, b) => a.instantUtc.compareTo(b.instantUtc));
      final offsets = <int>{};
      for (final candidate in occurrences) {
        if (!candidate.instantUtc.isUtc ||
            !civil
                .atOffset(candidate.offsetSeconds)
                .isAtSameMomentAs(candidate.instantUtc) ||
            !offsets.add(candidate.offsetSeconds)) {
          throw const FormatException('Invalid occurrence candidate');
        }
      }
      if (offset == null &&
          occurrences.isNotEmpty &&
          occurrences.every((value) => value.instantUtc.isBefore(now))) {
        return ScheduleTimeResolution(
          status: ScheduleTimeResolutionStatus.historicalUncertain,
          occurrences: occurrences,
          isHistorical: true,
        );
      }
      if (occurrences.isEmpty) {
        return ScheduleTimeResolution(
          status: ScheduleTimeResolutionStatus.nonexistent,
        );
      }
      if (stored != null) {
        final matches = occurrences.where(
          (candidate) => candidate.offsetSeconds == offset,
        );
        return ScheduleTimeResolution(
          status: matches.isEmpty
              ? ScheduleTimeResolutionStatus.changed
              : ScheduleTimeResolutionStatus.resolved,
          instantUtc: matches.isEmpty ? null : stored,
          proposedInstantUtc: matches.isEmpty && occurrences.length == 1
              ? occurrences.single.instantUtc
              : null,
          occurrences: occurrences,
        );
      }
      return ScheduleTimeResolution(
        status: occurrences.length == 1
            ? ScheduleTimeResolutionStatus.resolved
            : ScheduleTimeResolutionStatus.ambiguous,
        instantUtc: occurrences.length == 1
            ? occurrences.single.instantUtc
            : null,
        occurrences: occurrences,
      );
    } on Exception {
      return ScheduleTimeResolution(
        status: ScheduleTimeResolutionStatus.invalid,
      );
    }
  }
}
