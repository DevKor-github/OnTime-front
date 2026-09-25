import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:on_time_front/domain/entities/backup_recurring_time_review.dart';
import 'package:on_time_front/domain/entities/backup_time_review.dart';
import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'package:on_time_front/domain/recurrence/recurring_time_correction.dart';
import 'package:on_time_front/presentation/recurring/recurrence_labels.dart';
import 'package:on_time_front/presentation/recurring/recurrence_settings_sheet.dart';
import 'package:on_time_front/presentation/recurring/recurring_time_correction_plan_summary.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_date_time/screens/schedule_time_zone_picker.dart';
import 'package:on_time_front/presentation/shared/components/civil_date_time_picker.dart';

/// Borrows an authenticated candidate. This route never disposes it, creates a
/// ready input, or replaces app data. The parent revalidates after this returns.
class BackupRecurringTimeReviewScreen extends StatefulWidget {
  const BackupRecurringTimeReviewScreen({
    super.key,
    required this.input,
    required this.issue,
  });
  final BackupTimeReviewInput input;
  final BackupTimeReviewIssue issue;
  @override
  State<BackupRecurringTimeReviewScreen> createState() =>
      _BackupRecurringTimeReviewScreenState();
}

class _BackupRecurringTimeReviewScreenState
    extends State<BackupRecurringTimeReviewScreen> {
  RecurrenceRule? _rule;
  BackupRecurringTimePlan? _plan;
  Set<String> _excluded = {}, _detached = {}, _unmatched = {}, _possible = {};
  bool _busy = false,
      _saving = false,
      _confirming = false,
      _explicitEnd = false;
  bool _returning = false;
  bool _needsWhole = false, _wholeRequested = false, _wholeConfirmed = false;
  int _owner = 0, _draft = 0, _conflictPage = 0, _possiblePage = 0;
  String? _error;
  String text(String ko, String en) => recurrenceText(context, ko, en);
  BackupRecurringTimeReviewPort? get _port =>
      widget.input is BackupRecurringTimeReviewPort
      ? widget.input as BackupRecurringTimeReviewPort
      : null;
  bool owns(int owner, int draft) =>
      mounted && _owner == owner && _draft == draft;
  bool get _enabled => !_busy && !_saving && !_confirming && !_returning;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(BackupRecurringTimeReviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.input != widget.input || oldWidget.issue != widget.issue) {
      _load();
    }
  }

  @override
  void dispose() {
    _owner++;
    super.dispose();
  }

  void _invalidate() {
    _draft++;
    _plan = null;
    _detached = {};
    _unmatched = {};
    _possible = {};
    _wholeConfirmed = false;
    _conflictPage = 0;
    _possiblePage = 0;
    _error = null;
  }

  Future<void> _load() async {
    final owner = ++_owner;
    setState(() {
      _invalidate();
      _busy = true;
      _saving = false;
      _returning = false;
      _confirming = false;
      _rule = null;
      _excluded = {};
      _explicitEnd = false;
      _needsWhole = false;
      _wholeRequested = false;
    });
    final draft = _draft;
    final input = widget.input;
    final summary = input.summary;
    try {
      final port = _port;
      if (port == null) throw const BackupTimeReviewStale();
      final rule = await port.recurrenceRule(widget.issue.id);
      if (!owns(owner, draft)) return;
      final current = input.summary;
      if (summary.identity != current.identity ||
          summary.revision != current.revision ||
          summary.rulesIdentity != current.rulesIdentity) {
        throw const BackupTimeReviewStale();
      }
      setState(() {
        _rule = rule;
        _busy = false;
      });
    } catch (_) {
      if (owns(owner, draft)) {
        setState(() {
          _busy = false;
          _error = text(
            '반복 규칙을 읽지 못했어요. 상위 검토로 돌아가 전체 백업을 다시 확인해주세요.',
            'The recurrence rule could not be read. Return to the parent review and validate the entire backup again.',
          );
        });
      }
    }
  }

  RecurrenceRule _changedRule({
    DateTime? start,
    String? zone,
    RepeatedCivilTime? repeated,
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
      count: r.count,
      until: r.until,
      repeatedTime: repeated ?? r.repeatedTime,
    );
  }

  Future<void> _pickCivil(bool dateOnly) async {
    final owner = _owner, draft = _draft;
    final value = await showCivilDateTimePicker(
      context: context,
      initialCivil: _rule!.start,
      dateOnly: dateOnly,
      title: text('새 반복 시작', 'New recurrence start'),
    );
    if (value == null || !owns(owner, draft)) return;
    try {
      final rule = _changedRule(start: value);
      setState(() {
        _invalidate();
        _rule = rule;
        _excluded = {};
      });
    } catch (_) {
      setState(
        () => _error = text(
          '시작과 종료 조건을 확인해주세요.',
          'Check the start and end conditions.',
        ),
      );
    }
  }

  Future<void> _pickZone() async {
    final owner = _owner, draft = _draft;
    final value = await showScheduleTimeZonePicker(
      context: context,
      currentZone: _rule!.timeZoneId,
      civil: _rule!.start,
      offsetSeconds: null,
      isCurrent: () => owns(owner, draft),
    );
    if (value == null || !owns(owner, draft)) return;
    setState(() {
      final rule = _changedRule(zone: value);
      _invalidate();
      _rule = rule;
      _excluded = {};
    });
  }

  Future<void> _pickRule() async {
    final owner = _owner, draft = _draft;
    final result = await showModalBottomSheet<RecurrenceSettingsResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => RecurrenceSettingsSheet(
        start: _rule!.start,
        timeZoneId: _rule!.timeZoneId,
        initial: _rule,
        allowNone: false,
      ),
    );
    if (!owns(owner, draft) || result?.rule == null) return;
    setState(() {
      _invalidate();
      _rule = result!.rule;
      _explicitEnd = true;
      _excluded = {};
    });
  }

  Future<void> _review({Set<String>? excluded}) async {
    if (!_enabled || _rule == null || _port == null) return;
    setState(() {
      _invalidate();
      _busy = true;
      if (excluded != null) _excluded = Set.of(excluded);
    });
    final owner = _owner, draft = _draft;
    final summary = widget.input.summary;
    try {
      final plan = await _port!.reviewRecurrence(
        BackupRecurringTimeDraft(
          identity: summary.identity,
          revision: summary.revision,
          rulesIdentity: summary.rulesIdentity,
          issueId: widget.issue.id,
          rule: _rule!,
          endExplicitlyChosen: _explicitEnd,
          replaceWholeSourceInterval: _wholeRequested,
          excludedConflictSlots: _excluded,
        ),
      );
      if (!owns(owner, draft)) return;
      setState(() {
        _plan = plan;
        _busy = false;
      });
    } on BackupRecurringWholeReplacementRequired {
      if (owns(owner, draft)) {
        setState(() {
          _busy = false;
          _needsWhole = true;
          _wholeRequested = false;
          _error = text(
            '기준 회차 앞에도 시간대가 미확정인 미래 구간이 남아 있어요. 원 생성 구간 전체 교체 여부를 직접 선택하고 다시 검토해주세요.',
            'Unresolved future generation remains before the anchor. Explicitly choose whether to replace the whole original interval, then review again.',
          );
        });
      }
    } on RecurringTimeCorrectionCountRequired {
      if (owns(owner, draft)) {
        setState(() {
          _busy = false;
          _error = text(
            '반복 횟수나 종료 날짜를 직접 선택해야 해요. 반복·종료 설정을 열어주세요.',
            'Explicitly choose an occurrence count or end date in recurrence settings.',
          );
        });
      }
    } catch (_) {
      if (owns(owner, draft)) {
        setState(() {
          _busy = false;
          _error = text(
            '전체 계획을 검증하지 못했어요. 규칙을 수정하거나 상위 검토로 돌아가 다시 확인해주세요.',
            'The entire plan could not be verified. Adjust the rule or return to the parent review.',
          );
        });
      }
    }
  }

  bool get _canChoose {
    final p = _plan;
    if (!_enabled ||
        p == null ||
        p.conflicts.conflicts.isNotEmpty ||
        p.unresolvedOverrides.isNotEmpty ||
        (p.replacesWholeSourceInterval && !_wholeConfirmed)) {
      return false;
    }
    const equality = SetEquality<String>();
    return equality.equals(
          _detached,
          p.mapping.rows
              .where((r) => r.detached)
              .map((r) => r.original.id)
              .toSet(),
        ) &&
        equality.equals(
          _unmatched,
          p.mapping.exclusions
              .where((r) => r.slot == null)
              .map(
                (r) =>
                    RecurringTimeCorrectionPlanSummary.exclusionKey(r.original),
              )
              .toSet(),
        ) &&
        equality.equals(
          _possible,
          p.conflicts.possibleOverlaps.map((r) => r.id).toSet(),
        );
  }

  Future<void> _choose() async {
    if (!_canChoose) return;
    final owner = _owner, draft = _draft, plan = _plan!;
    final port = _port!;
    final choice = BackupRecurringTimeChoice(
      plan: plan,
      confirmedDetachedIds: _detached,
      confirmedUnmatchedExclusions: _unmatched,
      acknowledgedPossibleIds: _possible,
      confirmedWholeSourceReplacement: _wholeConfirmed,
    );
    setState(() => _confirming = true);
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(text('반복 변경을 확인할까요?', 'Confirm recurrence changes?')),
        content: Text(
          text(
            '검토한 회차 연결, 단발 보존, 제외 및 불확실 영향만 백업 후보에 반영합니다. 현재 앱 데이터는 바뀌지 않습니다. 상위 화면에서 백업 전체를 다시 검증한 후 별도로 복원을 확인해야 합니다.',
            'Apply only the reviewed associations, standalone records, exclusions and uncertain impacts to the backup candidate. Current app data is unchanged. The parent must validate the whole backup and separately confirm restoration.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(text('돌아가기', 'Back')),
          ),
          FilledButton(
            key: const Key('confirm-backup-recurrence-choice'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(text('후보에 반영', 'Apply to candidate')),
          ),
        ],
      ),
    );
    if (!owns(owner, draft)) return;
    setState(() => _confirming = false);
    if (yes != true) return;
    setState(() => _saving = true);
    try {
      await port.chooseRecurrence(choice);
      if (!owns(owner, draft)) return;
      setState(() {
        _saving = false;
        _returning = true;
      });
      // PopScope must rebuild before the programmatic return. Retire this
      // callback if the widget's candidate or issue changes in that frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (owns(owner, draft)) Navigator.of(context).pop();
      });
    } catch (_) {
      if (owns(owner, draft)) {
        setState(() {
          _saving = false;
          _invalidate();
          _error = text(
            '이 계획을 확인할 수 없어요. 상위 검토로 돌아가 백업 전체를 다시 검증해주세요.',
            'This plan could not be confirmed. Return to the parent review and validate the entire backup again.',
          );
        });
      }
    }
  }

  String civil(DateTime value) =>
      CivilDateTime.fromFields(value).toCivilIso8601String();
  @override
  Widget build(BuildContext context) {
    final rule = _rule, p = _plan;
    final conflicts = p?.conflicts.conflicts ?? [];
    final possible = p?.conflicts.possibleOverlaps ?? [];
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(text('백업 반복 시간 검토', 'Review backup recurrence')),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                text(
                  '반복 일정의 새 시각과 변경 영향을 확인해주세요. 이 단계에서는 현재 앱 데이터를 바꾸지 않습니다.',
                  'Review the new recurrence times and their effects. Current app data is unchanged at this step.',
                ),
              ),
              if (_busy || _saving) const LinearProgressIndicator(),
              if (_error != null)
                Text(
                  _error!,
                  key: const Key('backup-recurrence-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (rule != null) ...[
                Text(
                  '${civil(rule.start)} · ${rule.timeZoneId}\n${recurrenceLabel(context, rule)} · ${recurrenceEndLabel(context, rule)}',
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      key: const Key('backup-recurrence-date'),
                      onPressed: _enabled ? () => _pickCivil(true) : null,
                      child: Text(text('시작 날짜', 'Start date')),
                    ),
                    TextButton(
                      key: const Key('backup-recurrence-clock'),
                      onPressed: _enabled ? () => _pickCivil(false) : null,
                      child: Text(text('시작 시각', 'Start time')),
                    ),
                  ],
                ),
                TextButton(
                  key: const Key('backup-recurrence-zone'),
                  onPressed: _enabled ? _pickZone : null,
                  child: Text(text('시간대 선택', 'Choose time zone')),
                ),
                TextButton(
                  key: const Key('backup-recurrence-rule'),
                  onPressed: _enabled ? _pickRule : null,
                  child: Text(
                    text('반복·종료 직접 선택', 'Choose recurrence and end condition'),
                  ),
                ),
                Text(
                  text(
                    '두 번 나타나는 시각의 발생 순서',
                    'Occurrence when a local time repeats',
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final value in RepeatedCivilTime.values)
                      ChoiceChip(
                        key: ValueKey('backup-recurrence-repeat-${value.name}'),
                        label: Text(
                          value == RepeatedCivilTime.first
                              ? text('첫 번째', 'First')
                              : text('두 번째', 'Second'),
                        ),
                        selected: rule.repeatedTime == value,
                        onSelected: _enabled
                            ? (_) {
                                setState(() {
                                  final next = _changedRule(repeated: value);
                                  _invalidate();
                                  _rule = next;
                                  _excluded = {};
                                });
                              }
                            : null,
                      ),
                  ],
                ),
                if (_needsWhole)
                  CheckboxListTile(
                    key: const Key('request-backup-recurrence-whole'),
                    contentPadding: EdgeInsets.zero,
                    value: _wholeRequested,
                    onChanged: _enabled
                        ? (value) => setState(() {
                            _invalidate();
                            _excluded = {};
                            _wholeRequested = value == true;
                          })
                        : null,
                    title: Text(
                      text(
                        '해당 원 생성 구간 전체를 교체하는 계획을 검토할게요. 기준 회차 앞의 미생성 구간도 포함됩니다.',
                        'Review replacing this entire original interval, including unmaterialized occurrences before the anchor.',
                      ),
                    ),
                  ),
                FilledButton(
                  key: const Key('review-backup-recurrence'),
                  onPressed: _enabled ? () => _review() : null,
                  child: Text(text('전체 계획 검토', 'Review complete plan')),
                ),
              ],
              if (p != null) ...[
                const Divider(),
                Text(
                  '${text('원래 규칙', 'Original rule')}: ${recurrenceLabel(context, p.originalRule)} · ${p.originalRule.timeZoneId} · ${recurrenceEndLabel(context, p.originalRule)}',
                ),
                Text(
                  '${text('원 생성 구간', 'Original interval')}: ${civil(p.originalFrom)} → ${p.originalBefore == null ? text('끝 없음', 'No end') : civil(p.originalBefore!)}\n${text('폐쇄 경계', 'Close at')}: ${civil(p.closeAt)}',
                ),
                Text(
                  p.anchor.scheduleId == null
                      ? text(
                          '기존 개별 일정 0개: 앞으로 생성할 반복 일정의 시작과 종료 조건을 확인해주세요.',
                          '0 existing appointments: review the start and end conditions of future recurring appointments.',
                        )
                      : '${text('기준 회차', 'Anchor occurrence')}: ${civil(p.anchor.originalSlot)} · #${p.anchor.originalOrdinal}',
                ),
                if (p.mapping.firstSlot != null)
                  Text(
                    '${text('새 규칙의 첫 회차(제외 전)', 'First rule occurrence (before exclusions)')}: ${civil(p.mapping.firstSlot!.civilTime)} · ${p.mapping.rule.timeZoneId}\n${p.mapping.firstSlot!.instantUtc.toIso8601String()}',
                  ),
                if (p.conflicts.earliestPreparationUtc != null)
                  Text(
                    '${text('가장 이른 준비 시작', 'Earliest preparation start')}: ${p.conflicts.earliestPreparationUtc!.toIso8601String()}',
                  ),
                if (p.replacesWholeSourceInterval)
                  CheckboxListTile(
                    key: const Key('confirm-backup-recurrence-whole'),
                    contentPadding: EdgeInsets.zero,
                    value: _wholeConfirmed,
                    onChanged: _enabled
                        ? (value) =>
                              setState(() => _wholeConfirmed = value == true)
                        : null,
                    title: Text(
                      text(
                        '표시된 원 구간 전체에서 기존 규칙의 생성이 끝나며, 기준 회차 앞 미생성 일정도 새 규칙으로 바뀌는 영향을 확인했어요.',
                        'I understand that generation by the old rule ends throughout the shown interval, including unmaterialized appointments before the anchor.',
                      ),
                    ),
                  ),
                RecurringTimeCorrectionPlanSummary(
                  mapping: p.mapping,
                  unresolvedOverrides: p.unresolvedOverrides,
                  confirmedDetachedIds: _detached,
                  confirmedUnmatchedExclusions: _unmatched,
                  enabled: _enabled,
                  onDetachedChanged: (value) =>
                      setState(() => _detached = value),
                  onUnmatchedExclusionsChanged: (value) =>
                      setState(() => _unmatched = value),
                  onResolveOverride: (_) {
                    if (_enabled) Navigator.of(context).pop();
                  },
                ),
                if (p.unresolvedOverrides.isNotEmpty)
                  Text(
                    text(
                      '상위 시간 검토로 돌아가 표시된 일정의 시각을 먼저 선택한 뒤 반복 규칙을 다시 검토해주세요.',
                      'Return to the parent time review, choose the times of the listed appointments, then review this rule again.',
                    ),
                  ),
                if (conflicts.isNotEmpty) ...[
                  Text(
                    text('확인된 겹침을 해결해주세요.', 'Resolve the confirmed overlaps.'),
                  ),
                  for (final conflict
                      in conflicts.skip(_conflictPage * 10).take(10))
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${civil(conflict.slot.civilTime)} · ${p.mapping.rule.timeZoneId}\n${conflict.other.schedule.scheduleName}',
                            ),
                            if (conflict.persistent)
                              Text(
                                text(
                                  '계속 반복되는 겹침입니다. 규칙을 변경해주세요.',
                                  'This overlap repeats indefinitely. Change the rule.',
                                ),
                              )
                            else
                              TextButton(
                                key: ValueKey(
                                  'exclude-backup-slot-${conflict.slot.key}',
                                ),
                                onPressed: _enabled
                                    ? () => _review(
                                        excluded: {
                                          ..._excluded,
                                          conflict.slot.key,
                                        },
                                      )
                                    : null,
                                child: Text(
                                  text(
                                    '새 회차 제외·기존 일정은 단발 보존',
                                    'Exclude new slot; preserve existing appointment as standalone',
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  _pages(
                    'conflict',
                    conflicts.length,
                    _conflictPage,
                    (value) => setState(() => _conflictPage = value),
                  ),
                ],
                if (possible.isNotEmpty) ...[
                  Text(
                    text(
                      '겹침이 불확실한 일정 ${possible.length}개',
                      '${possible.length} appointments with uncertain overlap',
                    ),
                  ),
                  for (final item in possible.skip(_possiblePage * 10).take(10))
                    Text(
                      '${item.name}\n${item.originalCivil == null ? '' : civil(item.originalCivil!)} · ${item.timeZoneId ?? ''}',
                    ),
                  _pages(
                    'possible',
                    possible.length,
                    _possiblePage,
                    (value) => setState(() => _possiblePage = value),
                  ),
                  CheckboxListTile(
                    key: const Key('ack-backup-recurrence-possible'),
                    contentPadding: EdgeInsets.zero,
                    value: _possible.isNotEmpty,
                    onChanged: _enabled
                        ? (value) => setState(
                            () => _possible = value == true
                                ? possible.map((p) => p.id).toSet()
                                : {},
                          )
                        : null,
                    title: Text(
                      text(
                        '표시된 미확정 영향 전체를 확인했어요. 남은 문제를 해결하기 전에는 복원할 수 없어요.',
                        'I acknowledge all listed uncertain impacts. Remaining issues must be resolved before restoration.',
                      ),
                    ),
                  ),
                ],
                FilledButton(
                  key: const Key('choose-backup-recurrence'),
                  onPressed: _canChoose ? _choose : null,
                  child: Text(text('변경 내용 확인', 'Confirm changes')),
                ),
              ],
              TextButton(
                key: const Key('cancel-backup-recurrence'),
                onPressed: _saving || _confirming || _returning
                    ? null
                    : () => Navigator.of(context).pop(),
                child: Text(text('상위 검토로 돌아가기', 'Return to parent review')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pages(String kind, int count, int page, ValueChanged<int> changed) =>
      count <= 10
      ? const SizedBox.shrink()
      : Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              key: ValueKey('backup-recurrence-$kind-previous'),
              onPressed: _enabled && page > 0 ? () => changed(page - 1) : null,
              child: Text(text('이전', 'Previous')),
            ),
            Text(
              '${page * 10 + 1}–${(page * 10 + 10).clamp(0, count)} / $count',
            ),
            TextButton(
              key: ValueKey('backup-recurrence-$kind-next'),
              onPressed: _enabled && page * 10 + 10 < count
                  ? () => changed(page + 1)
                  : null,
              child: Text(text('다음', 'Next')),
            ),
          ],
        );
}
