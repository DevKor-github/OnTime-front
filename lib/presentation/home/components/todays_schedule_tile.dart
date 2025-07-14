import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/shared/constants/app_colors.dart';

class TodaysScheduleTile extends StatelessWidget {
  const TodaysScheduleTile({super.key, this.schedule});

  final ScheduleEntity? schedule;

  Widget _noSchedule(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
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
    return Container(
      decoration: BoxDecoration(
        color: schedule == null
            ? theme.colorScheme.surfaceContainerLow
            : theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.5),
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
    final leftTime = scheduleTime.difference(DateTime.now());
    //약속까지 hh:mm
    final hours = leftTime.inHours;
    final minutes = leftTime.inMinutes % 60;

    return _TimeColumn(
      hour: hours,
      minute: minutes,
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
