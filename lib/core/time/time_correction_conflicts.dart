import 'package:on_time_front/domain/entities/time_correction_conflict.dart';
export 'package:on_time_front/domain/entities/time_correction_conflict.dart';
import 'package:on_time_front/core/backup/backup_limits.dart';
import 'package:on_time_front/core/backup/backup_recurrence_scan.dart';
import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/recurrence/recurrence_engine.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
import 'schedule_time_resolution.dart';
import 'time_zone_rules.dart';

/// Detached records, materialized overrides and original protected facts are
/// supplied as stored intervals. Other rules are expanded only for the proof
/// range; none of this operation materializes or writes an occurrence.
abstract final class TimeCorrectionConflictScanner {
  static int _period(RecurrenceRule rule) => switch (rule.frequency) {
    RecurrenceFrequency.daily => rule.interval,
    RecurrenceFrequency.weekly => 7 * rule.interval,
    RecurrenceFrequency.monthly =>
      146097 * (rule.interval ~/ rule.interval.gcd(4800)),
  };

  static DateTime _proofEnd(
    RecurrenceRule rule,
    List<RecurringSegment> segments,
    Iterable<DateTime> exceptions,
    BackupBudget budget,
  ) {
    if (rule.until != null) {
      final end = rule.until!;
      return DateTime.utc(end.year, end.month, end.day, 23, 59, 59, 999, 999);
    }
    if (rule.count != null) {
      return DateTime.utc(9999, 12, 31, 23, 59, 59, 999, 999);
    }
    var days = 1;
    var anchor = rule.start;
    for (final value in [rule, ...segments.map((e) => e.rule)]) {
      budget.visit();
      final period = _period(value);
      days = days ~/ days.gcd(period) * period;
      if (days > 146097 * 10) BackupLimits.exceeded('recurrenceProofPeriod');
      if (value.start.isAfter(anchor)) anchor = value.start;
      final transitions = TimeZoneRules.location(value.timeZoneId).transitionAt;
      if (transitions.isNotEmpty) {
        final last = DateTime.fromMillisecondsSinceEpoch(
          transitions.last,
          isUtc: true,
        ).add(const Duration(days: 2));
        if (last.isAfter(anchor)) anchor = last;
      }
    }
    for (final value in exceptions) {
      budget.visit();
      final after = value.add(const Duration(days: 2));
      if (after.isAfter(anchor)) anchor = after;
    }
    final end = anchor.add(Duration(days: days + 7));
    if (end.year > 9999) BackupLimits.exceeded('recurrenceProofRange');
    return end;
  }

  static String canonicalSlot(String value) =>
      CivilDateTime.parse(value).toUtcCarrier().toIso8601String();

  static Stream<RecurrenceSlot> _slots(
    RecurrenceRule rule,
    DateTime through,
    BackupBudget budget, {
    Duration lead = Duration.zero,
    DateTime? cutoff,
    bool requireFullCount = true,
    bool strictSelection = true,
    void Function(DateTime civil, List<int> offsets)? onUnselected,
  }) async* {
    var ordinal = 0;
    await for (final candidate in scanBackupRule(
      rule: rule,
      through: through,
      budget: budget,
      leadTime: lead,
      preparationNotBefore: cutoff,
    )) {
      if (candidate.offsets.length > 1 && rule.repeatedTime == null) {
        if (strictSelection) throw RepeatedTimeChoiceRequired(candidate.civil);
        onUnselected?.call(candidate.civil, candidate.offsets);
        continue;
      }
      if (candidate.eligible) {
        ordinal = candidate.currentOrdinal;
        final offset = rule.repeatedTime == RepeatedCivilTime.second
            ? candidate.offsets.last
            : candidate.offsets.first;
        yield RecurrenceSlot(
          civilTime: candidate.civil,
          instantUtc: CivilDateTime.fromFields(
            candidate.civil,
          ).atOffset(offset),
          offsetSeconds: offset,
          ordinal: ordinal,
        );
      }
      if (rule.count != null && candidate.currentOrdinal >= rule.count!) break;
    }
    if (requireFullCount &&
        rule.count != null &&
        ordinal < rule.count! &&
        through.year == 9999) {
      throw const RecurrenceValidationException(
        'The complete occurrence count could not be verified.',
      );
    }
  }

