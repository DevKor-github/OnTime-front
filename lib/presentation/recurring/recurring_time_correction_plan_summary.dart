import 'package:flutter/material.dart';
import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_time_resolution.dart';
import 'package:on_time_front/domain/recurrence/recurring_time_correction.dart';
import 'recurrence_labels.dart';

/// Read-only plan details and controlled acknowledgements, not save authority.
/// The owning screen must reset acknowledgements whenever its review changes,
/// complete conflict review, and revalidate the exact review before saving.
/// Place inside a vertically scrollable parent.
class RecurringTimeCorrectionPlanSummary extends StatelessWidget {
  const RecurringTimeCorrectionPlanSummary({
    super.key,
    required this.mapping,
    required this.unresolvedOverrides,
    required this.confirmedDetachedIds,
    required this.confirmedUnmatchedExclusions,
    required this.onDetachedChanged,
    required this.onUnmatchedExclusionsChanged,
    this.onResolveOverride,
    this.enabled = true,
  });

  final RecurringTimeCorrectionMapping mapping;
  final Map<String, ScheduleTimeResolutionStatus> unresolvedOverrides;
  final Set<String> confirmedDetachedIds;
  final Set<String> confirmedUnmatchedExclusions;
  final ValueChanged<Set<String>> onDetachedChanged;
  final ValueChanged<Set<String>> onUnmatchedExclusionsChanged;
  final ValueChanged<String>? onResolveOverride;
  final bool enabled;

  static String exclusionKey(TimeCorrectionExclusion value) =>
      '${value.segmentId}\n${value.slot}';

  String _recorded(BuildContext context, ScheduleEntity value) {
    final offset = value.occurrenceOffsetSeconds;
    return '${recurrenceDate(context, value.scheduleTime)} · ${value.timeZoneId}\n'
        '${recurrenceText(context, '기록된 UTC 오프셋', 'Recorded UTC offset')}: '
        '${offset == null ? recurrenceText(context, '미확정', 'Unconfirmed') : _offset(offset)}'
        '${value.recurringSlotKey == null ? '' : '\n${recurrenceText(context, '기존 회차', 'Original slot')}: ${recurrenceDate(context, CivilDateTime.parse(value.recurringSlotKey!).toUtcCarrier())} · #${value.recurringOrdinal}'}';
  }

  String _offset(int seconds) {
    final absolute = seconds.abs();
    final hours = (absolute ~/ 3600).toString().padLeft(2, '0');
    final minutes = (absolute % 3600 ~/ 60).toString().padLeft(2, '0');
    final remainder = absolute % 60;
    return '${seconds < 0 ? '-' : '+'}$hours:$minutes'
        '${remainder == 0 ? '' : ':${remainder.toString().padLeft(2, '0')}'}';
  }

  String _reason(BuildContext context, ScheduleTimeResolutionStatus status) =>
      switch (status) {
        ScheduleTimeResolutionStatus.unknownZone => recurrenceText(
          context,
          '알 수 없는 시간대',
          'Unknown time zone',
        ),
        ScheduleTimeResolutionStatus.nonexistent => recurrenceText(
          context,
          '존재하지 않는 현지 시각',
          'Nonexistent local time',
        ),
        ScheduleTimeResolutionStatus.ambiguous => recurrenceText(
          context,
          '두 번 반복되는 현지 시각',
          'Repeated local time',
        ),
        ScheduleTimeResolutionStatus.changed => recurrenceText(
          context,
          '시간대 규칙 변경',
          'Changed time-zone rules',
        ),
        ScheduleTimeResolutionStatus.historicalUncertain => recurrenceText(
          context,
          '과거 시각 미확정',
          'Uncertain historical time',
        ),
        ScheduleTimeResolutionStatus.invalid => recurrenceText(
          context,
          '시각 확인 필요',
          'Time review required',
        ),
        ScheduleTimeResolutionStatus.resolved => recurrenceText(
          context,
          '별도 검토 결과 확인 필요',
          'Individual review result required',
        ),
      };

