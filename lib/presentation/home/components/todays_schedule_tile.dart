import 'package:on_time_front/presentation/shared/time/schedule_zoned_time.dart';
import 'package:on_time_front/core/time/schedule_time_resolution.dart';
import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'package:flutter/material.dart';
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
    this.resolution,
    this.emptyLabel,
  });

  final ScheduleEntity? schedule;
  final VoidCallback? onTap;
  final bool compact;
  final ScheduleTimeResolution? resolution;
  final String? emptyLabel;

  Widget _noSchedule(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10.0 : 11.0,
        vertical: compact ? 10.0 : 16.0,
      ),
      child: Text(
        emptyLabel ?? AppLocalizations.of(context)!.noAppointments,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.outlineVariant,
          height: 22 / 16,
        ),
      ),
    );
  }

  Widget _scheduleExists(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final resolution =
        this.resolution ??
        ScheduleTimeResolver.resolve(schedule!, nowUtc: DateTime.now());

    final countdown = Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 10.0 : 16.0),
      child: resolution.instantUtc == null
          ? const Icon(Icons.schedule_outlined)
          : _ScheduleLeftTimeColumn(
              key: ValueKey(resolution.instantUtc),
              scheduleTime: resolution.instantUtc!,
              compact: compact,
            ),
    );
    final details = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12.0 : 21.0,
        vertical: compact ? 8.0 : 11.0,
      ),
      child: _ScheduleDetailsColumn(
        schedule: schedule!,
        resolution: resolution,
        compact: compact,
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 400 ||
            MediaQuery.textScalerOf(context).scale(16) > 20;
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(padding: const EdgeInsets.only(top: 8), child: countdown),
              Divider(height: 16, color: colorScheme.primary),
              details,
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              countdown,
              VerticalDivider(width: 1, color: colorScheme.primary),
              Expanded(child: details),
            ],
          ),
        );
      },
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
        child: schedule == null
            ? _noSchedule(context)
            : _scheduleExists(context),
      ),
    );
  }
}

class _ScheduleDetailsColumn extends StatelessWidget {
  const _ScheduleDetailsColumn({
    required this.schedule,
    required this.resolution,
    required this.compact,
  });

  final ScheduleEntity schedule;
  final ScheduleTimeResolution resolution;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
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

        ScheduleZonedTime(
          civil: CivilDateTime.fromFields(schedule.scheduleTime),
          timeZoneId: schedule.timeZoneId,
          resolution: resolution,
          style: textTheme.bodySmall?.copyWith(color: colorScheme.primary),
        ),
      ],
    );
  }
}

class _ScheduleLeftTimeColumn extends StatelessWidget {
  const _ScheduleLeftTimeColumn({
    super.key,
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

          return _TimeColumn(hour: hours, minute: minutes, compact: compact);
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
                  ?.copyWith(color: colorScheme.primary),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: compact ? 2 : 4),
        Text(
          '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
          style:
              (compact
                      ? theme.textTheme.labelLarge
                      : theme.textTheme.titleSmall)
                  ?.copyWith(color: colorScheme.primary),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
