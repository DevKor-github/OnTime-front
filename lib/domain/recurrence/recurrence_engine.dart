import 'package:on_time_front/core/time/civil_time_resolver.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'package:timezone/timezone.dart' as tz;

class RecurrenceSlot {
  const RecurrenceSlot({
    required this.civilTime,
    required this.instantUtc,
    required this.offsetSeconds,
    required this.ordinal,
  });

  final DateTime civilTime;
  final DateTime instantUtc;
  final int offsetSeconds;

  /// One-based count of valid slots, including later deleted/excluded slots.
  final int ordinal;
  String get key => civilTime.toIso8601String();
}

enum RecurrenceSkipReason {
  nonexistentDate,
  nonexistentTime,
  preparationPassed,
}

class RecurrenceSkip {
  const RecurrenceSkip(this.date, this.reason);

  /// For a missing date, the first day of the affected month.
  final DateTime date;
  final RecurrenceSkipReason reason;
}

class RecurrenceExpansion {
  const RecurrenceExpansion({required this.slots, required this.skipped});
  final List<RecurrenceSlot> slots;
  final List<RecurrenceSkip> skipped;
}

class RepeatedTimeChoiceRequired implements Exception {
  const RepeatedTimeChoiceRequired(this.civilTime);
  final DateTime civilTime;
}

class RecurrenceSearchLimit implements Exception {
  const RecurrenceSearchLimit();
}

/// Pure calendar expansion. Exclusions consume their original count and never
/// cause replacement slots. No durable state, timers, or network are involved.
class RecurrenceEngine {
  const RecurrenceEngine();

  RecurrenceExpansion expand(
    RecurrenceRule rule, {
    required DateTime through,
    DateTime? from,
    DateTime? preparationNotBeforeUtc,
    Duration leadTime = Duration.zero,
    Set<String> excludedKeys = const {},
    int? limit,
    int candidateBudget = 200000,
  }) {
    if (candidateBudget < 1 || (limit != null && limit < 1)) {
      throw ArgumentError('Expansion budgets must be positive.');
    }
    final slots = <RecurrenceSlot>[];
    final skipped = <RecurrenceSkip>[];
    var visited = 0;
    for (final step in scan(
      rule,
      through: through,
      from: from,
      preparationNotBeforeUtc: preparationNotBeforeUtc,
      leadTime: leadTime,
      excludedKeys: excludedKeys,
    )) {
      if (++visited > candidateBudget) throw const RecurrenceSearchLimit();
      if (step.skipped != null) skipped.add(step.skipped!);
      if (step.slot != null) slots.add(step.slot!);
      if (limit != null && slots.length == limit) break;
    }
    return RecurrenceExpansion(
      slots: List.unmodifiable(slots),
      skipped: List.unmodifiable(skipped),
    );
  }

  /// One yield per visited candidate, including skipped/excluded/history slots.
  /// Keeping this iterator in memory lets bounded consumers continue without
  /// restarting count. [expand] and nearest queries share these exact rules.
  Iterable<RecurrenceScanStep> scan(
    RecurrenceRule rule, {
    required DateTime through,
    DateTime? from,
    DateTime? preparationNotBeforeUtc,
    Duration leadTime = Duration.zero,
    Set<String> excludedKeys = const {},
  }) sync* {
    if (leadTime.isNegative) throw ArgumentError.value(leadTime, 'leadTime');
    CivilTimeResolver.resolve(rule.start, 'UTC');
    tz.getLocation(rule.timeZoneId);
    var end = RecurrenceRule.civilDate(through);
    if (rule.until != null && rule.until!.isBefore(end)) end = rule.until!;
    final lower = from == null ? rule.start : RecurrenceRule.civilTime(from);
    var counted = 0;
    for (final date in _dates(rule, end)) {
      if (date.missing) {
        yield RecurrenceScanStep(
          date.value,
          skipped: !date.value.isBefore(RecurrenceRule.civilDate(lower))
              ? RecurrenceSkip(date.value, RecurrenceSkipReason.nonexistentDate)
              : null,
        );
        continue;
      }
      final civil = DateTime.utc(
        date.value.year,
        date.value.month,
        date.value.day,
        rule.start.hour,
        rule.start.minute,
        rule.start.second,
        rule.start.millisecond,
        rule.start.microsecond,
      );
      if (civil.isBefore(rule.start)) {
        yield RecurrenceScanStep(civil);
        continue;
      }
      final resolved = CivilTimeResolver.resolve(civil, rule.timeZoneId);
      if (resolved.isEmpty) {
        yield RecurrenceScanStep(
          civil,
          skipped: !civil.isBefore(lower)
              ? RecurrenceSkip(civil, RecurrenceSkipReason.nonexistentTime)
              : null,
        );
        continue;
      }
      if (resolved.length > 1 && rule.repeatedTime == null) {
        throw RepeatedTimeChoiceRequired(civil);
      }
      final actual =
          resolved.length > 1 && rule.repeatedTime == RepeatedCivilTime.second
          ? resolved.last
          : resolved.first;
      if (preparationNotBeforeUtc != null &&
          actual.instantUtc
              .subtract(leadTime)
              .isBefore(preparationNotBeforeUtc.toUtc())) {
        yield RecurrenceScanStep(
          civil,
          skipped: !civil.isBefore(lower)
              ? RecurrenceSkip(civil, RecurrenceSkipReason.preparationPassed)
              : null,
        );
        continue;
      }
      counted++;
      final slot =
          !civil.isBefore(lower) &&
              !excludedKeys.contains(civil.toIso8601String())
          ? RecurrenceSlot(
              civilTime: civil,
              instantUtc: actual.instantUtc,
              offsetSeconds: actual.offsetSeconds,
              ordinal: counted,
            )
          : null;
      yield RecurrenceScanStep(
        civil,
        slot: slot,
        countComplete: counted == rule.count,
      );
      if (counted == rule.count) break;
    }
  }

