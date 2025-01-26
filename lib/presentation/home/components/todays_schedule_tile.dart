import 'package:flutter/material.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';

class TodaysScheduleTile extends StatelessWidget {
  const TodaysScheduleTile({super.key, this.schedule});

  final ScheduleEntity? schedule;
  Widget noSchedule(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(11),
      ),
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11.0, vertical: 16.0),
        child: Text(
          '약속이 없는 날이에요',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.outlineVariant,
          ),
        ),
      ),
    );
  }

  Widget scheduleExists(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(11),
      ),
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              schedule!.scheduleName,
              style: theme.textTheme.bodyLarge,
            ),
            SizedBox(height: 8.0),
            Text(
              schedule!.place.placeName,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return schedule == null ? noSchedule(context) : scheduleExists(context);
  }
}
