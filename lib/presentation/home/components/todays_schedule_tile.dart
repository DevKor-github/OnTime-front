import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/shared/constants/app_colors.dart';

class TodaysScheduleTile extends StatelessWidget {
  const TodaysScheduleTile({
    super.key,
    this.schedule,
  });

  final ScheduleEntity? schedule;

  @override
  Widget build(BuildContext context) {
    if (schedule == null) {
      return Text(AppLocalizations.of(context)!.noAppointments);
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 24,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Time(schedule: schedule!),
              SvgPicture.asset(
                'assets/arrow_right.svg',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Location(schedule: schedule!),
        ],
      ),
    );
  }
}

class _Time extends StatelessWidget {
  const _Time({
    required this.schedule,
  });

  final ScheduleEntity schedule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      DateFormat.jm(Localizations.localeOf(context).toString())
          .format(schedule.scheduleTime),
      style: theme.textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _Location extends StatelessWidget {
  const _Location({
    required this.schedule,
  });

  final ScheduleEntity schedule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SvgPicture.asset(
          'assets/location.svg',
        ),
        const SizedBox(width: 8),
        Text(
          schedule.place.placeName,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}