  Iterable<_CandidateDate> _dates(RecurrenceRule rule, DateTime end) sync* {
    final start = RecurrenceRule.civilDate(rule.start);
    switch (rule.frequency) {
      case RecurrenceFrequency.daily:
        for (var date = start; !date.isAfter(end);) {
          yield _CandidateDate(date);
          // Check the remaining distance before adding arbitrary user intervals.
          if (end.difference(date).inDays < rule.interval) break;
          date = date.add(Duration(days: rule.interval));
        }
      case RecurrenceFrequency.weekly:
        var week = start.subtract(Duration(days: start.weekday - 1));
        final weekdays = rule.weekdays.toList()..sort();
        while (!week.isAfter(end)) {
          for (final day in weekdays) {
            final date = week.add(Duration(days: day - 1));
            if (!date.isBefore(start) && !date.isAfter(end)) {
              yield _CandidateDate(date);
            }
          }
          if (end.difference(week).inDays ~/ 7 < rule.interval) break;
          week = week.add(Duration(days: 7 * rule.interval));
        }
      case RecurrenceFrequency.monthly:
        var month = start.year * 12 + start.month - 1;
        final endMonth = end.year * 12 + end.month - 1;
        while (month <= endMonth) {
          final first = DateTime.utc(month ~/ 12, month % 12 + 1);
          final last = DateTime.utc(first.year, first.month + 1, 0).day;
          final int day;
          switch (rule.monthly) {
            case MonthlyRecurrence.lastDay:
              day = last;
            case MonthlyRecurrence.dayOfMonth:
              day = rule.monthDay;
            case MonthlyRecurrence.nthWeekday:
              if (rule.ordinal == -1) {
                final lastWeekday = DateTime.utc(
                  first.year,
                  first.month,
                  last,
                ).weekday;
                day = last - (lastWeekday - rule.monthWeekday + 7) % 7;
              } else {
                day =
                    1 +
                    (rule.monthWeekday - first.weekday + 7) % 7 +
                    7 * (rule.ordinal - 1);
              }
          }
          if (day > last) {
            yield _CandidateDate(first, missing: true);
          } else {
            final date = DateTime.utc(first.year, first.month, day);
            if (!date.isBefore(start) && !date.isAfter(end)) {
              yield _CandidateDate(date);
            }
          }
          if (endMonth - month < rule.interval) break;
          month += rule.interval;
        }
    }
  }
}

class _CandidateDate {
  const _CandidateDate(this.value, {this.missing = false});
  final DateTime value;
  final bool missing;
}

/// Frontier is conservative even for nonexistent calendar dates.
final class RecurrenceScanStep {
  const RecurrenceScanStep(
    this.frontierCivil, {
    this.slot,
    this.skipped,
    this.countComplete = false,
  });
  final DateTime frontierCivil;
  final RecurrenceSlot? slot;
  final RecurrenceSkip? skipped;
  final bool countComplete;
}
