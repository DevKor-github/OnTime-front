import 'package:equatable/equatable.dart';

enum RecurrenceFrequency { daily, weekly, monthly }

enum MonthlyRecurrence { dayOfMonth, nthWeekday, lastDay }

enum RepeatedCivilTime { first, second }

/// A rule in the schedule's named time zone, independent of the device zone.
/// Until is an inclusive civil date; count counts valid slots before exclusions.
class RecurrenceRule extends Equatable {
  RecurrenceRule({
    required this.frequency,
    required DateTime start,
    required this.timeZoneId,
    this.interval = 1,
    Set<int> weekdays = const {},
    this.monthly = MonthlyRecurrence.dayOfMonth,
    int? monthDay,
    this.ordinal = 1,
    int? monthWeekday,
    DateTime? until,
    this.count,
    this.repeatedTime,
  }) : start = civilTime(start),
       weekdays = Set.unmodifiable(weekdays),
       monthDay = monthDay ?? start.day,
       monthWeekday = monthWeekday ?? start.weekday,
       until = until == null ? null : civilDate(until) {
    if (interval < 1) throw ArgumentError.value(interval, 'interval');
    if (timeZoneId.trim().isEmpty) throw ArgumentError.value(timeZoneId);
    if (start.year < 1 || start.year > 9999) {
      throw ArgumentError.value(start, 'start');
    }
    if (frequency == RecurrenceFrequency.weekly && weekdays.isEmpty) {
      throw ArgumentError('Select at least one weekday.');
    }
    if (weekdays.any((day) => day < 1 || day > 7)) {
      throw ArgumentError.value(weekdays, 'weekdays');
    }
    if (this.monthDay < 1 || this.monthDay > 31) {
      throw ArgumentError.value(this.monthDay, 'monthDay');
    }
    if ((ordinal < 1 || ordinal > 5) && ordinal != -1) {
      throw ArgumentError.value(ordinal, 'ordinal');
    }
    if (this.monthWeekday < 1 || this.monthWeekday > 7) {
      throw ArgumentError.value(this.monthWeekday, 'monthWeekday');
    }
    if (count != null && count! < 1) throw ArgumentError.value(count, 'count');
    if (count != null && until != null) {
      throw ArgumentError('Count and until cannot both be set.');
    }
    if (this.until?.isBefore(civilDate(start)) ?? false) {
      throw ArgumentError('The end date precedes the start date.');
    }
  }

  final RecurrenceFrequency frequency;
  final DateTime start;
  final String timeZoneId;
  final int interval;
  final Set<int> weekdays;
  final MonthlyRecurrence monthly;
  final int monthDay;

  /// 1..5, or -1 for the last weekday of the month.
  final int ordinal;
  final int monthWeekday;
  final DateTime? until;
  final int? count;
  final RepeatedCivilTime? repeatedTime;

  RecurrenceRule withStartAndEnd({
    DateTime? start,
    int? count,
    DateTime? until,
    RepeatedCivilTime? repeatedTime,
  }) => RecurrenceRule(
    frequency: frequency,
    start: start ?? this.start,
    timeZoneId: timeZoneId,
    interval: interval,
    weekdays: weekdays,
    monthly: monthly,
    monthDay: monthDay,
    ordinal: ordinal,
    monthWeekday: monthWeekday,
    count: count,
    until: until,
    repeatedTime: repeatedTime ?? this.repeatedTime,
  );

  static DateTime civilDate(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);

  static DateTime civilTime(DateTime value) => DateTime.utc(
    value.year,
    value.month,
    value.day,
    value.hour,
    value.minute,
    value.second,
    value.millisecond,
    value.microsecond,
  );

  @override
  List<Object?> get props => [
    frequency,
    start,
    timeZoneId,
    interval,
    weekdays,
    monthly,
    monthDay,
    ordinal,
    monthWeekday,
    until,
    count,
    repeatedTime,
  ];
}
