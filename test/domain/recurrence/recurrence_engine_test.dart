import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/recurrence/recurrence_engine.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';

void main() {
  const engine = RecurrenceEngine();
  RecurrenceRule rule({
    RecurrenceFrequency frequency = RecurrenceFrequency.monthly,
    DateTime? start,
    int interval = 1,
    Set<int> weekdays = const {},
    MonthlyRecurrence monthly = MonthlyRecurrence.dayOfMonth,
    int monthDay = 31,
    int ordinal = 1,
    int monthWeekday = 1,
    int? count,
    DateTime? until,
    String zone = 'Asia/Seoul',
    RepeatedCivilTime? repeatedTime,
  }) => RecurrenceRule(
    frequency: frequency,
    start: start ?? DateTime(2026, 1, 31, 9),
    timeZoneId: zone,
    interval: interval,
    weekdays: weekdays,
    monthly: monthly,
    monthDay: monthDay,
    ordinal: ordinal,
    monthWeekday: monthWeekday,
    count: count,
    until: until,
    repeatedTime: repeatedTime,
  );

  test('monthly 31st counts real dates and skips short months', () {
    final result = engine.expand(
      rule(count: 3),
      through: DateTime(2026, 12, 31),
    );
    expect(result.slots.map((s) => s.civilTime), [
      DateTime.utc(2026, 1, 31, 9),
      DateTime.utc(2026, 3, 31, 9),
      DateTime.utc(2026, 5, 31, 9),
    ]);
    expect(
      result.skipped.map((s) => s.reason),
      everyElement(RecurrenceSkipReason.nonexistentDate),
    );
    expect(result.slots.map((s) => s.ordinal), [1, 2, 3]);
  });
  test('deleting a counted slot never extends or fills the series', () {
    final result = engine.expand(
      rule(count: 3),
      through: DateTime(2026, 12, 31),
      excludedKeys: {DateTime.utc(2026, 3, 31, 9).toIso8601String()},
    );
    expect(result.slots.map((s) => s.civilTime.month), [1, 5]);
    expect(result.slots.map((s) => s.ordinal), [1, 3]);
  });
  test('last day is distinct from 31st, including leap February', () {
    final result = engine.expand(
      rule(
        start: DateTime(2028, 1, 31, 9),
        monthly: MonthlyRecurrence.lastDay,
        count: 3,
      ),
      through: DateTime(2028, 3, 31),
    );
    expect(result.slots.map((s) => s.civilTime.day), [31, 29, 31]);
  });
  test('fifth weekday skips missing months while last weekday does not', () {
    final fifth = engine.expand(
      rule(
        start: DateTime(2026, 1, 1),
        monthly: MonthlyRecurrence.nthWeekday,
        ordinal: 5,
        count: 2,
      ),
      through: DateTime(2026, 6, 30),
    );
    expect(fifth.slots.map((s) => s.civilTime), [
      DateTime.utc(2026, 3, 30),
      DateTime.utc(2026, 6, 29),
    ]);
    final last = engine.expand(
      rule(
        start: DateTime(2026, 1, 1),
        monthly: MonthlyRecurrence.nthWeekday,
        ordinal: -1,
        count: 2,
      ),
      through: DateTime(2026, 6, 30),
    );
    expect(last.slots.map((s) => s.civilTime), [
      DateTime.utc(2026, 1, 26),
      DateTime.utc(2026, 2, 23),
    ]);
  });
  test('weekly matching starts inclusively without adding the anchor day', () {
    final result = engine.expand(
      rule(
        frequency: RecurrenceFrequency.weekly,
        start: DateTime(2026, 9, 22, 9),
        weekdays: {1, 3, 5},
        interval: 2,
        count: 5,
      ),
      through: DateTime(2026, 10, 31),
    );
    expect(result.slots.map((s) => s.civilTime), [
      DateTime.utc(2026, 9, 23, 9),
      DateTime.utc(2026, 9, 25, 9),
      DateTime.utc(2026, 10, 5, 9),
      DateTime.utc(2026, 10, 7, 9),
      DateTime.utc(2026, 10, 9, 9),
    ]);
  });
  test('daily intervals keep civil time and include the end date', () {
    final result = engine.expand(
      rule(
        frequency: RecurrenceFrequency.daily,
        start: DateTime(2026, 1, 1, 9),
        interval: 2,
        until: DateTime(2026, 1, 5),
      ),
      through: DateTime(2026, 12, 31),
    );
    expect(result.slots.map((s) => s.civilTime.day), [1, 3, 5]);
    expect(result.slots.first.instantUtc, DateTime.utc(2026, 1, 1));
  });
  test('spring gap is skipped and does not consume the count', () {
    final result = engine.expand(
      rule(
        frequency: RecurrenceFrequency.daily,
        start: DateTime(2026, 3, 7, 2, 30),
        zone: 'America/New_York',
        count: 3,
      ),
      through: DateTime(2026, 3, 12),
    );
    expect(result.slots.map((s) => s.civilTime.day), [7, 9, 10]);
    expect(result.skipped.single.reason, RecurrenceSkipReason.nonexistentTime);
  });
  test('fall overlap requires an explicit first or second choice', () {
    expect(
      () => engine.expand(
        rule(
          frequency: RecurrenceFrequency.daily,
          start: DateTime(2026, 11, 1, 1, 30),
          zone: 'America/New_York',
          count: 1,
        ),
        through: DateTime(2026, 11, 2),
      ),
      throwsA(isA<RepeatedTimeChoiceRequired>()),
    );
    for (final choice in RepeatedCivilTime.values) {
      final result = engine.expand(
        rule(
          frequency: RecurrenceFrequency.daily,
          start: DateTime(2026, 11, 1, 1, 30),
          zone: 'America/New_York',
          count: 1,
          repeatedTime: choice,
        ),
        through: DateTime(2026, 11, 2),
      );
      expect(
        result.slots.single.instantUtc,
        DateTime.utc(
          2026,
          11,
          1,
          choice == RepeatedCivilTime.first ? 5 : 6,
          30,
        ),
      );
    }
  });
  test('new series starts at a future preparation and counts from there', () {
    final result = engine.expand(
      rule(
        frequency: RecurrenceFrequency.daily,
        start: DateTime(2026, 9, 23, 9),
        count: 2,
      ),
      through: DateTime(2026, 9, 30),
      leadTime: const Duration(hours: 1),
      preparationNotBeforeUtc: DateTime.utc(2026, 9, 22, 23, 30),
    );
    expect(result.slots.map((s) => s.civilTime.day), [24, 25]);
    expect(result.slots.map((s) => s.ordinal), [1, 2]);
    expect(
      result.skipped.single.reason,
      RecurrenceSkipReason.preparationPassed,
    );
  });
  test('range queries preserve original count and stable slot keys', () {
    final base = rule(
      frequency: RecurrenceFrequency.daily,
      start: DateTime(2026, 1, 1, 9),
      count: 10,
    );
    final all = engine.expand(base, through: DateTime(2026, 1, 31));
    final range = engine.expand(
      base,
      from: DateTime(2026, 1, 8),
      through: DateTime(2026, 1, 31),
    );
    expect(range.slots.map((s) => s.key), all.slots.skip(7).map((s) => s.key));
    expect(range.slots.map((s) => s.ordinal), [8, 9, 10]);
  });
  test('unknown zone and exhausted search never report success', () {
    expect(
      () => engine.expand(
        rule(zone: 'Not/AZone'),
        through: DateTime(2026, 12, 31),
      ),
      throwsException,
    );
    expect(
      () => engine.expand(
        rule(),
        through: DateTime(2030, 12, 31),
        candidateBudget: 2,
      ),
      throwsA(isA<RecurrenceSearchLimit>()),
    );
  });
  test('invalid and ambiguous rule definitions are rejected', () {
    expect(() => rule(interval: 0), throwsArgumentError);
    expect(() => rule(count: 0), throwsArgumentError);
    expect(() => rule(monthDay: 32), throwsArgumentError);
    expect(() => rule(ordinal: 0), throwsArgumentError);
    expect(() => rule(count: 3, until: DateTime(2027)), throwsArgumentError);
    expect(
      () => rule(frequency: RecurrenceFrequency.weekly),
      throwsArgumentError,
    );
  });
}
