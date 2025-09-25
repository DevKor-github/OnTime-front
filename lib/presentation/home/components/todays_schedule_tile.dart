import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/presentation/home/bloc/schedule_timer_bloc.dart';

class TodaysScheduleTile extends StatelessWidget {
  const TodaysScheduleTile({super.key, this.schedule, this.onTap});

  final ScheduleEntity? schedule;
  final VoidCallback? onTap;

  Widget _noSchedule(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11.0, vertical: 16.0),
      child: Text(
        AppLocalizations.of(context)!.noAppointments,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
    );
  }

  Widget _scheduleExists(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _ScheduleLeftTimeColumn(
              scheduleTime: schedule!.scheduleTime,
            ),
          ),
          VerticalDivider(
            width: 1,
            color: colorScheme.primary,
          ),
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 21.0, vertical: 11.0),
              child: _ScheduleDetailsColumn(
                schedule: schedule!,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: schedule == null ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          color: schedule == null
              ? theme.colorScheme.surfaceContainerLow
              : theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        width: double.infinity,
        child:
            schedule == null ? _noSchedule(context) : _scheduleExists(context),
      ),
    );
  }
}

class _ScheduleDetailsColumn extends StatelessWidget {
  const _ScheduleDetailsColumn({required this.schedule});

  final ScheduleEntity schedule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final formattedTime = DateFormat.jm(
      AppLocalizations.of(context)!.localeName,
    ).format(schedule.scheduleTime);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          schedule.scheduleName,
          style: textTheme.titleLarge?.copyWith(color: colorScheme.primary),
        ),
        //time PM H:MM
        Text(
          formattedTime,
          style: textTheme.bodySmall?.copyWith(color: colorScheme.primary),
        ),
      ],
    );
  }
}

class _ScheduleLeftTimeColumn extends StatelessWidget {
  const _ScheduleLeftTimeColumn({required this.scheduleTime});

  final DateTime scheduleTime;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          ScheduleTimerBloc()..add(ScheduleTimerStarted(scheduleTime)),
      child: BlocBuilder<ScheduleTimerBloc, ScheduleTimerState>(
        builder: (context, state) {
          Duration leftTime;

          if (state is ScheduleTimerRunning) {
            leftTime = state.remainingDuration;
          } else if (state is ScheduleTimerFinished) {
            leftTime = Duration.zero;
          } else {
            // Initial state - calculate immediately
            leftTime = scheduleTime.difference(DateTime.now());
          }

          final hours = leftTime.inHours;
          final minutes = leftTime.inMinutes % 60;

          return _TimeColumn(
            hour: hours,
            minute: minutes,
          );
        },
      ),
    );
  }
}

class _TimeColumn extends StatelessWidget {
  const _TimeColumn({
    required this.hour,
    required this.minute,
  });

  final int hour;
  final int minute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          AppLocalizations.of(context)!.untilAppointment,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.primary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
          style: theme.textTheme.titleSmall?.copyWith(
            color: colorScheme.primary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
