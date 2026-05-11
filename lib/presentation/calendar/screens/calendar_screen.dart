import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';
import 'package:on_time_front/presentation/calendar/bloc/monthly_schedules_bloc.dart';
import 'package:on_time_front/presentation/calendar/component/schedule_detail.dart';
import 'package:on_time_front/presentation/schedule_create/screens/schedule_create_screen.dart';
import 'package:on_time_front/presentation/schedule_create/screens/schedule_edit_screen.dart';
import 'package:on_time_front/presentation/shared/components/calendar/centered_calendar_header.dart';
import 'package:on_time_front/presentation/shared/components/calendar/schedule_marker_builder.dart';
import 'package:on_time_front/presentation/shared/components/two_button_delete_dialog.dart';
import 'package:on_time_front/presentation/shared/theme/calendar_theme.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const double _calendarHorizontalPadding = 8.0;
  static const double _calendarVerticalPadding = 12.0;
  static const double _calendarDaysOfWeekHeight = 36.0;
  static const double _calendarRowHeight = 44.0;

  late DateTime _selectedDate;
  late final MonthlySchedulesBloc _monthlySchedulesBloc;

  DateTime get _firstDay => DateTime(2024, 12, 1);

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

    final initial = widget.initialDate == null
        ? DateTime.now()
        : DateTime(
            widget.initialDate!.year,
            widget.initialDate!.month,
            widget.initialDate!.day,
          );

    _selectedDate = _clampDay(initial, _firstDay, _lastDay);
    _monthlySchedulesBloc = getIt.get<MonthlySchedulesBloc>()
      ..add(
        MonthlySchedulesSubscriptionRequested(
          date: DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
          ),
        ),
      )
      ..add(
        MonthlySchedulesVisibleDateChanged(
          date: _selectedDate,
        ),
      );
  }

  void _onLeftArrowTap() {
    final next = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);

    setState(() {
      _selectedDate = _clampDay(next, _firstDay, _lastDay);
    });
  }

  void _onRightArrowTap() {
    final next = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);

    setState(() {
      _selectedDate = _clampDay(next, _firstDay, _lastDay);
    });
  }

  void _refreshSchedulesIfSaved(bool? saved) {
    if (saved != true || !mounted) {
      return;
    }

    _monthlySchedulesBloc.add(
      MonthlySchedulesRefreshRequested(date: _selectedDate),
    );
  }

  void _returnHome() {
    if (!mounted) {
      return;
    }

    context.go('/home');
  }

  @override
  void dispose() {
    unawaited(_monthlySchedulesBloc.close());
    super.dispose();
  }

  Future<void> _openCreateScheduleSheet(BuildContext context) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ScheduleCreateScreen(
        initialDate: _selectedDate,
      ),
    );

    _refreshSchedulesIfSaved(saved);
  }

  Future<void> _openEditScheduleSheet(
    BuildContext context, {
    required String scheduleId,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ScheduleEditScreen(
        scheduleId: scheduleId,
      ),
    );

    _refreshSchedulesIfSaved(saved);
  }

  double _calendarDetailGap(double maxHeight) {
    if (!maxHeight.isFinite) {
      return 27.0;
    }

    if (maxHeight < 620.0) {
      return 12.0;
    }

    if (maxHeight < 720.0) {
      return 18.0;
    }

    return 27.0;
  }

  double _selectedDateHeadingGap(double maxHeight) {
    if (maxHeight.isFinite && maxHeight < 620.0) {
      return 12.0;
    }

    return 18.0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final calendarTheme = theme.extension<CalendarTheme>()!;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _returnHome();
        }
      },
      child: BlocProvider.value(
        value: _monthlySchedulesBloc,
        child: Scaffold(
          backgroundColor: colorScheme.surfaceContainerLow,
          appBar: AppBar(
            title: Text(AppLocalizations.of(context)!.calendarTitle),
            backgroundColor: colorScheme.surfaceContainerLow,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _returnHome,
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0) +
                EdgeInsets.only(bottom: 12.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final detailGap = _calendarDetailGap(constraints.maxHeight);
                final selectedDateHeadingGap =
                    _selectedDateHeadingGap(constraints.maxHeight);

                return Column(
                  children: [
                    Container(
                      key: const Key('calendar_card'),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: colorScheme.surface,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: _calendarVerticalPadding,
                          horizontal: _calendarHorizontalPadding,
                        ),
                        child: BlocBuilder<MonthlySchedulesBloc,
                            MonthlySchedulesState>(
                          builder: (context, state) {
                            if (state.status == MonthlySchedulesStatus.error) {
                              return Text(AppLocalizations.of(context)!.error);
                            }

                            return TableCalendar(
                              locale:
                                  Localizations.localeOf(context).toString(),
                              daysOfWeekHeight: _calendarDaysOfWeekHeight,
                              rowHeight: _calendarRowHeight,
                              eventLoader: (day) {
                                day = DateTime(day.year, day.month, day.day);
                                return state.schedules[day] ?? [];
                              },
                              focusedDay: _selectedDate,
                              selectedDayPredicate: (day) =>
                                  isSameDay(_selectedDate, day),
                              firstDay: _firstDay,
                              lastDay: _lastDay,
                              calendarFormat: CalendarFormat.month,
                              headerStyle: calendarTheme.headerStyle,
                              daysOfWeekStyle: calendarTheme.daysOfWeekStyle,
                              calendarStyle: calendarTheme.calendarStyle,
                              onDaySelected: (selectedDay, focusedDay) {
                                setState(() {
                                  _selectedDate = _clampDay(
                                      selectedDay, _firstDay, _lastDay);
                                });
                                _monthlySchedulesBloc.add(
                                  MonthlySchedulesVisibleDateChanged(
                                    date: _selectedDate,
                                  ),
                                );
                              },
                              onPageChanged: (focusedDay) {
                                final clampedFocusedDay =
                                    _clampDay(focusedDay, _firstDay, _lastDay);

                                setState(() {
                                  _selectedDate = clampedFocusedDay;
                                });

                                _monthlySchedulesBloc.add(
                                  MonthlySchedulesVisibleDateChanged(
                                    date: _selectedDate,
                                  ),
                                );

                                _monthlySchedulesBloc.add(
                                  MonthlySchedulesMonthAdded(
                                    date: DateTime(
                                      clampedFocusedDay.year,
                                      clampedFocusedDay.month,
                                      clampedFocusedDay.day,
                                    ),
                                  ),
                                );
                              },
                              calendarBuilders: CalendarBuilders(
                                headerTitleBuilder: (context, date) {
                                  return CenteredCalendarHeader(
                                    focusedMonth: date,
                                    onLeftArrowTap: _onLeftArrowTap,
                                    onRightArrowTap: _onRightArrowTap,
                                    titleTextStyle: calendarTheme
                                        .headerStyle.titleTextStyle,
                                    leftIcon: calendarTheme
                                        .headerStyle.leftChevronIcon,
                                    rightIcon: calendarTheme
                                        .headerStyle.rightChevronIcon,
                                  );
                                },
                                markerBuilder: (context, day, events) {
                                  return selectedDayScheduleMarkerBuilder(
                                    selectedDay: _selectedDate,
                                    day: day,
                                    events: events,
                                  );
                                },
                                selectedBuilder: (context, day, focusedDay) {
                                  return Container(
                                    margin: const EdgeInsets.all(2.0),
                                    alignment: Alignment.center,
                                    decoration:
                                        calendarTheme.selectedDayDecoration,
                                    child: Text(
                                      DateFormat.d(
                                        Localizations.localeOf(context)
                                            .toString(),
                                      ).format(day),
                                      style: calendarTheme.selectedDayTextStyle,
                                    ),
                                  );
                                },
                                todayBuilder: (context, day, focusedDay) =>
                                    Container(
                                  margin: const EdgeInsets.all(2.0),
                                  alignment: Alignment.center,
                                  decoration: calendarTheme.todayDecoration,
                                  child: Text(
                                    DateFormat.d(
                                      Localizations.localeOf(context)
                                          .toString(),
                                    ).format(day),
                                    style: calendarTheme.todayTextStyle,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: detailGap),
                    Expanded(
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: Text(
                                DateFormat.MMMMd(
                                  Localizations.localeOf(context).toString(),
                                ).format(_selectedDate),
                                style: textTheme.headlineExtraSmall,
                                textAlign: TextAlign.start,
                              ),
                            ),
                            SizedBox(height: selectedDateHeadingGap),
                            Expanded(
                              child: BlocBuilder<MonthlySchedulesBloc,
                                  MonthlySchedulesState>(
                                builder: (context, state) {
                                  return _SelectedDateSchedulesContent(
                                    selectedDate: _selectedDate,
                                    state: state,
                                    onAddSchedule: () =>
                                        _openCreateScheduleSheet(context),
                                    onEditSchedule: (scheduleId) =>
                                        _openEditScheduleSheet(
                                      context,
                                      scheduleId: scheduleId,
                                    ),
                                    onDeleteSchedule: (schedule) {
                                      showTwoButtonDeleteDialog(
                                        context,
                                        title: AppLocalizations.of(context)!
                                            .scheduleDeleteConfirmTitle,
                                        description: AppLocalizations.of(
                                                context)!
                                            .scheduleDeleteConfirmDescription,
                                        cancelText:
                                            AppLocalizations.of(context)!
                                                .cancel,
                                        confirmText:
                                            AppLocalizations.of(context)!
                                                .deleteScheduleConfirmAction,
                                      ).then((confirmed) {
                                        if (confirmed != true ||
                                            !context.mounted) {
                                          return;
                                        }
                                        _monthlySchedulesBloc.add(
                                          MonthlySchedulesScheduleDeleted(
                                            schedule: schedule,
                                          ),
                                        );
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedDateSchedulesContent extends StatelessWidget {
  const _SelectedDateSchedulesContent({
    required this.selectedDate,
    required this.state,
    required this.onAddSchedule,
    required this.onEditSchedule,
    required this.onDeleteSchedule,
  });

  final DateTime selectedDate;
  final MonthlySchedulesState state;
  final VoidCallback onAddSchedule;
  final ValueChanged<String> onEditSchedule;
  final ValueChanged<ScheduleEntity> onDeleteSchedule;

  @override
  Widget build(BuildContext context) {
    final schedules = state.schedules[selectedDate] ?? const [];

    if (schedules.isEmpty) {
      if (state.status == MonthlySchedulesStatus.loading) {
        return const Center(child: CircularProgressIndicator());
      }

      if (state.status != MonthlySchedulesStatus.success) {
        return const SizedBox.expand();
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final selected = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
      );

      return _EmptySchedulesView(
        showAddButton: !selected.isBefore(today),
        onAddSchedule: onAddSchedule,
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: schedules.length,
      itemBuilder: (context, index) {
        final schedule = schedules[index];

        return BlocBuilder<ScheduleBloc, ScheduleState>(
          builder: (context, scheduleState) {
            final isEarlyStarted = scheduleState.isEarlyStarted &&
                scheduleState.schedule?.id == schedule.id;

            return ScheduleDetail(
              schedule: schedule,
              preparationTime:
                  state.preparationDurationByScheduleId[schedule.id],
              isEarlyStarted: isEarlyStarted,
              onEdit: () => onEditSchedule(schedule.id),
              onDeleted: () => onDeleteSchedule(schedule),
            );
          },
        );
      },
    );
  }
}

class _EmptySchedulesView extends StatelessWidget {
  const _EmptySchedulesView({
    required this.showAddButton,
    required this.onAddSchedule,
  });

  final bool showAddButton;
  final VoidCallback onAddSchedule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16.0,
          children: [
            Text(
              AppLocalizations.of(context)!.noSchedules,
              style: textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.outlineVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (showAddButton)
              ElevatedButton(
                onPressed: onAddSchedule,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.surface,
                  side: BorderSide(
                    width: 0.5,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 4.0,
                    horizontal: 12.0,
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context)!.addAppointment,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
