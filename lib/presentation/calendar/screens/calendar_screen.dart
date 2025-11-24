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
  DateTime _selectedDate =
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  void _onLeftArrowTap() {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
    });
  }

  void _onRightArrowTap() {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
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
                        firstDay: DateTime(2024, 12, 1),
                        lastDay: DateTime(2025, 12, 31),
                        calendarFormat: CalendarFormat.month,
                        headerStyle: calendarTheme.headerStyle,
                        daysOfWeekStyle: calendarTheme.daysOfWeekStyle,
                        calendarStyle: calendarTheme.calendarStyle,
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDate = DateTime(selectedDay.year,
                                selectedDay.month, selectedDay.day);
                          });
                          debugPrint(selectedDay.toIso8601String());
                        },
                        onPageChanged: (focusedDay) {
                          setState(() {
                            _selectedDate = DateTime(focusedDay.year,
                                focusedDay.month, focusedDay.day);
                          });
                          debugPrint(_selectedDate.toIso8601String());
                          context.read<MonthlySchedulesBloc>().add(
                              MonthlySchedulesMonthAdded(
                                  date: DateTime(focusedDay.year,
                                      focusedDay.month, focusedDay.day)));
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
