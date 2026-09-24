import 'package:flutter/material.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/presentation/recurring/recurrence_components.dart';
import 'package:on_time_front/presentation/recurring/recurrence_labels.dart';

class RecurrenceOccurrenceSheet extends StatelessWidget {
  const RecurrenceOccurrenceSheet({
    super.key,
    required this.schedule,
    this.onEdit,
    this.onDelete,
  });
  final ScheduleEntity schedule;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) {
    final unrecorded =
        !schedule.isStarted &&
        schedule.doneStatus == ScheduleDoneStatus.notEnded &&
        schedule.occurrenceInstantUtc.isBefore(DateTime.now().toUtc());
    return RecurrenceSheet(
      title: schedule.scheduleName,
      footer: ScreenActions(
        action: recurrenceText(context, '뒤로', 'Back'),
        onAction: () => Navigator.of(context).pop(),
      ),
      children: [
        RecurrencePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(recurrenceText(context, '이번 회차', 'This occurrence')),
              const SizedBox(height: 8),
              Text(
                recurrenceDate(context, schedule.scheduleTime),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (schedule.recurringOverrides.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    recurrenceText(
                      context,
                      '이 회차는 개별 수정되었습니다.',
                      'This occurrence has individual changes.',
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 24),
        RecurrenceValue(
          label: recurrenceText(context, '진행 기록', 'Preparation record'),
          value: unrecorded
              ? recurrenceText(
                  context,
                  '진행 기록이 없습니다.',
                  'No preparation recorded.',
                )
              : schedule.isStarted
              ? recurrenceText(
                  context,
                  '준비 진행 기록이 있습니다.',
                  'Preparation has been recorded.',
                )
              : recurrenceText(context, '예정된 일정입니다.', 'Upcoming occurrence.'),
        ),
        if (unrecorded)
          RecurrencePanel(
            highlighted: true,
            child: Text(
              recurrenceText(
                context,
                '이 회차는 별도 출근 진행 기록을 남기지 않습니다. 따라서 완료, 지각 결과 및 점수가 자동으로 생성되지 않습니다.',
                'No completion, late result, or score is generated automatically for an unrecorded occurrence.',
              ),
            ),
          ),
        if (onEdit != null)
          RecurrenceValue(
            label: recurrenceText(context, '일정 수정', 'Edit'),
            value: recurrenceText(context, '수정하기', 'Edit occurrence'),
            onTap: () {
              Navigator.of(context).pop();
              onEdit!();
            },
          ),
        if (onDelete != null)
          RecurrenceValue(
            label: recurrenceText(context, '일정 삭제', 'Delete'),
            value: recurrenceText(context, '이 회차 삭제하기', 'Delete occurrence'),
            onTap: () {
              Navigator.of(context).pop();
              onDelete!();
            },
          ),
      ],
    );
  }
}
