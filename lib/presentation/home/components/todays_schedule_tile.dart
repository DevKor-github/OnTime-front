import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/presentation/home/bloc/schedule_timer_bloc.dart';

class TodaysScheduleTile extends StatelessWidget {
  const TodaysScheduleTile({
    super.key,
    this.schedule,
    this.onTap,
    this.compact = false,
  });

  final ScheduleEntity? schedule;
  final VoidCallback? onTap;
  final bool compact;

  Widget _noSchedule(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10.0 : 11.0,
        vertical: compact ? 10.0 : 16.0,
      ),
      child: Text(
        AppLocalizations.of(context)!.noAppointments,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.outlineVariant,
          height: 22 / 16,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
            padding: EdgeInsets.symmetric(horizontal: compact ? 10.0 : 16.0),
            child: _ScheduleLeftTimeColumn(
              scheduleTime: schedule!.scheduleTime,
              compact: compact,
            ),
          ),
          VerticalDivider(
            width: 1,
            color: colorScheme.primary,
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 12.0 : 21.0,
                vertical: compact ? 8.0 : 11.0,
              ),
              child: _ScheduleDetailsColumn(
                schedule: schedule!,
                compact: compact,
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
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: schedule == null
              ? theme.colorScheme.surfaceContainerLow
              : theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        width: double.infinity,
        constraints: BoxConstraints(minHeight: compact ? 48 : 54),
        alignment: schedule == null ? Alignment.centerLeft : null,
        child:
            schedule == null ? _noSchedule(context) : _scheduleExists(context),
      ),
    );
  }
}

class _ScheduleDetailsColumn extends StatelessWidget {
  const _ScheduleDetailsColumn({
    required this.schedule,
    required this.compact,
  });

  final ScheduleEntity schedule;
  final bool compact;

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
          style: (compact ? textTheme.titleMedium : textTheme.titleLarge)
              ?.copyWith(color: colorScheme.primary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        //time PM H:MM
        Text(
          formattedTime,
          style: textTheme.bodySmall?.copyWith(color: colorScheme.primary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ScheduleLeftTimeColumn extends StatelessWidget {
  const _ScheduleLeftTimeColumn({
    required this.scheduleTime,
    required this.compact,
  });

  final DateTime scheduleTime;
  final bool compact;

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
            compact: compact,
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
    required this.compact,
  });

  final int hour;
  final int minute;
  final bool compact;

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
          style:
              (compact ? theme.textTheme.labelSmall : theme.textTheme.bodySmall)
                  ?.copyWith(
            color: colorScheme.primary,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: compact ? 2 : 4),
        Text(
          '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
          style: (compact
                  ? theme.textTheme.labelLarge
                  : theme.textTheme.titleSmall)
              ?.copyWith(
            color: colorScheme.primary,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