  @override
  Widget build(BuildContext context) {
    String text(String ko, String en) => recurrenceText(context, ko, en);
    final mapped = mapping.rows.where((row) => !row.detached).toList();
    final detached = mapping.rows.where((row) => row.detached).toList();
    final unmatched = mapping.exclusions
        .where((row) => row.slot == null)
        .toList();
    final matched = mapping.exclusions
        .where((row) => row.slot != null)
        .toList();
    final detachedIds = detached.map((row) => row.original.id).toSet();
    final unmatchedKeys = unmatched
        .map((row) => exclusionKey(row.original))
        .toSet();
    final schedules = {
      for (final row in mapping.rows) row.original.id: row.original,
      for (final row in mapping.protectedRows) row.id: row,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            text('반복 일정 변경 내용', 'Recurring schedule changes'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${recurrenceLabel(context, mapping.rule)}\n${mapping.rule.timeZoneId} · ${recurrenceEndLabel(context, mapping.rule)}',
        ),
        const SizedBox(height: 8),
        Text(
          text(
            '새 반복 횟수에는 제외한 회차도 포함됩니다. 단발로 남길 일정 ${detached.length}개는 별도로 유지됩니다.',
            'The new occurrence count includes excluded slots. ${detached.length} standalone schedules are preserved separately.',
          ),
        ),
        if (mapping.automaticallyRetainedCount)
          Text(
            text(
              '남은 횟수는 기존 기록과 현재 규칙으로 계산했습니다. 과거 시간대 규칙을 재현했다는 뜻은 아닙니다.',
              'The remaining count uses stored records and current rules; it does not reconstruct historical time-zone rules.',
            ),
          ),
        Text(
          text(
            '일정의 연결 관계와 별도로 충돌 검사를 확인해야 합니다. 이 목록만으로 저장 가능 여부가 확정되지는 않습니다.',
            'Conflict review is separate from these schedule associations. This list alone does not establish that the plan can be saved.',
          ),
        ),
        if (unresolvedOverrides.isNotEmpty)
          _PlanSection<MapEntry<String, ScheduleTimeResolutionStatus>>(
            key: const Key('plan-unresolved'),
            owner: mapping,
            title: text(
              '먼저 개별 시간 확인 (${unresolvedOverrides.length})',
              'Individual time review first (${unresolvedOverrides.length})',
            ),
            values: unresolvedOverrides.entries.toList(),
            builder: (entry) {
              final schedule = schedules[entry.key];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    title: Text(
                      schedule?.scheduleName ??
                          text('연결된 일정', 'Associated schedule'),
                    ),
                    subtitle: Text(
                      '${_reason(context, entry.value)}\n${text('이 일정의 시각을 확인한 후 전체 계획을 다시 검토하세요.', 'Review this time, then review the complete plan again.')}',
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      key: ValueKey('resolve-${entry.key}'),
                      onPressed: enabled && onResolveOverride != null
                          ? () => onResolveOverride!(entry.key)
                          : null,
                      child: Text(text('이 일정 시간 확인', 'Review this time')),
                    ),
                  ),
                ],
              );
            },
          ),
        _PlanSection<TimeCorrectionRowMapping>(
          key: const Key('plan-mapped'),
          owner: mapping,
          title: text(
            '새 회차에 연결 (${mapped.length})',
            'Associated with new slots (${mapped.length})',
          ),
          values: mapped,
          builder: (row) {
            final slot = row.slot!;
            final keepsTime = row.original.recurringOverrides
                .split(',')
                .contains('time');
            return ListTile(
              key: ValueKey('mapped-${row.original.id}'),
              title: Text(row.original.scheduleName),
              subtitle: Text(
                '${text('원래 일정', 'Original schedule')}: ${_recorded(context, row.original)}\n'
                '${text('새 회차 연결', 'New slot association')}: ${recurrenceDate(context, slot.civilTime)} · ${mapping.rule.timeZoneId} · #${slot.ordinal}\n'
                '${keepsTime ? text('개별 지정한 약속 시각과 시간대를 그대로 유지합니다. 위 시각은 새 회차의 연결 기준입니다.', 'The individually chosen appointment time and zone stay unchanged. The time above identifies the new slot.') : '${text('새 약속 시각', 'New appointment instant')}: ${slot.instantUtc.toUtc().toIso8601String()} · ${text('선택 오프셋', 'Selected offset')}: UTC${_offset(slot.offsetSeconds)}'}',
              ),
            );
          },
        ),
        if (detached.isNotEmpty)
          _PlanSection<TimeCorrectionRowMapping>(
            key: const Key('plan-detached'),
            owner: mapping,
            title: text(
              '단발로 유지할 일정 (${detached.length})',
              'Preserve as standalone (${detached.length})',
            ),
            values: detached,
            builder: (row) => CheckboxListTile(
              key: ValueKey('detached-${row.original.id}'),
              controlAffinity: ListTileControlAffinity.leading,
              value: confirmedDetachedIds.contains(row.original.id),
              title: Text(row.original.scheduleName),
              subtitle: Text(
                '${_recorded(context, row.original)}\n${text('이 일정을 삭제하지 않고 내용과 준비 항목을 그대로 유지하는 데 동의합니다.', 'I agree to preserve this schedule and its preparation unchanged, without deleting it.')}',
              ),
              onChanged: enabled
                  ? (checked) {
                      final next = confirmedDetachedIds.intersection(
                        detachedIds,
                      );
                      if (checked == true) {
                        next.add(row.original.id);
                      } else {
                        next.remove(row.original.id);
                      }
                      onDetachedChanged(Set.unmodifiable(next));
                    }
                  : null,
            ),
          ),
        if (mapping.protectedRows.isNotEmpty)
          _PlanSection<ScheduleEntity>(
            key: const Key('plan-protected'),
            owner: mapping,
            title: text(
              '변경하지 않는 기록 (${mapping.protectedRows.length})',
              'Records kept unchanged (${mapping.protectedRows.length})',
            ),
            values: mapping.protectedRows,
            builder: (row) => ListTile(
              title: Text(row.scheduleName),
              subtitle: Text(_recorded(context, row)),
            ),
          ),
        if (mapping.protectedSlots.isNotEmpty)
          Text(
            text(
              '보호된 기록에 대응하는 새 회차 ${mapping.protectedSlots.length}개는 제외해 중복 생성을 막습니다.',
              '${mapping.protectedSlots.length} new slots corresponding to protected records are excluded to prevent duplicate occurrences.',
            ),
          ),
        if (matched.isNotEmpty)
          _PlanSection<TimeCorrectionExclusionMapping>(
            key: const Key('plan-matched-exclusions'),
            owner: mapping,
            title: text(
              '계속 제외할 회차 (${matched.length})',
              'Slots that remain excluded (${matched.length})',
            ),
            values: matched,
            builder: (row) => ListTile(
              title: Text(
                recurrenceDate(
                  context,
                  CivilDateTime.parse(row.original.slot).toUtcCarrier(),
                ),
              ),
              subtitle: Text(
                '${text('새 회차 연결', 'New slot association')}: ${recurrenceDate(context, row.slot!.civilTime)} · #${row.slot!.ordinal}\n${text('원래 제외 기록을 보존하며 새 반복 횟수에서도 한 회차로 계산합니다.', 'The original exclusion is preserved; this slot also consumes one occurrence in the new count.')}',
              ),
            ),
          ),
        if (unmatched.isNotEmpty)
          _PlanSection<TimeCorrectionExclusionMapping>(
            key: const Key('plan-unmatched-exclusions'),
            owner: mapping,
            title: text(
              '새 규칙에 대응하지 않는 제외 기록 (${unmatched.length})',
              'Exclusions outside the new rule (${unmatched.length})',
            ),
            values: unmatched,
            builder: (row) {
              final id = exclusionKey(row.original);
              return CheckboxListTile(
                key: ValueKey('exclusion-$id'),
                controlAffinity: ListTileControlAffinity.leading,
                value: confirmedUnmatchedExclusions.contains(id),
                title: Text(
                  recurrenceDate(
                    context,
                    CivilDateTime.parse(row.original.slot).toUtcCarrier(),
                  ),
                ),
                subtitle: Text(
                  text(
                    '원래 제외 기록은 보존되지만 새 규칙에는 적용되지 않음을 확인했습니다. 삭제했던 회차를 다시 만들지 않습니다.',
                    'I understand that the original exclusion is preserved but does not apply to the new rule. The deleted occurrence is not recreated.',
                  ),
                ),
                onChanged: enabled
                    ? (checked) {
                        final next = confirmedUnmatchedExclusions.intersection(
                          unmatchedKeys,
                        );
                        if (checked == true) {
                          next.add(id);
                        } else {
                          next.remove(id);
                        }
                        onUnmatchedExclusionsChanged(Set.unmodifiable(next));
                      }
                    : null,
              );
            },
          ),
      ],
    );
  }
}

