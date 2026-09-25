import '../entities/civil_date_time.dart';
import '../entities/schedule_entity.dart';
import 'recurrence_rule.dart';

/// A closed generation interval can still own history and deletion tombstones.
/// Retaining such a reference never grants another start or delivery authority.
abstract final class RecurrenceReferencePolicy {
  /// A proof from stored civil bounds, independent of a zone registry.
  /// Count alone is deliberately insufficient: missing historical rules may
  /// change which calendar candidates consumed that count.
  static bool hasNoFutureGeneration({
    required RecurrenceRule rule,
    required DateTime fromSlot,
    required DateTime? beforeSlot,
    required DateTime nowUtc,
  }) {
    final from = RecurrenceRule.civilTime(fromSlot);
    DateTime? exclusiveEnd = beforeSlot == null
        ? null
        : RecurrenceRule.civilTime(beforeSlot);
    if (exclusiveEnd != null && !exclusiveEnd.isAfter(from)) return true;
    final until = rule.until;
    if (until != null) {
      final end = DateTime.utc(until.year, until.month, until.day + 1);
      if (exclusiveEnd == null || end.isBefore(exclusiveEnd)) {
        exclusiveEnd = end;
      }
    }
    if (exclusiveEnd == null) return false;
    // Every supported offset is in [-24h,+24h]. Even the latest possible
    // instant before this exclusive civil boundary must already be past.
    return !exclusiveEnd.add(const Duration(hours: 24)).isAfter(nowUtc.toUtc());
  }

  static bool isClosedTail(String slot, String? beforeSlot) =>
      beforeSlot != null &&
      CivilDateTime.parse(slot).compareTo(CivilDateTime.parse(beforeSlot)) >= 0;

  static bool hasProtectedFacts(ScheduleEntity value) =>
      value.isStarted ||
      value.preparationFrozen ||
      value.doneStatus != ScheduleDoneStatus.notEnded;

  static bool isProvablyPast(ScheduleEntity value, DateTime nowUtc) {
    final civil = CivilDateTime.fromFields(value.scheduleTime);
    final offset = value.occurrenceOffsetSeconds;
    // Missing offset must not acquire the device zone or an invented instant.
    final latest = offset == null
        ? civil.toUtcCarrier().add(const Duration(hours: 24))
        : civil.atOffset(offset);
    return latest.isBefore(nowUtc.toUtc());
  }
}
