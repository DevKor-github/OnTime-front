import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'package:timezone/timezone.dart' as tz;
import 'backup_limits.dart';
import 'backup_value_validation.dart';

class BackupRuleCandidate {
  const BackupRuleCandidate(
    this.civil,
    this.calendarOrdinal,
    this.currentOrdinal,
    this.offsets,
    this.eligible,
  );
  final DateTime civil;
  final int calendarOrdinal;
  final int currentOrdinal;
  final List<int> offsets;
  final bool eligible;
}

typedef BackupOffsetLookup =
    List<int> Function(DateTime civil, String zone, BackupBudget budget);

/// One bounded traversal per segment. Calendar membership/upper bound is
/// independent of tzdb; current ordinal is explicitly only a current-rule
/// observation, never proof of a historic rule version.
Stream<BackupRuleCandidate> scanBackupRule({
  required RecurrenceRule rule,
  required DateTime through,
  required BackupBudget budget,
  required Duration leadTime,
  DateTime? preparationNotBefore,
  BackupOffsetLookup offsetLookup = backupOffsets,
}) async* {
  var calendar = 0;
  var counted = 0;
  for (final date in _dates(rule, through, budget)) {
    final civil = DateTime.utc(
      date.year,
      date.month,
      date.day,
      rule.start.hour,
      rule.start.minute,
      rule.start.second,
      rule.start.millisecond,
      rule.start.microsecond,
    );
    if (civil.isBefore(rule.start) || civil.isAfter(through)) continue;
    calendar++;
    if (calendar % 256 == 0) await Future<void>.delayed(Duration.zero);
    final offsets = offsetLookup(civil, rule.timeZoneId, budget);
    final selected =
        offsets.isEmpty || (offsets.length > 1 && rule.repeatedTime == null)
        ? null
        : rule.repeatedTime == RepeatedCivilTime.second
        ? offsets.last
        : offsets.first;
    var eligible = selected != null;
    if (selected != null && preparationNotBefore != null) {
      final earliest =
          civil.microsecondsSinceEpoch -
          selected * 1000000 -
          leadTime.inMicroseconds;
      eligible =
          earliest >= preparationNotBefore.toUtc().microsecondsSinceEpoch;
    }
    if (eligible) counted++;
    yield BackupRuleCandidate(
      civil,
      calendar,
      counted,
      offsets,
      eligible && (rule.count == null || counted <= rule.count!),
    );
  }
}

List<int> backupOffsets(DateTime civil, String zone, BackupBudget budget) {
  BackupValueValidation.namedZone(zone);
  final location = tz.getLocation(zone);
  final distinct = <int>{};
  for (final zone in location.zones) {
    budget.visit();
    distinct.add(zone.offset ~/ 1000);
  }
  final results = <int>[];
  for (final offset in distinct) {
    budget.visit();
    final instant = civil.subtract(Duration(seconds: offset));
    final observed = tz.TZDateTime.from(instant, location);
    if (observed.year == civil.year &&
        observed.month == civil.month &&
        observed.day == civil.day &&
        observed.hour == civil.hour &&
        observed.minute == civil.minute &&
        observed.second == civil.second &&
        observed.millisecond == civil.millisecond &&
        observed.microsecond == civil.microsecond) {
      results.add(offset);
    }
  }
  // Earliest instant has the largest UTC offset (e.g. -04 before -05).
  results.sort((a, b) => b.compareTo(a));
  return results;
}

Iterable<DateTime> _dates(
  RecurrenceRule rule,
  DateTime through,
  BackupBudget budget,
) sync* {
  var end = RecurrenceRule.civilDate(through);
  if (rule.until != null && rule.until!.isBefore(end)) end = rule.until!;
  final start = RecurrenceRule.civilDate(rule.start);
  switch (rule.frequency) {
    case RecurrenceFrequency.daily:
      var date = start;
      while (!date.isAfter(end)) {
        budget.visit();
        yield date;
        if (end.difference(date).inDays < rule.interval) break;
        date = date.add(Duration(days: rule.interval));
      }
    case RecurrenceFrequency.weekly:
      var week = start.subtract(Duration(days: start.weekday - 1));
      final weekdays = rule.weekdays.toList()..sort();
      while (!week.isAfter(end)) {
        budget.visit();
        for (final weekday in weekdays) {
          budget.visit();
          final date = week.add(Duration(days: weekday - 1));
          if (!date.isBefore(start) && !date.isAfter(end)) yield date;
        }
        if (end.difference(week).inDays ~/ 7 < rule.interval) break;
        week = week.add(Duration(days: 7 * rule.interval));
      }
    case RecurrenceFrequency.monthly:
      var month = start.year * 12 + start.month - 1;
      final lastMonth = end.year * 12 + end.month - 1;
      while (month <= lastMonth) {
        budget.visit();
        final first = DateTime.utc(month ~/ 12, month % 12 + 1);
        final last = DateTime.utc(first.year, first.month + 1, 0).day;
        final int day;
        switch (rule.monthly) {
          case MonthlyRecurrence.dayOfMonth:
            day = rule.monthDay;
          case MonthlyRecurrence.lastDay:
            day = last;
          case MonthlyRecurrence.nthWeekday:
            day = rule.ordinal == -1
                ? last -
                      (DateTime.utc(first.year, first.month, last).weekday -
                              rule.monthWeekday +
                              7) %
                          7
                : 1 +
                      (rule.monthWeekday - first.weekday + 7) % 7 +
                      7 * (rule.ordinal - 1);
        }
        if (day <= last) {
          final date = DateTime.utc(first.year, first.month, day);
          if (!date.isBefore(start) && !date.isAfter(end)) yield date;
        }
        if (lastMonth - month < rule.interval) break;
        month += rule.interval;
      }
  }
}