class _PlanSection<T> extends StatefulWidget {
  const _PlanSection({
    super.key,
    required this.owner,
    required this.title,
    required this.values,
    required this.builder,
  });
  final Object owner;
  final String title;
  final List<T> values;
  final Widget Function(T) builder;

  @override
  State<_PlanSection<T>> createState() => _PlanSectionState<T>();
}

class _PlanSectionState<T> extends State<_PlanSection<T>> {
  static const pageSize = 10;
  int _start = 0;

  @override
  void didUpdateWidget(covariant _PlanSection<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.owner, widget.owner)) _start = 0;
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            widget.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (widget.values.isEmpty) Text(recurrenceText(context, '없음', 'None')),
        for (final value in widget.values.skip(_start).take(pageSize))
          widget.builder(value),
        if (widget.values.length > pageSize) ...[
          Text(
            '${_start + 1}–${(_start + pageSize).clamp(0, widget.values.length)} / ${widget.values.length}',
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                key: const Key('plan-page-previous'),
                onPressed: _start == 0
                    ? null
                    : () => setState(() => _start -= pageSize),
                child: Text(recurrenceText(context, '이전 항목', 'Previous items')),
              ),
              TextButton(
                key: const Key('plan-page-next'),
                onPressed: _start + pageSize >= widget.values.length
                    ? null
                    : () => setState(() => _start += pageSize),
                child: Text(recurrenceText(context, '다음 항목', 'Next items')),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}
