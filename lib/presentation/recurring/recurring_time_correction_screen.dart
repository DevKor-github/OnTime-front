import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:on_time_front/core/time/time_zone_rules.dart';
import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'package:on_time_front/domain/entities/schedule_save.dart';
import 'package:on_time_front/domain/entities/schedule_time_correction.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'package:on_time_front/domain/recurrence/recurring_time_correction.dart';
import 'package:on_time_front/domain/use-cases/recurring_time_correction_workflow.dart';
import 'package:on_time_front/domain/use-cases/schedule_time_correction_workflow.dart';
import 'package:on_time_front/presentation/schedule_create/screens/schedule_time_correction_screen.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_date_time/screens/schedule_time_zone_picker.dart';
import 'package:on_time_front/presentation/shared/components/civil_date_time_picker.dart';
import 'recurrence_labels.dart';
import 'recurrence_settings_sheet.dart';
import 'recurring_time_correction_plan_summary.dart';

/// Active-store controller. Backup candidates use their own lease/controller.
class RecurringTimeCorrectionScreen extends StatefulWidget {
  const RecurringTimeCorrectionScreen({
    super.key,
    required this.scheduleId,
    required this.workflow,
    required this.individualWorkflow,
    this.onSaved,
  });
  final String scheduleId;
  final RecurringTimeCorrectionWorkflow workflow;
  final ScheduleTimeCorrectionWorkflow individualWorkflow;
  final VoidCallback? onSaved;
  @override
  State<RecurringTimeCorrectionScreen> createState() =>
      _RecurringTimeCorrectionScreenState();
}

