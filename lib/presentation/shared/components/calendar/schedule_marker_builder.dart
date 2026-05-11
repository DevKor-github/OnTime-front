import 'package:flutter/widgets.dart';
import 'package:table_calendar/table_calendar.dart';

Widget? selectedDayScheduleMarkerBuilder<T>({
  required DateTime selectedDay,
  required DateTime day,
  required List<T> events,
}) {
  if (events.isNotEmpty && isSameDay(selectedDay, day)) {
    return const SizedBox.shrink();
  }

  return null;
}
