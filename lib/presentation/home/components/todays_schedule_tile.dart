import 'package:flutter/material.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/presentation/shared/constants/app_colors.dart';

class TodaysScheduleTile extends StatelessWidget {
  const TodaysScheduleTile({super.key, this.schedule});

  final ScheduleEntity? schedule;
  Widget noSchedule(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      '약속이 없는 날이에요',
      style: theme.textTheme.bodyLarge?.copyWith(
        color: theme.colorScheme.outlineVariant,
      ),
    );
  }

  Widget scheduleExists(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${schedule!.scheduleTime.hour > 12 ? '오후' : '오전'} ${schedule!.scheduleTime.hour % 12}시 ${schedule!.scheduleTime.minute}분',
          style: TextStyle(color: AppColors.white),
        ),
        Text(
          schedule!.scheduleName,
          style: TextStyle(color: AppColors.white),
        ),
        SizedBox(height: 8.0),
        // - 시간 - 분 전
        Text(
          '${schedule!.scheduleTime.difference(DateTime.now()).inHours}시간 ${schedule!.scheduleTime.difference(DateTime.now()).inMinutes % 60}분 전',
          style: TextStyle(color: AppColors.white),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: schedule == null
            ? theme.colorScheme.surfaceContainerLow
            : theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(11),
      ),
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11.0, vertical: 16.0),
        child: schedule == null ? noSchedule(context) : scheduleExists(context),
      ),
    );
  }
}
