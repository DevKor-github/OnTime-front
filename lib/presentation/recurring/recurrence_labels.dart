import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';

String recurrenceText(BuildContext context, String ko, String en) =>
    Localizations.localeOf(context).languageCode == 'ko' ? ko : en;
String recurrenceDate(BuildContext context, DateTime value) => DateFormat.yMMMd(
  Localizations.localeOf(context).toString(),
).add_jm().format(value);
String recurrenceDay(BuildContext context, DateTime value) =>
    DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(value);
String weekdayLabel(BuildContext context, int day) => DateFormat.E(
  Localizations.localeOf(context).toString(),
).format(DateTime(2026, 1, 5).add(Duration(days: day - 1)));
String recurrenceLabel(BuildContext context, RecurrenceRule rule) {
  final ko = Localizations.localeOf(context).languageCode == 'ko';
  final interval = switch (rule.frequency) {
    RecurrenceFrequency.daily =>
      ko ? '${rule.interval}일마다' : 'Every ${rule.interval} day(s)',
    RecurrenceFrequency.weekly =>
      ko ? '${rule.interval}주마다' : 'Every ${rule.interval} week(s)',
    RecurrenceFrequency.monthly =>
      ko ? '${rule.interval}개월마다' : 'Every ${rule.interval} month(s)',
  };
  var detail = '';
  if (rule.frequency == RecurrenceFrequency.weekly) {
    detail = (rule.weekdays.toList()..sort())
        .map((d) => weekdayLabel(context, d))
        .join('·');
  } else if (rule.frequency == RecurrenceFrequency.monthly) {
    detail = switch (rule.monthly) {
      MonthlyRecurrence.dayOfMonth =>
        ko ? '${rule.monthDay}일' : 'Day ${rule.monthDay}',
      MonthlyRecurrence.lastDay => ko ? '마지막 날' : 'Last day',
      MonthlyRecurrence.nthWeekday =>
        '${rule.ordinal == -1 ? (ko ? '마지막' : 'Last') : (ko ? '${rule.ordinal}번째' : '#${rule.ordinal}')} ${weekdayLabel(context, rule.monthWeekday)}',
    };
  }
  return '$interval${detail.isEmpty ? '' : ' $detail'} · ${TimeOfDay.fromDateTime(rule.start).format(context)}';
}

String recurrenceEndLabel(BuildContext context, RecurrenceRule rule) =>
    rule.count != null
    ? recurrenceText(context, '${rule.count}회', '${rule.count} occurrences')
    : rule.until != null
    ? '${DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(rule.until!)}${recurrenceText(context, '까지', ' inclusive')}'
    : recurrenceText(context, '종료 없음', 'No end date');
