import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/presentation/calendar/component/schedule_detail.dart';
import 'package:on_time_front/presentation/calendar/view_models/calendar_view_model.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _selectedDate =
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final todaysDate = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day, 0, 0, 0);

    final calendarViewModel =
        ref.read(calendarViewModelProvider(todaysDate).notifier);
    final schedules = ref.watch(calendarViewModelProvider(todaysDate));

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLow,
      appBar: AppBar(
        title: const Text('Calendar'),
        backgroundColor: colorScheme.surfaceContainerLow,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.go('/home');
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(11),
              ),
              child: switch (schedules) {
                AsyncValue(:final error?) => Text('Error: $error'),
                AsyncValue(:final valueOrNull?) => TableCalendar(
                    eventLoader: (day) {
                      day = DateTime(day.year, day.month, day.day);
                      return valueOrNull[day] ?? [];
                    },
                    focusedDay: _selectedDate,
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
                        _selectedDate = DateTime(selectedDay.year,
                            selectedDay.month, selectedDay.day);
                      });
                      debugPrint(selectedDay.toIso8601String());
                    },
                    onPageChanged: (focusedDay) {
                      calendarViewModel.getSchedulesForMonth(
                          DateTime(focusedDay.year, focusedDay.month));
                      setState(() {
                        _selectedDate = DateTime(
                            focusedDay.year, focusedDay.month, focusedDay.day);
                      });
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
                _ => const SizedBox(
                    height: 400.0,
                    width: double.infinity,
                  ),
              },
            ),
            SizedBox(height: 18.0),
            switch (schedules) {
              AsyncValue(:final error?) => Text('Error: $error'),
              AsyncValue(:final valueOrNull?) => Expanded(
                  child: ListView.builder(
                    itemCount: valueOrNull[_selectedDate]?.length ?? 0,
                    itemBuilder: (context, index) {
                      final schedule = valueOrNull[_selectedDate]![index];
                      return ScheduleDetail(schedule: schedule);
                    },
                  ),
                ),
              _ => const SizedBox(),
            },
          ],
        ),
      ),
    );
  }
}
