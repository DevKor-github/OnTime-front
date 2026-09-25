import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:on_time_front/core/time/civil_time_resolver.dart';
import 'package:on_time_front/domain/recurrence/recurrence_engine.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
import 'package:on_time_front/presentation/recurring/recurrence_components.dart';
import 'package:on_time_front/presentation/recurring/recurrence_labels.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form_bloc.dart';

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
    final title = review.persistentConflict
        ? recurrenceText(context, '반복 시간 조정', 'Adjust recurrence')
        : byKey.isNotEmpty
        ? recurrenceText(context, '겹치는 일정 확인', 'Conflicting occurrences')
        : review.detached.isNotEmpty
        ? recurrenceText(context, '변경 내용 확인', 'Review changes')
        : recurrenceText(context, '반복 일정 확인', 'Review recurrence');
    return RecurrenceSheet(
      title: title,
      spacing: 12,
      contentPadding: EdgeInsets.fromLTRB(
        16,
        review.conflicts.isEmpty && review.detached.isEmpty ? 0 : 15,
        16,
        16,
      ),
      action: review.persistentConflict
          ? recurrenceText(context, '반복 설정 수정', 'Change settings')
          : recurrenceText(
              context,
              review.detached.isNotEmpty
                  ? '단독 일정으로 남기고 저장'
                  : byKey.isNotEmpty
                  ? '저장하기 (${remaining.length}개)'
                  : '저장하기',
              'Save',
            ),
      onAction: review.persistentConflict
          ? () => Navigator.of(context).pop()
          : canSave
          ? () => Navigator.of(context).pop(Set<String>.from(_excluded))
          : null,
      children: [
        if (review.persistentConflict)
          ..._persistent(form, review)
        else if (byKey.isNotEmpty)
          ..._conflicts(form, review, byKey, remaining.length, canExclude)
        else if (review.detached.isNotEmpty)
          ..._detached(review)
        else
          ..._summary(form, review, remaining.toList()),
        if (review.totalOccurrences != null && review.conflicts.isEmpty)
          Text(
            recurrenceText(
              context,
              '반복 ${review.totalOccurrences! - _excluded.length}회${review.detached.isEmpty ? '' : ' + 독립 일정 ${review.detached.length}회'}',
              '${review.totalOccurrences! - _excluded.length} recurring occurrences',
            ),
            style: const TextStyle(fontSize: 12),
          ),
        if (review.skipped.isNotEmpty) ...[
          RecurrenceNotice(
            asset: 'recurrence_review_ellipse.svg',
            glyph: 'i',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recurrenceText(context, '건너뛴 날짜', 'Skipped dates'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                for (final skip in review.skipped.take(5))
                  Text(
                    _skip(context, skip),
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: Color(0xff545454),
                    ),
                  ),
              ],
            ),
          ),
          if (review.skipped.length > 5)
            TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (context) => SizedBox(
                  height: MediaQuery.sizeOf(context).height * .9,
                  child: RecurrenceSheet(
                    title: recurrenceText(context, '건너뛴 날짜', 'Skipped dates'),
                    children: [
                      for (final skip in review.skipped)
                        Text(_skip(context, skip)),
                    ],
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

  String _clock(DateTime time) =>
      DateFormat.jm(Localizations.localeOf(context).toString()).format(time);
  String _day(DateTime time) => DateFormat(
    recurrenceText(context, 'M월 d일 (E)', 'MMM d (E)'),
    Localizations.localeOf(context).toString(),
  ).format(time);

  List<Widget> _persistent(ScheduleFormState form, RecurrenceReview review) => [
    RecurrencePanel(
      highlighted: true,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recurrenceText(
              context,
              '반복 일정이 계속 겹쳐요',
              'These recurring rules keep overlapping',
            ),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xff4f69df),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            recurrenceText(
              context,
              '시간이나 요일을 수정해야 저장할 수 있어요.',
              'Change the time or repeat pattern before saving.',
            ),
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    ),
    const SizedBox(height: 4),
    Text(
      recurrenceText(context, '반복 요일', 'Repeat pattern'),
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    ),
    if (form.recurrenceRule != null)
      Wrap(
        spacing: 7,
        runSpacing: 8,
        children: [
          for (var day = 1; day <= 7; day++)
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: form.recurrenceRule!.weekdays.contains(day)
                    ? const Color(0xff4f69df)
                    : const Color(0xfff6f6f6),
              ),
              child: Text(
                weekdayLabel(context, day),
                style: TextStyle(
                  fontSize: 14,
                  color: form.recurrenceRule!.weekdays.contains(day)
                      ? Colors.white
                      : const Color(0xff545454),
                ),
              ),
            ),
        ],
      ),
    const SizedBox(height: 0),
    _periodPanel(
      form.scheduleName ?? '',
      form.scheduleTime!.subtract(
        form.totalPreparationTime +
            (form.moveTime ?? Duration.zero) +
            (form.scheduleSpareTime ?? Duration.zero),
      ),
      form.scheduleTime!,
    ),
    for (final conflict in review.conflicts.take(3))
      _periodPanel(
        conflict.other.scheduleName,
        null,
        conflict.other.scheduleTime,
      ),
  ];

  Widget _periodPanel(
    String title,
    DateTime? start,
    DateTime end,
  ) => RecurrencePanel(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        Text(
          start == null
              ? '${recurrenceText(context, '약속 시각', 'Appointment time')} ${_clock(end)}'
              : '${_clock(start)} – ${_clock(end)}',
          style: const TextStyle(fontSize: 14, color: Color(0xff545454)),
        ),
      ],
    ),
  );

  List<Widget> _conflicts(
    ScheduleFormState form,
    RecurrenceReview review,
    Map<String, List<RecurrenceConflict>> byKey,
    int remaining,
    bool canExclude,
  ) => [
    Text(
      recurrenceText(
        context,
        canExclude
            ? '개인 일정을 고려해 참석이 어려운 회차를 선택해 주세요.\n선택한 회차는 일정에서 제외됩니다.'
            : '다른 일정과 겹쳐요. 시간이나 준비과정을 조정해 주세요.',
        canExclude
            ? 'Select the conflicting occurrences to exclude.'
            : 'This overlaps another schedule. Adjust the time or preparation.',
      ),
      style: const TextStyle(
        fontSize: 13,
        height: 1.6,
        color: Color(0xff545454),
      ),
    ),
    RecurrencePanel(
      highlighted: true,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        children: [
          for (final entry in byKey.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 93,
                    child: Text(
                      _day(
                        review.occurrences[entry.key]?.schedule.scheduleTime ??
                            DateTime.parse(entry.key),
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff4f69df),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      recurrenceText(
                        context,
                        '${entry.value.map((c) => c.other.scheduleName).toSet().join(' · ')}이 있어 참석이 어렵습니다.',
                        entry.value
                            .map((c) => c.other.scheduleName)
                            .toSet()
                            .join(' · '),
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
    Row(
      children: [
        Expanded(
          child: Text(
            recurrenceText(
              context,
              '전체 ${review.slots.length}회차',
              '${review.slots.length} occurrences',
            ),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          recurrenceText(
            context,
            '선택 ${_excluded.length}개 제외 · $remaining개 저장 예정',
            '$remaining remaining',
          ),
          style: const TextStyle(fontSize: 10, color: Color(0xff545454)),
        ),
      ],
    ),
    Column(
      children: [
        for (var index = 0; index < review.slots.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: RecurrencePanel(
              padding: EdgeInsets.zero,
              highlighted: _excluded.contains(review.slots[index].key),
              child: CheckboxListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                dense: true,
                visualDensity: const VisualDensity(vertical: -4),
                minTileHeight: 38,
                value: _excluded.contains(review.slots[index].key),
                onChanged: canExclude
                    ? (v) => setState(
                        () => v == true
                            ? _excluded.add(review.slots[index].key)
                            : _excluded.remove(review.slots[index].key),
                      )
                    : null,
                title: Row(
                  children: [
                    SizedBox(
                      width: 64,
                      child: Text(
                        recurrenceText(
                          context,
                          '${index + 1}회차',
                          '#${index + 1}',
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _day(_time(review.slots[index])),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
    RecurrenceNotice(
      asset: 'recurrence_detached_vector.svg',
      glyph: 'i',
      glyphColor: const Color(0xff545454),
      child: Text(
        recurrenceText(
          context,
          '모든 회차를 제외하면 저장할 수 없습니다.\n제외한 회차는 총횟수에서 차감되며 다른 날짜로 채우지 않아요.',
          'At least one occurrence must remain. Excluded occurrences consume the count and are not replaced.',
        ),
        style: const TextStyle(
          fontSize: 11,
          height: 1.6,
          color: Color(0xff545454),
        ),
      ),
    ),
  ];

  List<Widget> _summary(
    ScheduleFormState form,
    RecurrenceReview review,
    List<RecurrenceSlot> remaining,
  ) => [
    Text(
      recurrenceText(
        context,
        '아래 내용으로 반복 일정을 저장할까요?',
        'Save this recurring schedule?',
      ),
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 12,
        height: 1.5,
        color: Color(0xff545454),
      ),
    ),
    RecurrencePanel(
      highlighted: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            form.scheduleName ?? '',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 3),
          if (form.recurrenceRule != null)
            Text(
              recurrencePatternLabel(
                context,
                form.recurrenceRule!,
                includeTime: true,
              ),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          if (remaining.isNotEmpty)
            Text(
              '${recurrenceText(context, '첫 일정', 'First occurrence')}: ${_day(_time(remaining.first))}',
              style: const TextStyle(
                fontSize: 12,
                height: 1.7,
                color: Color(0xff545454),
              ),
            ),
          const Divider(height: 28),
          Row(
            children: [
              SvgPicture.asset(
                'recurrence_review_clock.svg',
                package: 'assets',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  recurrenceText(
                    context,
                    '준비 ${form.totalPreparationTime.inMinutes}분 · 이동 ${form.moveTime?.inMinutes ?? 0}분 · 여유 ${form.scheduleSpareTime?.inMinutes ?? 0}분',
                    'Preparation ${form.totalPreparationTime.inMinutes} min · travel ${form.moveTime?.inMinutes ?? 0} min · buffer ${form.scheduleSpareTime?.inMinutes ?? 0} min',
                  ),
                  style: const TextStyle(fontSize: 12, height: 1.6),
                ),
              ),
            ],
          ),
          if (remaining.isNotEmpty &&
              review.occurrences[remaining.first.key] != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                SvgPicture.asset(
                  'recurrence_review_play.svg',
                  package: 'assets',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${recurrenceText(context, '준비 시작', 'Preparation starts')} ${_clock(CivilTimeResolver.civilTimeAt(review.occurrences[remaining.first.key]!.preparationStartUtc, review.occurrences[remaining.first.key]!.schedule.timeZoneId))}',
                    style: const TextStyle(fontSize: 12, height: 1.6),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
    if (remaining.isNotEmpty) ...[
      const SizedBox(height: 0),
      Row(
        children: [
          Expanded(
            child: Text(
              recurrenceText(context, '예정된 날짜', 'Upcoming occurrences'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            recurrenceText(
              context,
              '처음 ${remaining.take(3).length}개의 일정을 확인했어요.',
              'First occurrences',
            ),
            style: const TextStyle(fontSize: 11, color: Color(0xff545454)),
          ),
        ],
      ),
      RecurrencePanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          children: [
            for (final slot in remaining.take(3)) ...[
              if (slot != remaining.first) const Divider(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _day(_time(slot)),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    _clock(_time(slot)),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xff545454),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ],
  ];

  List<Widget> _detached(RecurrenceReview review) => [
    Text(
      recurrenceText(
        context,
        '규칙 변경으로 인해 기존과 다른 일정이 발생하는 회차가 있습니다. 아래 일정을 단독 일정으로 유지하고 저장할까요?',
        'Individually edited occurrences differ from the new rule. Keep these as standalone schedules?',
      ),
      style: const TextStyle(
        fontSize: 14,
        height: 1.8,
        color: Color(0xff545454),
      ),
    ),
    for (final value in review.detached)
      RecurrencePanel(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat(
                recurrenceText(context, 'M월 d일 EEEE', 'MMM d EEEE'),
                Localizations.localeOf(context).toString(),
              ).format(value.scheduleTime),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                SvgPicture.asset(
                  'recurrence_detached_timeicon.svg',
                  package: 'assets',
                ),
                const SizedBox(width: 12),
                Text(
                  _clock(value.scheduleTime),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xff545454),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    RecurrenceNotice(
      highlighted: true,
      asset: 'recurrence_detached_vector.svg',
      glyph: 'i',
      glyphColor: const Color(0xff212f6f),
      child: Text(
        recurrenceText(
          context,
          '개별 수정한 일정은 기존 시간과 준비과정을 그대로 유지합니다. 분리되는 일정도 남은 횟수에 포함돼요.',
          'Detached schedules count toward the remaining total and keep their time and preparation.',
        ),
        style: const TextStyle(
          fontSize: 13,
          height: 1.7,
          color: Color(0xff212f6f),
        ),
      ),
    ),
  ];

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
