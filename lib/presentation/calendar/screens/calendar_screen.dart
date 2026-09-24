import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
import 'package:on_time_front/domain/use-cases/recurring_schedules_use_case.dart';
import 'package:on_time_front/presentation/recurring/recurrence_scope_sheet.dart';
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
import 'package:on_time_front/presentation/shared/components/two_action_dialog.dart';
import 'package:on_time_front/presentation/shared/theme/calendar_theme.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';
import 'package:table_calendar/table_calendar.dart';

typedef CalendarCreateSheetBuilder =
    Widget Function(BuildContext context, DateTime initialDate);

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    this.initialDate,
    this.referenceDate,
    this.createSheetBuilder,
  });

  final DateTime? initialDate;
  final DateTime? referenceDate;
  final CalendarCreateSheetBuilder? createSheetBuilder;

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
      ..add(MonthlySchedulesVisibleDateChanged(date: _selectedDate));
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

  void _retryVisibleMonth() {
    _monthlySchedulesBloc.add(
      MonthlySchedulesSubscriptionRequested(date: _selectedDate),
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
      isDismissible: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          widget.createSheetBuilder?.call(context, _selectedDate) ??
          ScheduleCreateScreen(initialDate: _selectedDate),
    );

    _refreshSchedulesIfSaved(saved);
  }

  Future<void> _openEditScheduleSheet(
    BuildContext context, {
    required ScheduleEntity schedule,
  }) async {
    final scope = schedule.isRecurring
        ? await showRecurrenceScope(context)
        : RecurringEditScope.occurrence;
    if (scope == null || !context.mounted) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          ScheduleEditScreen(scheduleId: schedule.id, scope: scope),
    );

    _refreshSchedulesIfSaved(saved);
  }

  Future<void> _deleteRecurring(
    BuildContext context,
    ScheduleEntity schedule,
  ) async {
    final scope = await showRecurrenceScope(context, deleting: true);
    if (scope == null || !context.mounted) return;
    try {
      await getIt<RecurringSchedulesUseCase>().delete(schedule, scope);
      _refreshSchedulesIfSaved(true);
    } catch (_) {
      if (context.mounted) await _showScheduleDeleteFailureDialog(context);
    }
  }

  Future<void> _showScheduleDeleteFailureDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return showTwoActionDialog(
      context,
      config: TwoActionDialogConfig(
        title: l10n.scheduleDeleteFailedTitle,
        // Do not expose exception implementation details to the user. Local
        // failures share one actionable, translated recovery message.
        description: l10n.scheduleDeleteFailedDescription,
        primaryAction: DialogActionConfig(label: l10n.ok),
      ),
    );
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
    final viewport = MediaQuery.sizeOf(context);
    final sourceLayout =
        viewport.width >= 390 &&
        viewport.height >= 800 &&
        MediaQuery.textScalerOf(context).scale(1) <= 1.3;

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
          backgroundColor: const Color(0xfff2f4f6),
          appBar: AppBar(
            title: Text(AppLocalizations.of(context)!.calendarTitle),
            centerTitle: true,
            backgroundColor: const Color(0xfff2f4f6),
            leadingWidth:
                (Localizations.localeOf(context).languageCode == 'ko'
                    ? 80.0
                    : 88.0) *
                MediaQuery.textScalerOf(context).scale(1),
            leading: TextButton(
              onPressed: _returnHome,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xff4f69df),
                padding: EdgeInsets.zero,
                minimumSize: const Size(80, 44),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 20),
                  const Icon(Icons.chevron_left, size: 20),
                  const SizedBox(width: 2),
                  Text(
                    AppLocalizations.of(context)!.home,
                    style: textTheme.bodyMedium?.copyWith(
                      color: const Color(0xff4f69df),
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 18.0) +
                EdgeInsets.only(top: sourceLayout ? 11 : 0, bottom: 12.0),
            child: BlocListener<MonthlySchedulesBloc, MonthlySchedulesState>(
              listenWhen: (previous, current) =>
                  previous.deleteFailureCount != current.deleteFailureCount,
              listener: (context, state) {
                unawaited(_showScheduleDeleteFailureDialog(context));
              },
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final detailGap = _calendarDetailGap(constraints.maxHeight);
                  final selectedDateHeadingGap = _selectedDateHeadingGap(
                    constraints.maxHeight,
                  );

                  return Column(
                    children: [
                      Container(
                        key: const Key('calendar_card'),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: colorScheme.surface,
                        ),
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(
                                horizontal: _calendarHorizontalPadding,
                              ) +
                              EdgeInsets.only(
                                top: _calendarVerticalPadding,
                                bottom: sourceLayout
                                    ? 52
                                    : _calendarVerticalPadding,
                              ),
                          child: BlocBuilder<MonthlySchedulesBloc, MonthlySchedulesState>(
                            builder: (context, state) {
                              if (state.status ==
                                      MonthlySchedulesStatus.loading ||
                                  state.status ==
                                      MonthlySchedulesStatus.initial ||
                                  state.status ==
                                      MonthlySchedulesStatus.error) {
                                return SizedBox(
                                  height: sourceLayout ? 326 : 288,
                                  child: Center(
                                    child:
                                        state.status ==
                                            MonthlySchedulesStatus.error
                                        ? Transform.translate(
                                            offset: const Offset(0, 8),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  AppLocalizations.of(
                                                    context,
                                                  )!.error,
                                                  style: textTheme.titleLarge
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                                const SizedBox(height: 16),
                                                ElevatedButton(
                                                  key: const Key(
                                                    'calendar_month_retry',
                                                  ),
                                                  onPressed: _retryVisibleMonth,
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(0xff4f69df),
                                                    minimumSize: const Size(
                                                      149,
                                                      44,
                                                    ),
                                                    maximumSize: const Size(
                                                      149,
                                                      44,
                                                    ),
                                                    fixedSize: const Size(
                                                      149,
                                                      44,
                                                    ),
                                                    padding: EdgeInsets.zero,
                                                    tapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    AppLocalizations.of(
                                                      context,
                                                    )!.retry,
                                                    style: textTheme.bodyLarge
                                                        ?.copyWith(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : Transform.translate(
                                            offset: const Offset(0, 8),
                                            child: const SizedBox(
                                              key: Key(
                                                'calendar_month_spinner',
                                              ),
                                              width: 28,
                                              height: 28,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 3,
                                                color: Color(0xff4f69df),
                                              ),
                                            ),
                                          ),
                                  ),
                                );
                              }

                              return TableCalendar(
                                locale: Localizations.localeOf(
                                  context,
                                ).toString(),
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
                                      selectedDay,
                                      _firstDay,
                                      _lastDay,
                                    );
                                  });
                                  _monthlySchedulesBloc.add(
                                    MonthlySchedulesVisibleDateChanged(
                                      date: _selectedDate,
                                    ),
                                  );
                                },
                                onPageChanged: (focusedDay) {
                                  final clampedFocusedDay = _clampDay(
                                    focusedDay,
                                    _firstDay,
                                    _lastDay,
                                  );

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
                                    return Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: sourceLayout ? 15 : 0,
                                      ),
                                      child: CenteredCalendarHeader(
                                        focusedMonth: date,
                                        onLeftArrowTap: _onLeftArrowTap,
                                        onRightArrowTap: _onRightArrowTap,
                                        titleTextStyle: calendarTheme
                                            .headerStyle
                                            .titleTextStyle,
                                        leftIcon: calendarTheme
                                            .headerStyle
                                            .leftChevronIcon,
                                        rightIcon: calendarTheme
                                            .headerStyle
                                            .rightChevronIcon,
                                      ),
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
                                          Localizations.localeOf(
                                            context,
                                          ).toString(),
                                        ).format(day),
                                        style:
                                            calendarTheme.selectedDayTextStyle,
                                      ),
                                    );
                                  },
                                  todayBuilder: (context, day, focusedDay) =>
                                      Container(
                                        margin: const EdgeInsets.all(2.0),
                                        alignment: Alignment.center,
                                        decoration:
                                            calendarTheme.todayDecoration,
                                        child: Text(
                                          DateFormat.d(
                                            Localizations.localeOf(
                                              context,
                                            ).toString(),
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
                                child:
                                    BlocBuilder<
                                      MonthlySchedulesBloc,
                                      MonthlySchedulesState
                                    >(
                                      builder: (context, state) {
                                        return _SelectedDateSchedulesContent(
                                          selectedDate: _selectedDate,
                                          referenceDate: widget.referenceDate,
                                          sourceLayout: sourceLayout,
                                          state: state,
                                          onAddSchedule: () =>
                                              _openCreateScheduleSheet(context),
                                          onEditSchedule: (schedule) =>
                                              _openEditScheduleSheet(
                                                context,
                                                schedule: schedule,
                                              ),
                                          onDeleteSchedule: (schedule) {
                                            if (schedule.isRecurring) {
                                              _deleteRecurring(
                                                context,
                                                schedule,
                                              );
                                              return;
                                            }
                                            showTwoButtonDeleteDialog(
                                              context,
                                              title: AppLocalizations.of(
                                                context,
                                              )!.scheduleDeleteConfirmTitle,
                                              description: AppLocalizations.of(
                                                context,
                                              )!.scheduleDeleteConfirmDescription,
                                              cancelText: AppLocalizations.of(
                                                context,
                                              )!.cancel,
                                              confirmText: AppLocalizations.of(
                                                context,
                                              )!.deleteScheduleConfirmAction,
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
      ),
    );
  }
}

class _SelectedDateSchedulesContent extends StatelessWidget {
  const _SelectedDateSchedulesContent({
    required this.selectedDate,
    required this.referenceDate,
    required this.sourceLayout,
    required this.state,
    required this.onAddSchedule,
    required this.onEditSchedule,
    required this.onDeleteSchedule,
  });

  final DateTime selectedDate;
  final DateTime? referenceDate;
  final bool sourceLayout;
  final MonthlySchedulesState state;
  final VoidCallback onAddSchedule;
  final ValueChanged<ScheduleEntity> onEditSchedule;
  final ValueChanged<ScheduleEntity> onDeleteSchedule;

  @override
  Widget build(BuildContext context) {
    final schedules = state.schedules[selectedDate] ?? const [];

    if (schedules.isEmpty) {
      if (state.status == MonthlySchedulesStatus.loading) {
        return sourceLayout
            ? const SizedBox.expand()
            : const Center(child: CircularProgressIndicator());
      }

      if (state.status != MonthlySchedulesStatus.success) {
        return const SizedBox.expand();
      }

      final now = referenceDate ?? DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final selected = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
      );

      return _EmptySchedulesView(
        sourceLayout: sourceLayout,
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
            final isEarlyStarted =
                scheduleState.isEarlyStarted &&
                scheduleState.schedule?.id == schedule.id;

            return ScheduleDetail(
              schedule: schedule,
              preparationTime:
                  state.preparationDurationByScheduleId[schedule.id],
              isEarlyStarted: isEarlyStarted,
              onEdit: () => onEditSchedule(schedule),
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
    required this.sourceLayout,
    required this.showAddButton,
    required this.onAddSchedule,
  });

  final bool sourceLayout;
  final bool showAddButton;
  final VoidCallback onAddSchedule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Align(
      alignment: sourceLayout ? Alignment.topCenter : Alignment.center,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, sourceLayout ? 32 : 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: sourceLayout ? 33 : 16,
          children: [
            Text(
              AppLocalizations.of(context)!.noSchedules,
              style: textTheme.titleMedium?.copyWith(
                color: sourceLayout
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.outlineVariant,
                fontWeight: sourceLayout ? FontWeight.w700 : null,
              ),
              textAlign: TextAlign.center,
            ),
            if (showAddButton)
              ElevatedButton(
                onPressed: onAddSchedule,
                style: ElevatedButton.styleFrom(
                  backgroundColor: sourceLayout
                      ? const Color(0xff4f69df)
                      : theme.colorScheme.surface,
                  minimumSize: sourceLayout ? const Size(149, 44) : null,
                  side: sourceLayout
                      ? BorderSide.none
                      : BorderSide(
                          width: 0.5,
                          color: theme.colorScheme.outlineVariant,
                        ),
                  padding: sourceLayout
                      ? const EdgeInsets.symmetric(horizontal: 16)
                      : const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context)!.addAppointment,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      (sourceLayout
                              ? textTheme.bodyLarge
                              : textTheme.bodyMedium)
                          ?.copyWith(
                            color: sourceLayout
                                ? Colors.white
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: sourceLayout ? FontWeight.w600 : null,
                          ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
