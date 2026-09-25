import 'package:on_time_front/core/time/civil_time_resolver.dart';
import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'package:on_time_front/domain/entities/schedule_time_resolution.dart';
import 'package:on_time_front/presentation/shared/time/schedule_zoned_time.dart';
import 'package:flutter/material.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'package:on_time_front/presentation/recurring/recurrence_components.dart';
import 'package:on_time_front/presentation/recurring/recurrence_labels.dart';

class RecurrenceTimeChoiceSheet extends StatefulWidget {
  const RecurrenceTimeChoiceSheet({
    super.key,
    required this.date,
    required this.timeZoneId,
  });
  final DateTime date;
  final String timeZoneId;
  @override
  State<RecurrenceTimeChoiceSheet> createState() =>
      _RecurrenceTimeChoiceSheetState();
}

class _RecurrenceTimeChoiceSheetState extends State<RecurrenceTimeChoiceSheet> {
  RepeatedCivilTime _choice = RepeatedCivilTime.first;
  Widget _candidatePreview(RepeatedCivilTime choice) {
    final candidates = CivilTimeResolver.resolve(
      widget.date,
      widget.timeZoneId,
    );
    final index = choice == RepeatedCivilTime.first ? 0 : 1;
    if (candidates.length <= index) return const SizedBox.shrink();
    return ScheduleZonedTime(
      showInstant: true,
      civil: CivilDateTime.fromFields(widget.date),
      timeZoneId: widget.timeZoneId,
      resolution: ScheduleTimeResolution(
        status: ScheduleTimeResolutionStatus.resolved,
        instantUtc: candidates[index].instantUtc,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => RecurrenceSheet(
    title: recurrenceText(context, '반복 시각 확인', 'Repeated time'),
    action: recurrenceText(context, '적용', 'Apply'),
    onAction: () => Navigator.of(context).pop(_choice),
    children: [
      const SizedBox(height: 24),
      Text(
        recurrenceText(context, '반복 시각 확인', 'Choose the repeated time'),
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      Text(
        recurrenceText(
          context,
          '${widget.timeZoneId}의 ${recurrenceDate(context, widget.date)}은 서머타임 종료로 두 번 발생합니다. 반복에 사용할 시각을 선택해 주세요.',
          '${recurrenceDate(context, widget.date)} occurs twice in ${widget.timeZoneId}. Choose which occurrence to use.',
        ),
      ),
      for (final choice in RepeatedCivilTime.values)
        RecurrenceChoice(
          label: recurrenceText(
            context,
            choice == RepeatedCivilTime.first ? '첫 번째 시각' : '두 번째 시각',
            choice == RepeatedCivilTime.first
                ? 'First occurrence'
                : 'Second occurrence',
          ),
          selected: _choice == choice,
          onTap: () => setState(() => _choice = choice),
          child: _candidatePreview(choice),
        ),
      RecurrencePanel(
        child: Text(
          recurrenceText(
            context,
            '반복되는 모든 날짜에 이 선택이 그대로 적용됩니다. 해당 현지 시각이 존재하지 않는 경우에는 그 회차를 건너뛰며, 총 반복 횟수에서 제외됩니다.',
            'This choice applies to future repeated times. Nonexistent local times are skipped without consuming the count.',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    ],
  );
}

class RecurrenceSaveErrorSheet extends StatelessWidget {
  const RecurrenceSaveErrorSheet({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => RecurrenceSheet(
    title: recurrenceText(context, '저장할 수 없어요', 'Could not save'),
    action: recurrenceText(context, '다시 저장하기', 'Retry saving'),
    onAction: () => Navigator.of(context).pop(true),
    children: [
      const SizedBox(height: 12),
      RecurrencePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(
              recurrenceText(
                context,
                '입력한 내용은 유지되었어요. 조건을 확인하거나 다시 시도해 주세요.',
                'Your input is preserved. Check the conditions or retry.',
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
