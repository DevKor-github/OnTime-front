import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/calendar/bloc/monthly_schedules_bloc.dart';
import 'package:on_time_front/presentation/calendar/component/schedule_detail.dart';
import 'package:on_time_front/presentation/schedule_create/screens/schedule_edit_screen.dart';
import 'package:on_time_front/presentation/shared/components/calendar/centered_calendar_header.dart';
import 'package:on_time_front/presentation/shared/theme/calendar_theme.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _selectedDate;

  DateTime get _firstDay => DateTime(2024, 12, 1);

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

  @override
  void initState() {
    super.initState();
    _selectedDate = _clampDay(DateTime.now(), _firstDay, _lastDay);
  }

  void _onLeftArrowTap() {
    setState(() {
      final next = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
      _selectedDate = _clampDay(next, _firstDay, _lastDay);
    });
  }

  void _onRightArrowTap() {
    setState(() {
      final next = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
      _selectedDate = _clampDay(next, _firstDay, _lastDay);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final todaysDate = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day, 0, 0, 0);
    final calendarTheme = theme.extension<CalendarTheme>()!;

    return BlocProvider(
      create: (context) => getIt.get<MonthlySchedulesBloc>()
        ..add(MonthlySchedulesSubscriptionRequested(date: todaysDate)),
      child: Scaffold(
        backgroundColor: colorScheme.surfaceContainerLow,
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.calendarTitle),
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
                  borderRadius: BorderRadius.circular(11),
                  color: colorScheme.surface,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 16.0, horizontal: 8.0),
                  child:
                      BlocBuilder<MonthlySchedulesBloc, MonthlySchedulesState>(
                    builder: (context, state) {
                      if (state.status == MonthlySchedulesStatus.error) {
                        return Text(AppLocalizations.of(context)!.error);
                      }

                      return TableCalendar(
                        locale: Localizations.localeOf(context).toString(),
                        daysOfWeekHeight: 40,
                        eventLoader: (day) {
                          day = DateTime(day.year, day.month, day.day);
                          return state.schedules[day] ?? [];
                        },
                        focusedDay: _selectedDate,
                        firstDay: _firstDay,
                        lastDay: _lastDay,
                        calendarFormat: CalendarFormat.month,
                        headerStyle: calendarTheme.headerStyle,
                        daysOfWeekStyle: calendarTheme.daysOfWeekStyle,
                        calendarStyle: calendarTheme.calendarStyle,
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDate =
                                _clampDay(selectedDay, _firstDay, _lastDay);
                          });
                          debugPrint(selectedDay.toIso8601String());
                        },
                        onPageChanged: (focusedDay) {
                          setState(() {
                            _selectedDate =
                                _clampDay(focusedDay, _firstDay, _lastDay);
                          });
                          debugPrint(_selectedDate.toIso8601String());
                          final clampedDay =
                              _clampDay(focusedDay, _firstDay, _lastDay);
                          context.read<MonthlySchedulesBloc>().add(
                              MonthlySchedulesMonthAdded(
                                  date: DateTime(clampedDay.year,
                                      clampedDay.month, clampedDay.day)));
                        },
                        calendarBuilders: CalendarBuilders(
                          headerTitleBuilder: (context, date) {
                            return CenteredCalendarHeader(
                              focusedMonth: date,
                              onLeftArrowTap: _onLeftArrowTap,
                              onRightArrowTap: _onRightArrowTap,
                              titleTextStyle:
                                  calendarTheme.headerStyle.titleTextStyle,
                              leftIcon:
                                  calendarTheme.headerStyle.leftChevronIcon,
                              rightIcon:
                                  calendarTheme.headerStyle.rightChevronIcon,
                            );
                          },
                          todayBuilder: (context, day, focusedDay) => Container(
                            margin: const EdgeInsets.all(4.0),
                            alignment: Alignment.center,
                            decoration: calendarTheme.todayDecoration,
                            child: Text(
                              DateFormat.d(Localizations.localeOf(context)
                                      .toString())
                                  .format(day),
                              style: textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 18.0),
              BlocBuilder<MonthlySchedulesBloc, MonthlySchedulesState>(
                builder: (context, state) {
                  if (state.schedules[_selectedDate]?.isEmpty ?? true) {
                    if (state.status == MonthlySchedulesStatus.loading) {
                      return CircularProgressIndicator();
                    } else if (state.status != MonthlySchedulesStatus.success) {
                      return const SizedBox();
                    } else {
                      return Text(AppLocalizations.of(context)!.noSchedules);
                    }
                  }

                  return Expanded(
                    child: ListView.builder(
                      itemCount: state.schedules[_selectedDate]?.length ?? 0,
                      itemBuilder: (context, index) {
                        final schedule = state.schedules[_selectedDate]![index];
                        return ScheduleDetail(
                          schedule: schedule,
                          onEdit: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => ScheduleEditScreen(
                                scheduleId: schedule.id,
                              ),
                            );
                          },
                          onDeleted: () {
                            context.read<MonthlySchedulesBloc>().add(
                                  MonthlySchedulesScheduleDeleted(
                                      schedule: schedule),
                                );
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
