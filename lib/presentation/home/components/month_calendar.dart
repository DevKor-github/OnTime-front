import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/presentation/calendar/bloc/monthly_schedules_bloc.dart';
import 'package:on_time_front/presentation/shared/components/calendar/centered_calendar_header.dart';
import 'package:on_time_front/presentation/shared/theme/calendar_theme.dart';
import 'package:table_calendar/table_calendar.dart';

class MonthCalendar extends StatefulWidget {
  const MonthCalendar({
    super.key,
    required this.monthlySchedulesState,
    this.dispatchBlocEvents = true,
    this.onDateSelected,
  });

  final MonthlySchedulesState monthlySchedulesState;
  final bool dispatchBlocEvents;
  final void Function(DateTime)? onDateSelected;

  @override
  State<MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<MonthCalendar> {
  late DateTime _focusedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final lastDay = DateTime(2026, 12, 31);
    _focusedDay = now.isAfter(lastDay) ? lastDay : now;
  }

  void _onLeftArrowTap() {
    final DateTime firstDay = DateTime(2024, 1, 1);
    final DateTime nextFocusedDay =
        DateTime(_focusedDay.year, _focusedDay.month - 1, 1);

    final DateTime clampedFocusedDay =
        nextFocusedDay.isBefore(firstDay) ? firstDay : nextFocusedDay;

    setState(() {
      _focusedDay = clampedFocusedDay;
    });
    if (widget.dispatchBlocEvents) {
      context.read<MonthlySchedulesBloc>().add(MonthlySchedulesMonthAdded(
          date: DateTime(clampedFocusedDay.year, clampedFocusedDay.month, 1)));
    }
  }

  void _onRightArrowTap() {
    final DateTime lastDay = DateTime(2026, 12, 31);
    final DateTime nextFocusedDay =
        DateTime(_focusedDay.year, _focusedDay.month + 1, 1);

    final DateTime clampedFocusedDay =
        nextFocusedDay.isAfter(lastDay) ? lastDay : nextFocusedDay;

    setState(() {
      _focusedDay = clampedFocusedDay;
    });
    if (widget.dispatchBlocEvents) {
      context.read<MonthlySchedulesBloc>().add(MonthlySchedulesMonthAdded(
          date: DateTime(clampedFocusedDay.year, clampedFocusedDay.month, 1)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final calendarTheme = theme.extension<CalendarTheme>()!;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
      ),
      child: TableCalendar(
        locale: Localizations.localeOf(context).toString(),
        eventLoader: (day) {
          day = DateTime(day.year, day.month, day.day);
          return widget.monthlySchedulesState.schedules[day] ?? [];
        },
        sixWeekMonthsEnforced: true,
        rowHeight: 50,
        availableGestures: AvailableGestures.none,
        focusedDay: _focusedDay,
        firstDay: DateTime(2024, 1, 1),
        lastDay: DateTime(2026, 12, 31),
        calendarFormat: CalendarFormat.month,
        headerStyle: calendarTheme.headerStyle,
        daysOfWeekStyle: calendarTheme.daysOfWeekStyle,
        daysOfWeekHeight: 40,
        calendarStyle: calendarTheme.calendarStyle,
        onDaySelected: (selectedDay, focusedDay) {
          if (widget.onDateSelected != null) {
            widget.onDateSelected!(selectedDay);
          }
        },
        onPageChanged: (focusedDay) {
          final DateTime firstDay = DateTime(2024, 1, 1);
          final DateTime lastDay = DateTime(2026, 12, 31);

          DateTime clampedFocusedDay = focusedDay;
          if (focusedDay.isBefore(firstDay)) {
            clampedFocusedDay = firstDay;
          } else if (focusedDay.isAfter(lastDay)) {
            clampedFocusedDay = lastDay;
          }

          setState(() {
            _focusedDay = clampedFocusedDay;
          });
          if (widget.dispatchBlocEvents) {
            context.read<MonthlySchedulesBloc>().add(MonthlySchedulesMonthAdded(
                date: DateTime(clampedFocusedDay.year, clampedFocusedDay.month,
                    clampedFocusedDay.day)));
          }
        },
        calendarBuilders: CalendarBuilders(
          headerTitleBuilder: (context, date) {
            return CenteredCalendarHeader(
              focusedMonth: date,
              onLeftArrowTap: _onLeftArrowTap,
              onRightArrowTap: _onRightArrowTap,
              titleTextStyle: calendarTheme.headerStyle.titleTextStyle,
              leftIcon: calendarTheme.headerStyle.leftChevronIcon,
              rightIcon: calendarTheme.headerStyle.rightChevronIcon,
            );
          },
          todayBuilder: (context, day, focusedDay) => Container(
            margin: const EdgeInsets.all(4.0),
            alignment: Alignment.center,
            decoration: calendarTheme.todayDecoration,
            child: Text(
              day.day.toString(),
              style: textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
