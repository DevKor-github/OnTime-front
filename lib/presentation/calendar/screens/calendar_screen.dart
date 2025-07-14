import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/calendar/bloc/monthly_schedules_bloc.dart';
import 'package:on_time_front/presentation/calendar/component/schedule_detail.dart';
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
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: BlocBuilder<MonthlySchedulesBloc, MonthlySchedulesState>(
                  builder: (context, state) {
                    if (state.status == MonthlySchedulesStatus.error) {
                      return Text(AppLocalizations.of(context)!.error);
                    }

                    return TableCalendar(
                      eventLoader: (day) {
                        day = DateTime(day.year, day.month, day.day);
                        return state.schedules[day] ?? [];
                      },
                      focusedDay: _selectedDate,
                      firstDay: DateTime(2024, 12, 1),
                      lastDay: DateTime(2025, 12, 31),
                      calendarFormat: CalendarFormat.month,
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextFormatter: (date, locale) =>
                            DateFormat.yMMMM(locale).format(date),
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
                        todayBuilder: (context, day, focusedDay) => Container(
                          margin: const EdgeInsets.all(4.0),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            DateFormat.d(
                                    Localizations.localeOf(context).toString())
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
              SizedBox(height: 18.0),
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
                            context.go(
                              '/scheduleEdit/${schedule.id}',
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