  static bool _overlaps(
    TimeCorrectionBusyInterval a,
    TimeCorrectionBusyInterval b,
  ) =>
      a.instantUtc == b.instantUtc ||
      (a.preparationStartUtc.isBefore(b.instantUtc) &&
          b.preparationStartUtc.isBefore(a.instantUtc));

  static Future<TimeCorrectionConflictProof> scan({
    required RecurrenceRule rule,
    required ScheduleEntity base,
    required Duration basePreparation,
    required Map<String, ScheduleEntity> proposedOverrides,
    required Map<String, Duration> proposedPreparationById,
    required Set<String> excludedSlots,
    required List<TimeCorrectionBusyInterval> storedOthers,
    required List<RecurringSegment> otherSegments,
    required Map<String, Set<String>> otherExcludedSlots,
    required DateTime nowUtc,
    required BackupBudget budget,
  }) async {
    final excluded = excludedSlots.map(canonicalSlot).toSet();
    final through = _proofEnd(rule, otherSegments, [
      for (final row in storedOthers) row.schedule.scheduleTime,
      for (final row in proposedOverrides.values) row.scheduleTime,
      for (final keys in otherExcludedSlots.values)
        for (final key in keys) CivilDateTime.parse(key).toUtcCarrier(),
    ], budget);
    final proposed = <(RecurrenceSlot, TimeCorrectionBusyInterval)>[];
    final mapped = {
      for (final entry in proposedOverrides.entries)
        canonicalSlot(entry.key): entry.value,
    };
    await for (final slot in _slots(rule, through, budget)) {
      if (excluded.contains(slot.key)) continue;
      final override = mapped[slot.key];
      final value =
          override ??
          base.copyWith(
            id: slot.key,
            scheduleTime: slot.civilTime,
            timeZoneId: rule.timeZoneId,
            occurrenceOffsetSeconds: slot.offsetSeconds,
          );
      final instant = ScheduleTimeResolver.resolve(
        value,
        nowUtc: nowUtc,
      ).instantUtc;
      if (instant == null) {
        throw const RecurrenceValidationException(
          'An occurrence needs explicit time review.',
        );
      }
      final preparation = proposedPreparationById[value.id] ?? basePreparation;
      final lead =
          preparation +
          value.moveTime +
          (value.scheduleSpareTime ?? Duration.zero);
      proposed.add((
        slot,
        TimeCorrectionBusyInterval(value, instant.subtract(lead), instant),
      ));
      budget.visit();
      if (proposed.length > BackupLimits.schedules) {
        BackupLimits.exceeded('schedules');
      }
    }
    if (proposed.isEmpty) {
      throw const RecurrenceValidationException(
        'No unexcluded occurrence remains.',
      );
    }
    final others = <TimeCorrectionBusyInterval>[...storedOthers];
    final uncertain = <TimeCorrectionPossibleOverlap>[];
    // Materialized rows (including overrides) own their segment+slot even when
    // their ID was preserved across a split and differs from a generated ID.
    final occupied = {
      for (final row in storedOthers)
        if (row.schedule.recurringSegmentId != null &&
            row.schedule.recurringSlotKey != null)
          '${row.schedule.recurringSegmentId}\n${canonicalSlot(row.schedule.recurringSlotKey!)}',
    };
    final first = proposed
        .map((e) => e.$2.preparationStartUtc)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final last = proposed
        .map((e) => e.$2.instantUtc)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    for (final segment in otherSegments) {
      final keys = (otherExcludedSlots[segment.id] ?? {})
          .map(canonicalSlot)
          .toSet();
      var upper = last.add(segment.leadTime + const Duration(days: 2));
      final max = DateTime.utc(9999, 12, 31, 23, 59, 59, 999, 999);
      if (upper.isAfter(max)) upper = max;
      await for (final slot in _slots(
        segment.rule,
        upper,
        budget,
        lead: segment.leadTime,
        cutoff: segment.preparationNotBefore,
        requireFullCount: false,
        strictSelection: false,
        onUnselected: (civil, offsets) {
          final key = canonicalSlot(civil.toIso8601String());
          if (keys.contains(key) || occupied.contains('${segment.id}\n$key')) {
            return;
          }
          if (civil.isBefore(segment.fromSlot) ||
              (segment.beforeSlot != null &&
                  !civil.isBefore(segment.beforeSlot!))) {
            return;
          }
          final early = CivilDateTime.fromFields(
            civil,
          ).atOffset(offsets.first).subtract(segment.leadTime);
          final late = CivilDateTime.fromFields(civil).atOffset(offsets.last);
          if (late.isBefore(first) || early.isAfter(last)) return;
          budget.visit();
          if (uncertain.length >= BackupLimits.schedules) {
            BackupLimits.exceeded('schedules');
          }
          uncertain.add(
            TimeCorrectionPossibleOverlap(
              id: '${segment.id}\n${civil.toIso8601String()}',
              name: segment.schedule.scheduleName,
              reason: 'ambiguous',
              originalCivil: civil,
              timeZoneId: segment.rule.timeZoneId,
              rule: segment.rule,
              earliestPreparationUtc: early,
              latestTargetUtc: late,
            ),
          );
        },
      )) {
        if (!segment.includes(slot) ||
            keys.contains(slot.key) ||
            occupied.contains('${segment.id}\n${slot.key}')) {
          continue;
        }
        final start = slot.instantUtc.subtract(segment.leadTime);
        if (slot.instantUtc.isBefore(first) || start.isAfter(last)) continue;
        final value = segment.schedule.copyWith(
          id: '${segment.id}\n${slot.key}',
          scheduleTime: slot.civilTime,
          timeZoneId: segment.rule.timeZoneId,
          occurrenceOffsetSeconds: slot.offsetSeconds,
          recurringSegmentId: segment.id,
          recurringSlotKey: slot.key,
          recurringOrdinal: slot.ordinal,
        );
        others.add(TimeCorrectionBusyInterval(value, start, slot.instantUtc));
        if (others.length > BackupLimits.schedules) {
          BackupLimits.exceeded('schedules');
        }
      }
    }
    proposed.sort(
      (a, b) => a.$2.preparationStartUtc.compareTo(b.$2.preparationStartUtc),
    );
    others.sort(
      (a, b) => a.preparationStartUtc.compareTo(b.preparationStartUtc),
    );
    final conflicts = <TimeCorrectionConflict>[];
    var otherStartIndex = 0;
    final unboundedOthers = {
      for (final segment in otherSegments)
        if (segment.rule.count == null &&
            segment.rule.until == null &&
            segment.beforeSlot == null)
          segment.id,
    };
    final unbounded = rule.count == null && rule.until == null;
    for (var i = 0; i < proposed.length; i++) {
      final item = proposed[i];
      for (
        var j = i + 1;
        j < proposed.length &&
            !proposed[j].$2.preparationStartUtc.isAfter(item.$2.instantUtc);
        j++
      ) {
        budget.visit();
        final other = proposed[j];
        if (_overlaps(item.$2, other.$2)) {
          conflicts.add(
            TimeCorrectionConflict(
              slot: other.$1,
              other: item.$2,
              otherSlotKey: item.$1.key,
              persistent:
                  unbounded &&
                  !mapped.containsKey(item.$1.key) &&
                  !mapped.containsKey(other.$1.key),
            ),
          );
        }
      }
      while (otherStartIndex < others.length &&
          !others[otherStartIndex].instantUtc.isAfter(
            item.$2.preparationStartUtc,
          ) &&
          others[otherStartIndex].instantUtc != item.$2.instantUtc) {
        budget.visit();
        otherStartIndex++;
      }
      for (var j = otherStartIndex; j < others.length; j++) {
        final other = others[j];
        budget.visit();
        if (other.preparationStartUtc.isAfter(item.$2.instantUtc)) break;
        if (!_overlaps(item.$2, other)) continue;
        conflicts.add(
          TimeCorrectionConflict(
            slot: item.$1,
            other: other,
            persistent:
                unbounded &&
                !mapped.containsKey(item.$1.key) &&
                unboundedOthers.contains(other.schedule.recurringSegmentId) &&
                other.schedule.recurringOverrides.isEmpty,
          ),
        );
      }
      if (conflicts.length > BackupLimits.records) {
        BackupLimits.exceeded('records');
      }
    }
    return TimeCorrectionConflictProof(
      conflicts: conflicts,
      through: through,
      workUnits: budget.work,
      earliestPreparationUtc: first,
      latestTargetUtc: last,
      possibleOverlaps: uncertain,
      proposedSlots: proposed.map((e) => e.$1).toList(),
    );
  }
}
