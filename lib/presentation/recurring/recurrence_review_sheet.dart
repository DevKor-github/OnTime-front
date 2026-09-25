import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/core/time/time_zone_rules.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'package:on_time_front/core/time/schedule_time_resolution.dart';
import 'package:on_time_front/presentation/shared/time/schedule_zoned_time.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
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
  late DateTime _displayNowUtc;
  @override
  Widget build(BuildContext context) {
    _displayNowUtc = DateTime.now().toUtc();
    final l = AppLocalizations.of(context)!;
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
        Text(
          form.originalSchedule == null
              ? l.zonedTimeReviewScopeNew
              : form.recurringScope == RecurringEditScope.following
              ? l.zonedTimeReviewScopeFollowing
              : l.zonedTimeReviewScopeOccurrence,
        ),
        if (!review.persistentConflict && remaining.isNotEmpty)
          RecurrencePanel(
            highlighted: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.zonedTimeFirstOccurrence),
                _slotPresentation(remaining.first),
                if (review.occurrences[remaining.first.key] != null) ...[
                  const SizedBox(height: 12),
                  _preparationPresentation(remaining.first),
                ],
              ],
            ),
          ),
        if (review.persistentConflict) ...[
          RecurrencePanel(
            highlighted: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recurrenceText(
                    context,
                    '반복 일정이 계속 겹쳐요',
                    'These recurring rules keep overlapping',
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  recurrenceText(
                    context,
                    '시간이나 요일을 수정해야 저장할 수 있어요.',
                    'Change the time or repeat pattern before saving.',
                  ),
                ),
              ],
            ),
          ),
          if (form.recurrenceRule != null)
            RecurrenceValue(
              label: recurrenceText(context, '반복 요일', 'Repeat pattern'),
              value: recurrenceLabel(context, form.recurrenceRule!),
            ),
          Text(form.scheduleName ?? ''),
          _draftPresentation(),
          for (final conflict in review.conflicts)
            RecurrencePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(conflict.other.scheduleName),
                  _schedulePresentation(conflict.other),
                ],
              ),
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
          RecurrencePanel(
            highlighted: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry in byKey.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '${recurrenceDate(context, review.occurrences[entry.key]?.schedule.scheduleTime ?? DateTime.parse(entry.key))} · ${entry.value.map((c) => c.other.scheduleName).toSet().join(' · ')}',
                    ),
                  ),
              ],
            ),
          ),
          Text(
            recurrenceText(
              context,
              '전체 ${review.slots.length}회차 · 선택 ${_excluded.length}개 제외',
              '${review.slots.length} occurrences · ${_excluded.length} excluded',
            ),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (final slot in review.slots)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: RecurrencePanel(
                padding: EdgeInsets.zero,
                highlighted: _excluded.contains(slot.key),
                child: CheckboxListTile(
                  key: ValueKey('review-occurrence-${slot.key}'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  dense: true,
                  value: _excluded.contains(slot.key),
                  onChanged: canExclude
                      ? (v) => setState(
                          () => v == true
                              ? _excluded.add(slot.key)
                              : _excluded.remove(slot.key),
                        )
                      : null,
                  title: _slotPresentation(slot),
                  subtitle: byKey.containsKey(slot.key)
                      ? Text(
                          byKey[slot.key]!
                              .map((c) => c.other.scheduleName)
                              .toSet()
                              .join(' · '),
                        )
                      : null,
                ),
              ),
            ),
          RecurrencePanel(
            child: Text(
              recurrenceText(
                context,
                '모든 회차를 제외하면 저장할 수 없습니다. 제외한 회차는 총횟수에서 차감되며 다른 날짜로 채우지 않아요.',
                'At least one occurrence must remain. Excluded occurrences consume the count and are not replaced.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ] else ...[
          if (review.detached.isEmpty) ...[
            Text(
              recurrenceText(
                context,
                '아래 내용으로 반복 일정을 저장할까요?',
                'Save this recurring schedule?',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            RecurrencePanel(
              highlighted: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    form.scheduleName ?? '',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(fontSize: 24),
                  ),
                  const SizedBox(height: 8),
                  if (form.recurrenceRule != null)
                    Text(
                      recurrenceLabel(context, form.recurrenceRule!),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  const Divider(height: 28),
                  Text(
                    recurrenceText(
                      context,
                      '준비 ${form.totalPreparationTime.inMinutes}분 · 이동 ${form.moveTime?.inMinutes ?? 0}분 · 여유 ${form.scheduleSpareTime?.inMinutes ?? 0}분',
                      'Preparation ${form.totalPreparationTime.inMinutes} min · travel ${form.moveTime?.inMinutes ?? 0} min · buffer ${form.scheduleSpareTime?.inMinutes ?? 0} min',
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (review.detached.isNotEmpty) ...[
            Text(
              recurrenceText(
                context,
                '규칙 변경으로 기존과 다른 일정이 발생하는 회차가 있습니다. 아래 일정을 단독 일정으로 유지하고 저장할까요?',
                'Individually edited occurrences differ from the new rule. Keep these as standalone schedules?',
              ),
            ),
            for (final value in review.detached)
              RecurrencePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value.scheduleName),
                    _schedulePresentation(value),
                  ],
                ),
              ),
            RecurrencePanel(
              highlighted: true,
              child: Text(
                recurrenceText(
                  context,
                  '개별 수정한 일정은 기존 시간과 준비과정을 그대로 유지합니다. 분리되는 일정도 남은 횟수에 포함돼요.',
                  'Detached schedules count toward the remaining total and keep their time and preparation.',
                ),
              ),
            ),
          ],
          if (review.totalOccurrences != null)
            Text(
              recurrenceText(
                context,
                '반복 ${review.totalOccurrences! - _excluded.length}회${review.detached.isEmpty ? '' : ' + 독립 일정 ${review.detached.length}회'}',
                '${review.totalOccurrences! - _excluded.length} recurring occurrences',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
        if (!review.persistentConflict && remaining.isNotEmpty)
          ExpansionTile(
            key: const ValueKey('all-reviewed-occurrences'),
            title: Text(l.zonedTimeAllReviewedOccurrences),
            children: [
              for (final slot in remaining)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: _slotPresentation(slot),
                ),
            ],
          ),
        if (review.skipped.isNotEmpty) ...[
          RecurrencePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recurrenceText(context, '건너뛴 날짜', 'Skipped dates'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                for (final skip in review.skipped.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      _skip(context, skip),
                      style: Theme.of(context).textTheme.bodySmall,
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

  Widget _draftPresentation() {
    final form = widget.form;
    // This is a presentation-only snapshot. Reuse the common resolver so an
    // obsolete explicit offset remains changed rather than selecting a new one.
    final preview = ScheduleEntity(
      id: form.id,
      place: PlaceEntity(
        id: form.placeId ?? '',
        placeName: form.placeName ?? '',
      ),
      scheduleName: form.scheduleName ?? '',
      scheduleTime: form.scheduleTime!,
      timeZoneId: form.timeZoneId,
      occurrenceOffsetSeconds: form.occurrenceOffsetSeconds,
      moveTime: form.moveTime ?? Duration.zero,
      isChanged: false,
      isStarted: false,
      scheduleSpareTime: form.scheduleSpareTime,
      scheduleNote: '',
    );
    return _schedulePresentation(preview);
  }

  Widget _schedulePresentation(ScheduleEntity schedule) => ScheduleZonedTime(
    civil: CivilDateTime.fromFields(schedule.scheduleTime),
    timeZoneId: schedule.timeZoneId,
    resolution: ScheduleTimeResolver.resolve(schedule, nowUtc: _displayNowUtc),
    showInstant: true,
  );

  Widget _slotPresentation(RecurrenceSlot slot) {
    final schedule = widget.review.occurrences[slot.key]?.schedule;
    return ScheduleZonedTime(
      showInstant: true,
      civil: CivilDateTime.fromFields(schedule?.scheduleTime ?? slot.civilTime),
      timeZoneId: schedule?.timeZoneId ?? widget.form.timeZoneId,
      resolution: schedule == null
          ? ScheduleTimeResolution(
              status: ScheduleTimeResolutionStatus.resolved,
              instantUtc: slot.instantUtc,
            )
          : ScheduleTimeResolver.resolve(schedule, nowUtc: _displayNowUtc),
    );
  }

  Widget _preparationPresentation(RecurrenceSlot slot) {
    final l = AppLocalizations.of(context)!;
    final occurrence = widget.review.occurrences[slot.key]!;
    final zone = occurrence.schedule.timeZoneId;
    CivilDateTime? civil;
    final resolution = ScheduleTimeResolver.resolve(
      occurrence.schedule,
      nowUtc: _displayNowUtc,
    );
    if (resolution.status == ScheduleTimeResolutionStatus.resolved &&
        TimeZoneRules.contains(zone)) {
      try {
        civil = CivilDateTime.fromFields(
          CivilTimeResolver.civilTimeAt(occurrence.preparationStartUtc, zone),
        );
      } on Exception {
        // The reviewed instant remains meaningful even if a rule reload or
        // the supported civil range now prevents a safe named-zone display.
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.zonedTimePreparationStart),
        if (civil == null) ...[
          Text(l.zonedTimePreparationUnavailable),
          Text(
            '$zone · ${l.zonedTimeInstant}: ${occurrence.preparationStartUtc.toIso8601String()}',
          ),
        ] else
          ScheduleZonedTime(
            civil: civil,
            timeZoneId: zone,
            resolution: ScheduleTimeResolution(
              status: ScheduleTimeResolutionStatus.resolved,
              instantUtc: occurrence.preparationStartUtc,
            ),
            showInstant: true,
          ),
      ],
    );
  }

  String _skip(BuildContext context, RecurrenceSkip skip) =>
      '${recurrenceDate(context, skip.date)} · ${switch (skip.reason) {
        RecurrenceSkipReason.nonexistentDate => recurrenceText(context, '해당 월에 없는 날짜/요일', 'Date or weekday missing in this month'),
        RecurrenceSkipReason.nonexistentTime => recurrenceText(context, '일광절약시간 변경으로 없는 시각', 'Time does not exist due to daylight saving'),
        RecurrenceSkipReason.preparationPassed => recurrenceText(context, '준비 시작 시각이 지남', 'Preparation start has passed'),
      }}';
}
