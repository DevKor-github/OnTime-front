import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/presentation/calendar/bloc/monthly_schedules_bloc.dart';
import 'package:on_time_front/presentation/shared/components/calendar/centered_calendar_header.dart';
import 'package:on_time_front/presentation/shared/components/calendar/schedule_marker_builder.dart';
import 'package:on_time_front/presentation/shared/theme/calendar_theme.dart';
import 'package:table_calendar/table_calendar.dart';

class MonthCalendar extends StatefulWidget {
  const MonthCalendar({
    super.key,
    required this.monthlySchedulesState,
    this.dispatchBlocEvents = true,
    this.onDateSelected,
    this.rowHeight = 50,
    this.daysOfWeekHeight = 40,
    this.contentPadding = const EdgeInsets.all(16.0),
    this.today,
  });

  final MonthlySchedulesState monthlySchedulesState;
  final bool dispatchBlocEvents;
  final void Function(DateTime)? onDateSelected;
  final double rowHeight;
  final double daysOfWeekHeight;
  final EdgeInsetsGeometry contentPadding;
  final DateTime? today;

  @override
  State<MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<MonthCalendar> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  bool _manuallyNavigated = false;
  DateTime get _today => widget.today ?? DateTime.now();

  DateTime get _firstDay => DateTime(2024, 1, 1);

  DateTime get _lastDay => DateTime(_today.year + 5, 12, 31);

  DateTime _clampDay(DateTime day, DateTime firstDay, DateTime lastDay) {
    final d = DateTime(day.year, day.month, day.day);
    final first = DateTime(firstDay.year, firstDay.month, firstDay.day);
    final last = DateTime(lastDay.year, lastDay.month, lastDay.day);

    if (d.isBefore(first)) return first;
    if (d.isAfter(last)) return last;
    return d;
  }

  @override
  void initState() {
    super.initState();
    _focusedDay = _clampDay(_today, _firstDay, _lastDay);
    _selectedDay = _focusedDay;
  }

  @override
  void didUpdateWidget(covariant MonthCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.today == null ||
        isSameDay(oldWidget.today, widget.today) ||
        _manuallyNavigated) {
      return;
    }
    final oldMonth = (_focusedDay.year, _focusedDay.month);
    _focusedDay = _clampDay(_today, _firstDay, _lastDay);
    _selectedDay = _focusedDay;
    if (oldMonth != (_focusedDay.year, _focusedDay.month) &&
        widget.dispatchBlocEvents) {
      context.read<MonthlySchedulesBloc>().add(
        MonthlySchedulesMonthAdded(
          date: DateTime(_focusedDay.year, _focusedDay.month, 1),
        ),
      );
    }
  }

  void _onLeftArrowTap() {
    _manuallyNavigated = true;
    final nextFocusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
    final clampedFocusedDay = _clampDay(nextFocusedDay, _firstDay, _lastDay);

    setState(() {
      _focusedDay = clampedFocusedDay;
    });

    if (widget.dispatchBlocEvents) {
      context.read<MonthlySchedulesBloc>().add(
        MonthlySchedulesMonthAdded(
          date: DateTime(clampedFocusedDay.year, clampedFocusedDay.month, 1),
        ),
      );
    }
  }

  void _onRightArrowTap() {
    _manuallyNavigated = true;
    final nextFocusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
    final clampedFocusedDay = _clampDay(nextFocusedDay, _firstDay, _lastDay);

    setState(() {
      _focusedDay = clampedFocusedDay;
    });

    if (widget.dispatchBlocEvents) {
      context.read<MonthlySchedulesBloc>().add(
        MonthlySchedulesMonthAdded(
          date: DateTime(clampedFocusedDay.year, clampedFocusedDay.month, 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final calendarTheme = theme.extension<CalendarTheme>()!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedPadding = widget.contentPadding.resolve(
          Directionality.of(context),
        );
        final constrainedRowHeight = _constrainedRowHeight(
          maxHeight: constraints.maxHeight,
          verticalPadding: resolvedPadding.vertical,
        );

        return Container(
          padding: widget.contentPadding,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(11)),
          child: TableCalendar(
            locale: Localizations.localeOf(context).toString(),
            eventLoader: (day) {
              day = DateTime(day.year, day.month, day.day);
              return widget.monthlySchedulesState.schedules[day] ?? [];
            },
            sixWeekMonthsEnforced: true,
            rowHeight: constrainedRowHeight,
            availableGestures: AvailableGestures.none,
            focusedDay: _focusedDay,
            currentDay: _today,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            firstDay: _firstDay,
            lastDay: _lastDay,
            calendarFormat: CalendarFormat.month,
            headerStyle: calendarTheme.headerStyle,
            daysOfWeekStyle: calendarTheme.daysOfWeekStyle,
            daysOfWeekHeight: widget.daysOfWeekHeight,
            calendarStyle: calendarTheme.calendarStyle,
            onDaySelected: (selectedDay, focusedDay) {
              _manuallyNavigated = true;
              final clampedSelectedDay = _clampDay(
                selectedDay,
                _firstDay,
                _lastDay,
              );
              final clampedFocusedDay = _clampDay(
                focusedDay,
                _firstDay,
                _lastDay,
              );

              setState(() {
                _selectedDay = clampedSelectedDay;
                _focusedDay = clampedFocusedDay;
              });

              widget.onDateSelected?.call(clampedSelectedDay);
            },
            onPageChanged: (focusedDay) {
              final clampedFocusedDay = _clampDay(
                focusedDay,
                _firstDay,
                _lastDay,
              );

              setState(() {
                _focusedDay = clampedFocusedDay;
              });

              if (widget.dispatchBlocEvents) {
                context.read<MonthlySchedulesBloc>().add(
                  MonthlySchedulesMonthAdded(
                    date: DateTime(
                      clampedFocusedDay.year,
                      clampedFocusedDay.month,
                      1,
                    ),
                  ),
                );
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
              markerBuilder: (context, day, events) {
                return selectedDayScheduleMarkerBuilder(
                  selectedDay: _selectedDay,
                  day: day,
                  events: events,
                );
              },
              selectedBuilder: (context, day, focusedDay) {
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
      },
    );
  }

  double _constrainedRowHeight({
    required double maxHeight,
    required double verticalPadding,
  }) {
    if (!maxHeight.isFinite) {
      return widget.rowHeight;
    }

    const headerHeight = 64.0;
    final availableRowsHeight =
        maxHeight - verticalPadding - headerHeight - widget.daysOfWeekHeight;
    final fittedRowHeight = availableRowsHeight / 6;

    return fittedRowHeight.clamp(24.0, 56.0).toDouble();
  }
}