class _RecurringTimeCorrectionScreenState
    extends State<RecurringTimeCorrectionScreen> {
  ScheduleTimeCorrectionReview? _anchor;
  RecurrenceRule? _rule;
  RecurringTimeCorrectionReview? _review;
  RecurringTimeCorrectionCommand? _command;
  ScheduleSaveReceipt? _receipt;
  Set<String> _excluded = {}, _detached = {}, _unmatched = {}, _uncertain = {};
  bool _explicitEnd = false,
      _busy = false,
      _confirming = false,
      _needsReview = false;
  String? _error;
  int _owner = 0, _selection = 0, _conflictPage = 0, _possiblePage = 0;
  bool _owns(int owner, int selection) =>
      mounted && owner == _owner && selection == _selection;
  String text(String ko, String en) => recurrenceText(context, ko, en);
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(RecurringTimeCorrectionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scheduleId != widget.scheduleId ||
        oldWidget.workflow != widget.workflow ||
        oldWidget.individualWorkflow != widget.individualWorkflow) {
      _load();
    }
  }

  void _invalidate() {
    _selection++;
    _review = null;
    _command = null;
    _receipt = null;
    _detached = {};
    _unmatched = {};
    _uncertain = {};
    _conflictPage = 0;
    _possiblePage = 0;
    _error = null;
    _needsReview = false;
  }

  Future<void> _load() async {
    final owner = ++_owner;
    setState(() {
      _invalidate();
      _busy = true;
      _confirming = false;
      _anchor = null;
      _rule = null;
      _excluded = {};
      _explicitEnd = false;
    });
    try {
      final anchor = await widget.individualWorkflow.repository.review(
        widget.scheduleId,
      );
      if (!mounted || owner != _owner) return;
      final source = anchor.snapshot.segment;
      if (source == null) {
        throw const ScheduleSaveRejected(ScheduleSaveFailure.invalid);
      }
      final start = CivilDateTime.parse(
        anchor.snapshot.schedule.recurringSlotKey!,
      ).toUtcCarrier();
      setState(() {
        _anchor = anchor;
        _rule = source.rule.withStartAndEnd(
          start: start,
          count: source.rule.count,
          until: source.rule.until,
          repeatedTime: source.rule.repeatedTime,
        );
        _busy = false;
      });
    } catch (_) {
      if (!mounted || owner != _owner) return;
      setState(() {
        _busy = false;
        _needsReview = true;
        _error = text(
          '현재 반복 일정을 읽지 못했어요. 다시 확인해주세요.',
          'The recurring schedule could not be read. Review it again.',
        );
      });
    }
  }

  RecurrenceRule _changedRule({
    DateTime? start,
    String? zone,
    RepeatedCivilTime? repeated,
    bool replaceRepeated = false,
  }) {
    final r = _rule!;
    return RecurrenceRule(
      frequency: r.frequency,
      start: start ?? r.start,
      timeZoneId: zone ?? r.timeZoneId,
      interval: r.interval,
      weekdays: r.weekdays,
      monthly: r.monthly,
      monthDay: r.monthDay,
      ordinal: r.ordinal,
      monthWeekday: r.monthWeekday,
      until: r.until,
      count: r.count,
      repeatedTime: replaceRepeated ? repeated : r.repeatedTime,
    );
  }

  Future<void> _pickCivil(bool dateOnly) async {
    final owner = _owner, selection = _selection;
    final result = await showCivilDateTimePicker(
      context: context,
      initialCivil: _rule!.start,
      dateOnly: dateOnly,
      title: text('새 반복 시작 시각', 'New recurring start'),
    );
    if (result == null || !_owns(owner, selection)) return;
    try {
      final rule = _changedRule(start: result);
      setState(() {
        _invalidate();
        _rule = rule;
        _excluded = {};
      });
    } on ArgumentError {
      setState(
        () => _error = text(
          '종료 날짜 이후로 시작할 수 없어요. 반복 종료 조건을 먼저 바꿔주세요.',
          'The start cannot follow the end date. Change the end condition first.',
        ),
      );
    }
  }

  Future<void> _pickZone() async {
    final owner = _owner, selection = _selection;
    final result = await showScheduleTimeZonePicker(
      context: context,
      currentZone: _rule!.timeZoneId,
      civil: _rule!.start,
      offsetSeconds: null,
      isCurrent: () => _owns(owner, selection),
    );
    if (result == null || !_owns(owner, selection)) return;
    setState(() {
      final rule = _changedRule(zone: result, replaceRepeated: true);
      _invalidate();
      _rule = rule;
      _excluded = {};
    });
  }

  Future<void> _pickRule() async {
    final owner = _owner, selection = _selection;
    final result = await showModalBottomSheet<RecurrenceSettingsResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => RecurrenceSettingsSheet(
        start: _rule!.start,
        timeZoneId: _rule!.timeZoneId,
        initial: _rule,
        allowNone: false,
        leadTime: _anchor!.snapshot.segment!.leadTime,
      ),
    );
    if (result?.rule == null || !_owns(owner, selection)) return;
    setState(() {
      _invalidate();
      _rule = result!.rule;
      _explicitEnd = true;
      _excluded = {};
    });
  }

  Future<void> _buildPlan({Set<String>? excluded}) async {
    if (_busy || _confirming || _anchor == null || _rule == null) return;
    setState(() {
      _invalidate();
      if (excluded != null) _excluded = Set.of(excluded);
      _busy = true;
    });
    final owner = _owner, selection = _selection;
    try {
      final review = await widget.workflow.repository.review(
        RecurringTimeCorrectionRequest(
          anchorReview: _anchor!,
          rule: _rule!,
          endExplicitlyChosen: _explicitEnd,
          excludedConflictSlots: _excluded,
        ),
      );
      if (!_owns(owner, selection)) return;
      setState(() {
        _review = review;
        _busy = false;
      });
    } on RecurringTimeCorrectionCountRequired {
      if (!_owns(owner, selection)) return;
      setState(() {
        _busy = false;
        _error = text(
          '남은 횟수를 확정할 수 없어요. 반복 설정에서 횟수나 종료 조건을 직접 확인해주세요.',
          'The remaining count cannot be established. Explicitly choose the count or end condition in recurrence settings.',
        );
      });
    } catch (_) {
      if (!_owns(owner, selection)) return;
      setState(() {
        _busy = false;
        _error = text(
          '전체 계획을 검증하지 못했어요. 시각·규칙·기록을 다시 확인해주세요. 변경은 저장되지 않았어요.',
          'The complete plan could not be verified. Review its time, rule and records. No changes were saved.',
        );
      });
    }
  }

  Future<void> _resolveOne(String id) async {
    final owner = _owner, selection = _selection;
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (routeContext) => Scaffold(
          appBar: AppBar(
            title: Text(text('개별 시간 확인', 'Individual time review')),
          ),
          body: ScheduleTimeCorrectionScreen(
            scheduleId: id,
            workflow: widget.individualWorkflow,
            onSaved: () => Navigator.of(routeContext).pop(true),
          ),
        ),
      ),
    );
    if (!_owns(owner, selection)) return;
    // The original plan and every acknowledgement lose authority even if the
    // individual screen was cancelled; rebuild from an actual fresh baseline.
    await _load();
  }

  bool get _canConfirm {
    final review = _review, proof = review?.conflictProof;
    if (_busy ||
        _confirming ||
        _needsReview ||
        _receipt != null ||
        review == null ||
        proof == null ||
        proof.conflicts.isNotEmpty ||
        review.unresolvedOverrides.isNotEmpty) {
      return false;
    }
    return const SetEquality<String>().equals(
          _detached,
          review.mapping.rows
              .where((e) => e.detached)
              .map((e) => e.original.id)
              .toSet(),
        ) &&
        const SetEquality<String>().equals(
          _unmatched,
          review.mapping.exclusions
              .where((e) => e.slot == null)
              .map(
                (e) =>
                    RecurringTimeCorrectionPlanSummary.exclusionKey(e.original),
              )
              .toSet(),
        ) &&
        const SetEquality<String>().equals(
          _uncertain,
          proof.possibleOverlaps.map((e) => e.id).toSet(),
        );
  }

  Future<void> _confirm() async {
    if (!_canConfirm) return;
    final owner = _owner, selection = _selection;
    final command = _command ??= RecurringTimeCorrectionCommand(
      review: _review!,
      mutationId: const Uuid().v7(),
      confirmedDetachedIds: _detached,
      confirmedUnmatchedExclusions: _unmatched,
      acknowledgedUncertainIds: _uncertain,
    );
    setState(() => _confirming = true);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(text('반복 시간 변경을 확인하세요', 'Confirm recurring time changes')),
        content: SingleChildScrollView(
          child: Text(
            text(
              '확인한 연결·단발 보존·제외·불확실 영향 목록을 적용합니다. 보호된 과거 기록은 유지됩니다. 알림 동기화가 남으면 별도로 표시합니다.',
              'Apply the reviewed associations, standalone preservation, exclusions and uncertain impacts. Protected history is preserved. Any pending notification synchronization is shown separately.',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(text('취소', 'Cancel')),
          ),
          FilledButton(
            key: const Key('confirm-recurring-time'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(text('확인 후 저장', 'Confirm and save')),
          ),
        ],
      ),
    );
    if (!_owns(owner, selection)) return;
    setState(() => _confirming = false);
    if (accepted != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final receipt = await widget.workflow.confirm(command);
      if (_owns(owner, selection)) _saved(receipt);
    } on ScheduleSaveRejected {
      if (!_owns(owner, selection)) return;
      setState(() {
        _busy = false;
        _needsReview = true;
        _error = text(
          '기록이나 시간 기준이 달라졌어요. 최신 기록으로 새 계획을 확인해주세요.',
          'The record or time authority changed. Review a new plan from the latest record.',
        );
      });
    } on ScheduleTimeCorrectionConflict {
      if (!_owns(owner, selection)) return;
      setState(() {
        _busy = false;
        _needsReview = true;
        _error = text(
          '충돌 영향이 달라졌어요. 계획을 다시 확인해주세요.',
          'Overlap impacts changed. Review the plan again.',
        );
      });
    } catch (_) {
      if (!_owns(owner, selection)) return;
      setState(() {
        _busy = false;
        _error = text(
          '결과를 확인하지 못했어요. 다시 저장하면 동일한 확인 명령의 결과를 조회합니다.',
          'The result could not be confirmed. Saving again retries the exact confirmed command.',
        );
      });
    }
  }

  void _saved(ScheduleSaveReceipt receipt) {
    setState(() {
      _busy = false;
      _receipt = receipt;
    });
    if (!receipt.deliveryPending) {
      if (widget.onSaved != null) {
        widget.onSaved!();
      } else {
        Navigator.of(context).pop(true);
      }
    }
  }

  Future<void> _retryDelivery() async {
    final owner = _owner, selection = _selection;
    setState(() => _busy = true);
    final receipt = await widget.workflow.retryDelivery(_receipt!);
    if (_owns(owner, selection)) _saved(receipt);
  }

  String _reason(String reason) => switch (reason) {
    'unknownZone' => text('알 수 없는 시간대', 'Unknown time zone'),
    'ambiguous' => text(
      '반복되는 현지 시각의 선택 필요',
      'A repeated wall time needs an occurrence choice',
    ),
    'nonexistent' => text('존재하지 않는 현지 시각', 'Nonexistent wall time'),
    'changed' => text('시간대 규칙 변경 확인 필요', 'Changed time zone rules need review'),
    'historicalUncertain' => text('역사적 순간 불확실', 'Historical instant uncertain'),
    _ => text('정확한 순간 확인 필요', 'The exact instant needs review'),
  };
  @override
  Widget build(BuildContext context) {
    final rule = _rule, review = _review;
    final enabled = !_busy && !_confirming && _receipt == null;
    final proof = review?.conflictProof;
    final conflicts = proof?.conflicts ?? [];
    final offset = _conflictPage * 10;
    final possible = proof?.possibleOverlaps ?? [];
    final possibleOffset = _possiblePage * 10;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          text('이 회차 이후 시간 확인', 'Review time from this occurrence'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (_anchor != null) Text(_anchor!.snapshot.schedule.scheduleName),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Text(_error!, key: const Key('recurring-time-error')),
        TextButton(
          key: const Key('reload-recurring-time'),
          onPressed: enabled ? _load : null,
          child: Text(text('최신 기록 다시 확인', 'Review latest record')),
        ),
        if (rule != null) ...[
          ListTile(
            key: const Key('recurring-time-date'),
            title: Text(recurrenceDate(context, rule.start)),
            subtitle: Text(text('날짜 변경', 'Change date')),
            onTap: enabled ? () => _pickCivil(true) : null,
          ),
          TextButton(
            key: const Key('recurring-time-clock'),
            onPressed: enabled ? () => _pickCivil(false) : null,
            child: Text(text('시각 변경', 'Change time')),
          ),
          ListTile(
            key: const Key('recurring-time-zone'),
            title: Text(rule.timeZoneId),
            subtitle: Text(
              text(
                '현지 시각을 유지하고 시간대 선택',
                'Choose a zone while preserving wall time',
              ),
            ),
            onTap: enabled ? _pickZone : null,
          ),
          Text(recurrenceLabel(context, rule)),
          TextButton(
            key: const Key('recurring-time-rule'),
            onPressed: enabled ? _pickRule : null,
            child: Text(
              text('반복·종료 조건 확인', 'Review recurrence and end condition'),
            ),
          ),
          Text(
            text(
              '두 번 발생하는 시각의 회차 선택',
              'Occurrence choice when wall time repeats',
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final value in RepeatedCivilTime.values)
                ChoiceChip(
                  label: Text(
                    value == RepeatedCivilTime.first
                        ? text('첫 번째', 'First')
                        : text('두 번째', 'Second'),
                  ),
                  selected: rule.repeatedTime == value,
                  onSelected: enabled
                      ? (_) => setState(() {
                          final r = _changedRule(
                            repeated: value,
                            replaceRepeated: true,
                          );
                          _invalidate();
                          _rule = r;
                          _excluded = {};
                        })
                      : null,
                ),
            ],
          ),
          FilledButton(
            key: const Key('build-recurring-time-plan'),
            onPressed: enabled && TimeZoneRules.contains(rule.timeZoneId)
                ? _buildPlan
                : null,
            child: Text(text('전체 계획 검토', 'Review complete plan')),
          ),
        ],
        if (review != null) ...[
          RecurringTimeCorrectionPlanSummary(
            mapping: review.mapping,
            unresolvedOverrides: review.unresolvedOverrides,
            confirmedDetachedIds: _detached,
            confirmedUnmatchedExclusions: _unmatched,
            enabled: enabled,
            onDetachedChanged: (v) => setState(() {
              _detached = v;
              _command = null;
            }),
            onUnmatchedExclusionsChanged: (v) => setState(() {
              _unmatched = v;
              _command = null;
            }),
            onResolveOverride: _resolveOne,
          ),
          if (conflicts.isNotEmpty) ...[
            Text(text('확정된 충돌을 해결해야 해요', 'Resolve confirmed overlaps')),
            for (final conflict in conflicts.skip(offset).take(10))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${recurrenceDate(context, conflict.slot.civilTime)} · ${review.mapping.rule.timeZoneId}\n${conflict.other.schedule.scheduleName}\n${recurrenceDate(context, conflict.other.schedule.scheduleTime)} · ${conflict.other.schedule.timeZoneId}',
                      ),
                      if (conflict.persistent)
                        Text(
                          text(
                            '반복되는 충돌이에요. 규칙을 변경해주세요.',
                            'This overlap repeats indefinitely. Change the rule.',
                          ),
                        )
                      else
                        TextButton(
                          onPressed: enabled
                              ? () => _buildPlan(
                                  excluded: {..._excluded, conflict.slot.key},
                                )
                              : null,
                          child: Text(
                            text(
                              '새 규칙에서 이 회차 제외·기존 일정은 단발 보존',
                              'Exclude this new slot; preserve an existing appointment as standalone',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            if (conflicts.length > 10)
              Row(
                children: [
                  TextButton(
                    onPressed: _conflictPage > 0
                        ? () => setState(() => _conflictPage--)
                        : null,
                    child: Text(text('이전', 'Previous')),
                  ),
                  Text(
                    '${offset + 1}–${(offset + 10).clamp(0, conflicts.length)} / ${conflicts.length}',
                  ),
                  TextButton(
                    onPressed: offset + 10 < conflicts.length
                        ? () => setState(() => _conflictPage++)
                        : null,
                    child: Text(text('다음', 'Next')),
                  ),
                ],
              ),
          ],
          if (review.mapping.conflictExclusions.isNotEmpty)
            Text(
              text(
                '명시적으로 제외한 새 회차: ${review.mapping.conflictExclusions.length}개. 이 회차도 반복 횟수를 소비합니다.',
                'Explicitly excluded new slots: ${review.mapping.conflictExclusions.length}. These slots still consume the recurrence count.',
              ),
            ),
          if (proof != null && proof.possibleOverlaps.isNotEmpty) ...[
            Text(
              text(
                '다음 일정은 정확한 충돌 판정이 불가능해요. 해당 일정의 새 시작·알림은 보류되며 개별 교정 때 다시 검사합니다.',
                'Exact overlap is uncertain for these appointments. Their new starts and alarms remain on hold and their individual corrections will recheck overlaps.',
              ),
            ),
            // One acknowledgement covers the exact complete list of identities;
            // no per-row widget expansion is needed for a large candidate set.
            Text(
              '${proof.possibleOverlaps.length} ${text('개 영향 항목', 'possible impacts')}',
            ),
            for (final impact in possible.skip(possibleOffset).take(10))
              Text(
                '${impact.name}\n${impact.originalCivil == null ? '' : recurrenceDate(context, impact.originalCivil!)} · ${impact.timeZoneId ?? ''}\n${_reason(impact.reason)}${impact.rule == null ? '' : '\n${recurrenceLabel(context, impact.rule!)} · ${recurrenceEndLabel(context, impact.rule!)}'}',
              ),
            if (possible.length > 10)
              Row(
                children: [
                  TextButton(
                    key: const Key('possible-overlap-previous'),
                    onPressed: _possiblePage > 0
                        ? () => setState(() => _possiblePage--)
                        : null,
                    child: Text(text('이전', 'Previous')),
                  ),
                  Text(
                    '${possibleOffset + 1}–${(possibleOffset + 10).clamp(0, possible.length)} / ${possible.length}',
                  ),
                  TextButton(
                    key: const Key('possible-overlap-next'),
                    onPressed: possibleOffset + 10 < possible.length
                        ? () => setState(() => _possiblePage++)
                        : null,
                    child: Text(text('다음', 'Next')),
                  ),
                ],
              ),
            CheckboxListTile(
              key: const Key('ack-recurring-uncertain'),
              value:
                  _uncertain.length ==
                  proof.possibleOverlaps.map((e) => e.id).toSet().length,
              onChanged: enabled
                  ? (value) => setState(() {
                      _uncertain = value == true
                          ? proof.possibleOverlaps.map((e) => e.id).toSet()
                          : {};
                      _command = null;
                    })
                  : null,
              title: Text(
                text(
                  '미확정 일정의 실행 보류와 후속 재검증을 확인했어요',
                  'I acknowledge withheld execution and later revalidation for uncertain appointments',
                ),
              ),
            ),
          ],
          FilledButton(
            key: const Key('review-recurring-time-confirm'),
            onPressed: _canConfirm ? _confirm : null,
            child: Text(text('변경 내용 확인', 'Review changes')),
          ),
        ],
        if (_receipt?.deliveryPending ?? false) ...[
          Text(
            text(
              '저장은 완료됐고 알림 동기화가 남아 있어요.',
              'Saved; notification synchronization is still pending.',
            ),
          ),
          TextButton(
            onPressed: _busy ? null : _retryDelivery,
            child: Text(
              text('알림 동기화 재시도', 'Retry notification synchronization'),
            ),
          ),
        ],
      ],
    );
  }
}
