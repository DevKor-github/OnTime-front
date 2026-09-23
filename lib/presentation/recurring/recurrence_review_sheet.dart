import 'package:flutter/material.dart';
import 'package:on_time_front/core/time/civil_time_resolver.dart';
import 'package:on_time_front/domain/recurrence/recurrence_engine.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
import 'package:on_time_front/presentation/recurring/recurrence_components.dart';
import 'package:on_time_front/presentation/recurring/recurrence_labels.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form_bloc.dart';
import 'package:on_time_front/presentation/shared/components/modal_wide_button.dart';

class RecurrenceReviewSheet extends StatefulWidget {
  const RecurrenceReviewSheet({
    super.key,
    required this.review,
    required this.form,
  });
  final RecurrenceReview review;
  final ScheduleFormState form;
  @override
  State<RecurrenceReviewSheet> createState() => _RecurrenceReviewSheetState();
}

class _RecurrenceReviewSheetState extends State<RecurrenceReviewSheet> {
  final _excluded = <String>{};
  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    final form = widget.form;
    final byKey = <String, List<RecurrenceConflict>>{};
    for (final conflict in review.conflicts) {
      (byKey[conflict.slot.key] ??= []).add(conflict);
      if (conflict.otherSlotKey != null) {
        (byKey[conflict.otherSlotKey!] ??= []).add(conflict);
      }
    }
    final remaining = review.slots.where((s) => !_excluded.contains(s.key));
    final canExclude = form.recurrenceRule != null;
    final canSave =
        !review.persistentConflict &&
        review.conflicts.every(
          (c) =>
              _excluded.contains(c.slot.key) ||
              _excluded.contains(c.otherSlotKey),
        ) &&
        (remaining.isNotEmpty || review.detached.isNotEmpty);
    return RecurrenceSheet(
      title: recurrenceText(context, '반복 일정 확인', 'Review recurrence'),
      action: recurrenceText(context, '저장', 'Save'),
      onAction: canSave
          ? () => Navigator.of(context).pop(Set<String>.from(_excluded))
          : null,
      children: [
        Text(
          form.scheduleName ?? '',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (form.recurrenceRule != null)
          RecurrenceValue(
            label: recurrenceText(context, '반복', 'Repeat'),
            value: recurrenceLabel(context, form.recurrenceRule!),
          ),
        if (review.totalOccurrences != null)
          Text(
            recurrenceText(
              context,
              '반복 ${review.totalOccurrences! - _excluded.length}회'
                  '${review.detached.isEmpty ? '' : ' + 독립 일정 ${review.detached.length}회'}',
              '${review.totalOccurrences! - _excluded.length} recurring occurrences'
                  '${review.detached.isEmpty ? '' : ' + ${review.detached.length} standalone schedules'}',
            ),
          ),
        if (remaining.isNotEmpty)
          Text(
            '${recurrenceText(context, '첫 일정', 'First occurrence')} · ${recurrenceDate(context, _time(remaining.first))}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        if (remaining.isNotEmpty)
          RecurrenceValue(
            label: recurrenceText(context, '예정된 일정', 'Upcoming occurrences'),
            value: remaining
                .take(3)
                .map((s) => recurrenceDate(context, _time(s)))
                .join('\n'),
          ),
        if (remaining.isNotEmpty &&
            review.occurrences[remaining.first.key] != null)
          Text(
            '${recurrenceText(context, '준비 시작', 'Preparation starts')} · ${recurrenceDate(context, CivilTimeResolver.civilTimeAt(review.occurrences[remaining.first.key]!.preparationStartUtc, review.occurrences[remaining.first.key]!.schedule.timeZoneId))}',
          ),
        Text(
          recurrenceText(
            context,
            '준비 ${form.totalPreparationTime.inMinutes}분 + 이동 ${form.moveTime?.inMinutes ?? 0}분 + 여유 ${form.scheduleSpareTime?.inMinutes ?? 0}분',
            'Preparation ${form.totalPreparationTime.inMinutes} min + travel ${form.moveTime?.inMinutes ?? 0} min + buffer ${form.scheduleSpareTime?.inMinutes ?? 0} min',
          ),
        ),
        if (review.persistentConflict) ...[
          Text(
            recurrenceText(
              context,
              '반복 시간이나 요일이 계속 겹쳐요. 반복 설정을 조정해 주세요.',
              'These recurring rules keep overlapping. Change the time or repeat pattern.',
            ),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          ModalWideButton(
            text: recurrenceText(context, '설정 바꾸기', 'Change settings'),
            variant: ModalWideButtonVariant.primary,
            layout: ModalWideButtonLayout.full,
            height: 52,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ] else if (byKey.isNotEmpty) ...[
          Text(
            recurrenceText(
              context,
              canExclude
                  ? '겹치는 회차를 확인하고 제외할 일정을 직접 선택해 주세요.'
                  : '다른 일정과 겹쳐요. 시간이나 준비과정을 조정해 주세요.',
              canExclude
                  ? 'Select the conflicting occurrences to exclude.'
                  : 'This overlaps another schedule. Adjust the time or preparation.',
            ),
          ),
          for (final entry in byKey.entries)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _excluded.contains(entry.key),
              onChanged: canExclude
                  ? (v) => setState(
                      () => v == true
                          ? _excluded.add(entry.key)
                          : _excluded.remove(entry.key),
                    )
                  : null,
              title: Text(
                recurrenceDate(
                  context,
                  review.occurrences[entry.key]?.schedule.scheduleTime ??
                      DateTime.parse(entry.key),
                ),
              ),
              subtitle: Text(
                entry.value
                    .map((c) => c.other.scheduleName)
                    .toSet()
                    .join(' · '),
              ),
            ),
          if (canExclude)
            Text(
              recurrenceText(
                context,
                '제외한 회차는 총횟수에서 차감되며 다른 날짜로 채우지 않아요.',
                'Excluded occurrences consume the count and are not replaced.',
              ),
            ),
        ],
        if (review.detached.isNotEmpty) ...[
          Text(
            recurrenceText(
              context,
              '개별 수정한 일정은 독립 일정으로 유지해요.',
              'Individually edited occurrences remain as standalone schedules.',
            ),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (final value in review.detached)
            Text(
              '${value.scheduleName}\n${recurrenceDate(context, value.scheduleTime)}',
            ),
          Text(
            recurrenceText(
              context,
              '분리되는 일정도 남은 횟수에 포함돼요. 현재 시간과 준비과정을 유지합니다.',
              'Detached schedules count toward the remaining total and keep their time and preparation.',
            ),
          ),
        ],
        if (review.skipped.isNotEmpty) ...[
          Text(
            recurrenceText(context, '건너뛴 날짜', 'Skipped dates'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (final skip in review.skipped.take(5)) Text(_skip(context, skip)),
          if (review.skipped.length > 5)
            TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (context) => SizedBox(
                  height: MediaQuery.sizeOf(context).height * .8,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: review.skipped.length,
                    itemBuilder: (context, i) => ListTile(
                      title: Text(_skip(context, review.skipped[i])),
                    ),
                  ),
                ),
              ),
              child: Text(
                recurrenceText(
                  context,
                  '건너뛴 날짜 ${review.skipped.length}개 모두 보기',
                  'View all ${review.skipped.length} skipped dates',
                ),
              ),
            ),
        ],
      ],
    );
  }

  DateTime _time(RecurrenceSlot slot) =>
      widget.review.occurrences[slot.key]?.schedule.scheduleTime ??
      slot.civilTime;

  String _skip(BuildContext context, RecurrenceSkip skip) =>
      '${recurrenceDate(context, skip.date)} · ${switch (skip.reason) {
        RecurrenceSkipReason.nonexistentDate => recurrenceText(context, '해당 월에 없는 날짜/요일', 'Date or weekday missing in this month'),
        RecurrenceSkipReason.nonexistentTime => recurrenceText(context, '일광절약시간 변경으로 없는 시각', 'Time does not exist due to daylight saving'),
        RecurrenceSkipReason.preparationPassed => recurrenceText(context, '준비 시작 시각이 지남', 'Preparation start has passed'),
      }}';
}
