import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/calendar/bloc/monthly_schedules_bloc.dart';
import 'package:on_time_front/presentation/calendar/component/schedule_detail.dart';
import 'package:on_time_front/presentation/schedule_create/screens/schedule_edit_screen.dart';
import 'package:on_time_front/presentation/schedule_create/screens/schedule_create_screen.dart';
import 'package:on_time_front/presentation/shared/components/calendar/centered_calendar_header.dart';
import 'package:on_time_front/presentation/shared/components/two_button_delete_dialog.dart';
import 'package:on_time_front/presentation/shared/theme/calendar_theme.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final lastDay = DateTime(2026, 12, 31);

    if (widget.initialDate != null) {
      _selectedDate = DateTime(
        widget.initialDate!.year,
        widget.initialDate!.month,
        widget.initialDate!.day,
      );
    } else {
      _selectedDate = now.isAfter(lastDay)
          ? lastDay
          : DateTime(now.year, now.month, now.day);
    }
  }

  void _onLeftArrowTap() {
    final DateTime firstDay = DateTime(2024, 12, 1);
    final DateTime nextSelectedDate =
        DateTime(_selectedDate.year, _selectedDate.month - 1, 1);

    final DateTime clampedSelectedDate =
        nextSelectedDate.isBefore(firstDay) ? firstDay : nextSelectedDate;

    setState(() {
      _selectedDate = clampedSelectedDate;
    });
  }

  void _onRightArrowTap() {
    final DateTime lastDay = DateTime(2026, 12, 31);
    final DateTime nextSelectedDate =
        DateTime(_selectedDate.year, _selectedDate.month + 1, 1);

    final DateTime clampedSelectedDate =
        nextSelectedDate.isAfter(lastDay) ? lastDay : nextSelectedDate;

    setState(() {
      _selectedDate = clampedSelectedDate;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final calendarTheme = theme.extension<CalendarTheme>()!;

    return BlocProvider(
      create: (context) => getIt.get<MonthlySchedulesBloc>()
        ..add(MonthlySchedulesSubscriptionRequested(
            date: DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          0,
          0,
          0,
        ))),
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
                        lastDay: DateTime(2026, 12, 31),
                        calendarFormat: CalendarFormat.month,
                        headerStyle: calendarTheme.headerStyle,
                        daysOfWeekStyle: calendarTheme.daysOfWeekStyle,
                        calendarStyle: calendarTheme.calendarStyle,
                        onDaySelected: (selectedDay, focusedDay) {
                          final DateTime firstDay = DateTime(2024, 12, 1);
                          final DateTime lastDay = DateTime(2026, 12, 31);

                          DateTime clampedSelectedDate = DateTime(
                              selectedDay.year,
                              selectedDay.month,
                              selectedDay.day);

                          if (clampedSelectedDate.isBefore(firstDay)) {
                            clampedSelectedDate = firstDay;
                          } else if (clampedSelectedDate.isAfter(lastDay)) {
                            clampedSelectedDate = lastDay;
                          }

                          setState(() {
                            _selectedDate = clampedSelectedDate;
                          });
                          debugPrint(clampedSelectedDate.toIso8601String());
                        },
                        onPageChanged: (focusedDay) {
                          final DateTime firstDay = DateTime(2024, 12, 1);
                          final DateTime lastDay = DateTime(2026, 12, 31);

                          DateTime clampedFocusedDay = DateTime(focusedDay.year,
                              focusedDay.month, focusedDay.day);

                          if (clampedFocusedDay.isBefore(firstDay)) {
                            clampedFocusedDay = firstDay;
                          } else if (clampedFocusedDay.isAfter(lastDay)) {
                            clampedFocusedDay = lastDay;
                          }

                          setState(() {
                            _selectedDate = clampedFocusedDay;
                          });
                          debugPrint(_selectedDate.toIso8601String());
                          context.read<MonthlySchedulesBloc>().add(
                              MonthlySchedulesMonthAdded(
                                  date: DateTime(
                                      clampedFocusedDay.year,
                                      clampedFocusedDay.month,
                                      clampedFocusedDay.day)));
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
              const SizedBox(height: 32.0),
              BlocBuilder<MonthlySchedulesBloc, MonthlySchedulesState>(
                builder: (context, state) {
                  if (state.schedules[_selectedDate]?.isEmpty ?? true) {
                    if (state.status == MonthlySchedulesStatus.loading) {
                      return CircularProgressIndicator();
                    } else if (state.status != MonthlySchedulesStatus.success) {
                      return const SizedBox();
                    } else {
                      // Empty-state UI with date title and action box
                      final dateText =
                          DateFormat('M월 d일', 'ko').format(_selectedDate);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dateText,
                            style: textTheme.headlineExtraSmall,
                          ),
                          const SizedBox(height: 24.0),
                          Container(
                            width: double.infinity,
                            height: 148,
                            padding: const EdgeInsets.symmetric(vertical: 24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  '약속이 없어요',
                                  style: textTheme.titleMedium?.copyWith(
                                        color: colorScheme.outlineVariant,
                                      ) ??
                                      TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        height: 1.4,
                                        color: colorScheme.outlineVariant,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 32.0),
                                SizedBox(
                                  width: 149,
                                  height: 43,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (context) =>
                                            ScheduleCreateScreen(),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colorScheme.primary,
                                      foregroundColor: colorScheme.onPrimary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                        horizontal: 8,
                                      ),
                                    ),
                                    child: Text(
                                      '약속 추가하기',
                                      style: textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            height: 1.4,
                                            color: colorScheme.onPrimary,
                                          ) ??
                                          TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            height: 1.4,
                                            color: colorScheme.onPrimary,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }
                  }

                  return Expanded(
                    child: ListView.separated(
                      itemCount: state.schedules[_selectedDate]?.length ?? 0,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
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
                            showTwoButtonDeleteDialog(
                              context,
                              title: AppLocalizations.of(context)!
                                  .scheduleDeleteConfirmTitle,
                              description: AppLocalizations.of(context)!
                                  .scheduleDeleteConfirmDescription,
                              cancelText: AppLocalizations.of(context)!.cancel,
                              confirmText: AppLocalizations.of(context)!
                                  .deleteScheduleConfirmAction,
                            ).then((confirmed) {
                              if (confirmed != true || !context.mounted) {
                                return;
                              }
                              context.read<MonthlySchedulesBloc>().add(
                                    MonthlySchedulesScheduleDeleted(
                                        schedule: schedule),
                                  );
                            });
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
