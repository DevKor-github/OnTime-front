import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_time_front/presentation/calendar/view_models/calendar_view_model.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime selectedDate =
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final schedules = ref.watch(calendarViewModelProvider(
        DateTime(DateTime.now().year, DateTime.now().month)));
    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Calendar'),
      ),
      body: Column(
        children: [
          switch (schedules) {
            AsyncValue(:final error?) => Text('Error: $error'),
            AsyncValue(:final valueOrNull?) => TableCalendar(
                eventLoader: (day) {
                  final datesOfSchedules = valueOrNull.map((schedule) {
                    return schedule.scheduleTime;
                  });
                  return datesOfSchedules.where((schedule) {
                    return schedule.year == day.year &&
                        schedule.month == day.month &&
                        schedule.day == day.day;
                  }).toList();
                },
                focusedDay: DateTime.now(),
                firstDay: DateTime(2024, 12, 1),
                lastDay: DateTime(2025, 12, 31),
                calendarFormat: CalendarFormat.month,
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: textTheme.bodySmall!,
                  weekendStyle: textTheme.bodySmall!,
                ),
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  weekendTextStyle: textTheme.bodySmall!,
                  defaultTextStyle: textTheme.bodySmall!,
                  markerDecoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  markerMargin: EdgeInsets.symmetric(horizontal: 1.0),
                ),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    selectedDate = selectedDay;
                  });
                  debugPrint(selectedDay.toIso8601String());
                },
                calendarBuilders: CalendarBuilders(
                  todayBuilder: (context, day, focusedDay) => Container(
                    margin: const EdgeInsets.all(4.0),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      day.day.toString(),
                      style: textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            _ => const SizedBox(),
          },
          Text(selectedDate.toIso8601String()),
        ],
      ),
    );
  }
}
