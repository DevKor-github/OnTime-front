import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/home/components/week_calendar.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'Default',
  type: WeekCalendar,
)
Widget weekCalendarUseCase(BuildContext context) {
  final now = DateTime.now();
  final highlightedCount = context.knobs.double
      .slider(
        label: 'Highlighted Days',
        min: 0,
        max: 7,
        initialValue: 2,
      )
      .toInt();

  final highlighted = List<DateTime>.generate(
    highlightedCount,
    (i) => DateTime(now.year, now.month, now.day + i),
  );

  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: WeekCalendar(
      date: now,
      highlightedDates: highlighted,
      onDateSelected: (d) {},
    ),
  );
}
