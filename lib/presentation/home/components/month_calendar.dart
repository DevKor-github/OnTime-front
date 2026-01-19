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
  });

  final MonthlySchedulesState monthlySchedulesState;
  final bool dispatchBlocEvents;

  @override
  State<MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<MonthCalendar> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = _clampDay(DateTime.now(), _firstDay, _lastDay);
    _selectedDay = _focusedDay;
  }

  DateTime get _firstDay => DateTime(2000, 1, 1);

  // Keep this comfortably in the future so the calendar doesn't break as time passes.
  DateTime get _lastDay => DateTime(DateTime.now().year + 5, 12, 31);

  DateTime _clampDay(DateTime day, DateTime firstDay, DateTime lastDay) {
    final d = DateTime(day.year, day.month, day.day);
    final first = DateTime(firstDay.year, firstDay.month, firstDay.day);
    final last = DateTime(lastDay.year, lastDay.month, lastDay.day);

    if (d.isBefore(first)) return first;
    if (d.isAfter(last)) return last;
    return d;
  }

  void _onLeftArrowTap() {
    final DateTime nextFocusedDay =
        DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
    setState(() {
      _focusedDay = _clampDay(nextFocusedDay, _firstDay, _lastDay);
    });
    if (widget.dispatchBlocEvents) {
      context.read<MonthlySchedulesBloc>().add(MonthlySchedulesMonthAdded(
          date: DateTime(nextFocusedDay.year, nextFocusedDay.month, 1)));
    }
  }

  void _onRightArrowTap() {
    final DateTime nextFocusedDay =
        DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
    setState(() {
      _focusedDay = _clampDay(nextFocusedDay, _firstDay, _lastDay);
    });
    if (widget.dispatchBlocEvents) {
      context.read<MonthlySchedulesBloc>().add(MonthlySchedulesMonthAdded(
          date: DateTime(nextFocusedDay.year, nextFocusedDay.month, 1)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        firstDay: _firstDay,
        lastDay: _lastDay,
        calendarFormat: CalendarFormat.month,
        headerStyle: calendarTheme.headerStyle,
        daysOfWeekStyle: calendarTheme.daysOfWeekStyle,
        daysOfWeekHeight: 40,
        calendarStyle: calendarTheme.calendarStyle,
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = _clampDay(selectedDay, _firstDay, _lastDay);
            _focusedDay = _clampDay(focusedDay, _firstDay, _lastDay);
          });
        },
        onPageChanged: (focusedDay) {
          setState(() {
            _focusedDay = _clampDay(focusedDay, _firstDay, _lastDay);
          });
          if (widget.dispatchBlocEvents) {
            final clampedDay = _clampDay(focusedDay, _firstDay, _lastDay);
            context.read<MonthlySchedulesBloc>().add(MonthlySchedulesMonthAdded(
                date: DateTime(
                    clampedDay.year, clampedDay.month, clampedDay.day)));
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
          selectedBuilder: (context, day, focusedDay) {
            final isToday = isSameDay(day, DateTime.now());

            return Container(
              margin: const EdgeInsets.all(4.0),
              alignment: Alignment.center,
              decoration: calendarTheme.selectedDayDecoration,
              child: Text(
                day.day.toString(),
                style: calendarTheme.selectedDayTextStyle,
              ),
            );
          },
          todayBuilder: (context, day, focusedDay) => Container(
            margin: const EdgeInsets.all(4.0),
            alignment: Alignment.center,
            decoration: calendarTheme.todayDecoration,
            child: Text(
              day.day.toString(),
              style: calendarTheme.todayTextStyle,
            ),
          ),
        ),
      ),
    );
  }
}
