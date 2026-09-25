import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/presentation/recurring/recurrence_components.dart';
import 'package:on_time_front/presentation/recurring/recurrence_labels.dart';

class RecurrenceOccurrenceSheet extends StatelessWidget {
  const RecurrenceOccurrenceSheet({
    super.key,
    required this.schedule,
    this.onEdit,
    this.onDelete,
    this.now,
  });
  final ScheduleEntity schedule;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final DateTime Function()? now;
  @override
  Widget build(BuildContext context) {
    final unrecorded =
        !schedule.isStarted &&
        schedule.doneStatus == ScheduleDoneStatus.notEnded &&
        schedule.occurrenceInstantUtc.isBefore(
          (now?.call() ?? DateTime.now()).toUtc(),
        );
    return RecurrenceSheet(
      title: schedule.scheduleName,
      footer: ScreenActions(
        action: recurrenceText(context, '뒤로', 'Back'),
        onAction: () => Navigator.of(context).pop(),
      ),
      spacing: 0,
      contentPadding: const EdgeInsets.fromLTRB(17, 22, 17, 16),
      children: [
        RecurrencePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                recurrenceText(context, '이번 회차', 'This occurrence'),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 3),
              Text(
                DateFormat(
                  recurrenceText(
                    context,
                    schedule.scheduleTime.minute == 0
                        ? 'M/d EEEE H시'
                        : 'M/d EEEE H시 mm분',
                    'MMM d EEEE HH:mm',
                  ),
                  Localizations.localeOf(context).toString(),
                ).format(schedule.scheduleTime),
                style: const TextStyle(
                  fontSize: 23,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (schedule.recurringOverrides.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  recurrenceText(
                    context,
                    '이 회차는 개별 수정되었습니다.',
                    'This occurrence has individual changes.',
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xff545454),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Row(
            children: [
              Text(
                recurrenceText(context, '진행 기록', 'Preparation record'),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  unrecorded
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
                      : recurrenceText(
                          context,
                          '예정된 일정입니다.',
                          'Upcoming occurrence.',
                        ),
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xff545454),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        if (unrecorded) ...[
          const SizedBox(height: 16),
          RecurrenceNotice(
            highlighted: true,
            glyph: 'i',
            asset: 'recurrence_review_ellipse.svg',
            child: Text(
              recurrenceText(
                context,
                '이 회차는 별도 출근 진행 기록을 남기지 않습니다. 따라서 완료, 지각 결과 및 점수가 자동으로 생성되지 않습니다.',
                'No completion, late result, or score is generated automatically for an unrecorded occurrence.',
              ),
              style: const TextStyle(fontSize: 13, height: 1.6),
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (onEdit != null)
          _action(
            context,
            recurrenceText(context, '수정하기', 'Edit occurrence'),
            onEdit!,
          ),
        if (onDelete != null) ...[
          const SizedBox(height: 8),
          _action(
            context,
            recurrenceText(context, '이 회차 삭제하기', 'Delete occurrence'),
            onDelete!,
          ),
        ],
      ],
    );
  }

  Widget _action(BuildContext context, String label, VoidCallback callback) =>
      Material(
        color: const Color(0xfff6f6f6),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            Navigator.of(context).pop();
            callback();
          },
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Expanded(
                  child: Text(label, style: const TextStyle(fontSize: 16)),
                ),
                SvgPicture.asset(
                  'recurrence_occurrence_frame.svg',
                  package: 'assets',
                ),
              ],
            ),
          ),
        ),
      );
}
