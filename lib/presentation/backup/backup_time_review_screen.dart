import 'dart:async';
import 'package:on_time_front/domain/entities/time_correction_conflict.dart';
import 'package:flutter/material.dart';
import 'package:on_time_front/domain/entities/backup_operation.dart';
import 'package:on_time_front/domain/entities/backup_restore_selection.dart';
import 'package:on_time_front/domain/entities/backup_time_review.dart';
import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_date_time/screens/schedule_time_zone_picker.dart';
import 'package:on_time_front/presentation/shared/components/civil_date_time_picker.dart';

/// Returns a newly verified input, never applies it. The parent owns the final
/// replacement confirmation and also awaits idempotent selection cleanup.
class BackupTimeReviewScreen extends StatefulWidget {
  const BackupTimeReviewScreen({
    super.key,
    required this.input,
    this.onReviewRecurrence,
  });
  final BackupTimeReviewInput input;
  final Future<void> Function(BackupTimeReviewInput, BackupTimeReviewIssue)?
  onReviewRecurrence;
  @override
  State<BackupTimeReviewScreen> createState() => _BackupTimeReviewScreenState();
}

class _BackupTimeReviewScreenState extends State<BackupTimeReviewScreen> {
  late BackupTimeReviewInput _input;
  final _retired = <BackupRestoreSelection>[];
  BackupTimeReviewIssuePage? _page;
  BackupTimeReviewIssue? _selected;
  BackupTimeFieldReview? _field;
  CivilDateTime? _civil;
  String _zone = '';
  int? _offset;
  bool _possibleAcknowledged = false;
  String? _cursor, _error;
  final _previous = <String?>[];
  int _owner = 0, _draft = 0;
  bool _busy = false,
      _closing = false,
      _cleanupFailed = false,
      _allowPop = false;
  String text(String ko, String en) =>
      Localizations.localeOf(context).languageCode == 'ko' ? ko : en;
  bool owns(int owner) => mounted && owner == _owner && !_closing;

  @override
  void initState() {
    super.initState();
    _input = widget.input;
    _load();
  }

  @override
  void didUpdateWidget(BackupTimeReviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.input != widget.input) {
      _owner++;
      _retired.add(_input);
      _input = widget.input;
      _previous.clear();
      _cursor = null;
      _closing = false;
      _allowPop = false;
      _cleanupFailed = false;
      _load();
    }
  }

  @override
  void dispose() {
    _owner++;
    // The service retains failed cleanup in its lease. The parent awaits the
    // same cleanup, including forced route removal; no unhandled Future escapes.
    for (final selected in [..._retired, _input]) {
      unawaited(selected.dispose().catchError((Object _) {}));
    }
    super.dispose();
  }

  Future<void> _load() async {
    final owner = ++_owner;
    final input = _input;
    setState(() {
      _busy = true;
      _error = null;
      _page = null;
      _clearDraft();
    });
    try {
      for (final old in List<BackupRestoreSelection>.of(_retired)) {
        await old.dispose();
        _retired.remove(old);
      }
      final page = await input.issues(cursor: _cursor);
      if (!owns(owner)) return;
      setState(() {
        _page = page;
        _busy = false;
      });
    } catch (_) {
      if (!owns(owner)) return;
      setState(() {
        _busy = false;
        _cleanupFailed = _retired.isNotEmpty;
        _error = text(
          '검토 내용을 읽지 못했어요. 전체 검증을 다시 하거나 취소해주세요.',
          'Could not load this review. Validate again or cancel.',
        );
      });
    }
  }

  void _clearDraft() {
    _selected = null;
    _civil = null;
    _zone = '';
    _field = null;
    _offset = null;
    _possibleAcknowledged = false;
    _draft++;
  }

  void _edit(BackupTimeReviewIssue issue) {
    setState(() {
      _clearDraft();
      _selected = issue;
      _civil = issue.civil;
      _zone = issue.zone ?? '';
      _error = null;
    });
  }

  void _changed() {
    _draft++;
    _field = null;
    _offset = null;
    _possibleAcknowledged = false;
    _error = null;
  }

  Future<void> _pickCivil(bool dateOnly) async {
    final owner = _owner, draft = _draft;
    final value = await showCivilDateTimePicker(
      context: context,
      initialCivil: _civil!.toUtcCarrier(),
      dateOnly: dateOnly,
      title: text(dateOnly ? '날짜' : '시간', dateOnly ? 'Date' : 'Time'),
    );
    if (!owns(owner) || draft != _draft || value == null) return;
    setState(() {
      _civil = CivilDateTime.fromFields(value);
      _changed();
    });
  }

  Future<void> _pickZone() async {
    final owner = _owner, draft = _draft;
    final value = await showScheduleTimeZonePicker(
      context: context,
      currentZone: _zone,
      civil: _civil?.toUtcCarrier(),
      offsetSeconds: _offset,
      isCurrent: () => owns(owner) && draft == _draft,
    );
    if (!owns(owner) || draft != _draft || value == null) return;
    setState(() {
      _zone = value;
      _changed();
    });
  }

  Future<void> _reviewField() async {
    final owner = _owner, draft = _draft;
    final input = _input;
    final summary = input.summary;
    setState(() {
      _busy = true;
      _error = null;
      _field = null;
      _offset = null;
      _possibleAcknowledged = false;
    });
    try {
      final field = await input.review(
        BackupTimeDraft(
          identity: summary.identity,
          revision: summary.revision,
          rulesIdentity: summary.rulesIdentity,
          issueId: _selected!.id,
          civil: _civil!,
          zone: _zone,
        ),
      );
      if (!owns(owner) || draft != _draft) return;
      setState(() {
        _field = field;
        _busy = false;
      });
    } catch (_) {
      if (!owns(owner)) return;
      setState(() {
        _busy = false;
        _error = text(
          '이 시각을 확인하지 못했어요. 시간대를 선택하거나 전체 검증을 다시 해주세요.',
          'This time could not be reviewed. Choose a time zone or validate again.',
        );
      });
    }
  }

  String _offsetLabel(int offset) {
    final value = offset.abs();
    final hours = (value ~/ 3600).toString().padLeft(2, '0');
    final minutes = (value % 3600 ~/ 60).toString().padLeft(2, '0');
    final seconds = value % 60;
    return 'UTC${offset < 0 ? '-' : '+'}$hours:$minutes${seconds == 0 ? '' : ':${seconds.toString().padLeft(2, '0')}'}';
  }

  TimeCorrectionConflictProof? get _proof => _field?.conflictsByOffset[_offset];
  bool get _canChoose {
    if (_field == null || _offset == null) return false;
    if (_field!.issue.kind != BackupTimeFieldKind.scheduleOccurrence) {
      return true;
    }
    final proof = _proof;
    return proof != null &&
        proof.conflicts.isEmpty &&
        (proof.possibleOverlaps.isEmpty || _possibleAcknowledged);
  }

  Future<void> _confirm() async {
    if (!_canChoose) return;
    final owner = _owner, draft = _draft;
    final input = _input, field = _field!;
    final offset = _offset!;
    final acknowledged =
        _proof?.possibleOverlaps.map((item) => item.id).toSet() ?? <String>{};
    setState(() {
      _busy = true;
    });
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(text('이 시각을 선택할까요?', 'Use this time?')),
        content: Text(
          '${text('현재 기록', 'Current record')}\n${field.issue.currentLiteral}\n${field.issue.zone ?? text('시간대 미지정', 'No time zone')}\n\n${text('선택할 시각', 'Selected time')}\n${field.draft.civil.toCivilIso8601String()}\n${field.draft.zone} · ${_offsetLabel(offset)}\n\n${text('선택 후 백업 전체를 다시 검증합니다. 현재 앱 데이터는 아직 바뀌지 않습니다.', 'The entire backup will be validated again. Current app data is not replaced yet.')}\n\n${acknowledged.isEmpty ? '' : text('겹침이 불확실한 일정이 있다는 점을 확인했습니다. 남은 시간 문제를 해결해야 복원할 수 있습니다.', 'You acknowledged appointments with uncertain overlap. Remaining time issues must be resolved before restoring.')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(text('돌아가기', 'Back')),
          ),
          FilledButton(
            key: const Key('confirm-backup-time-choice'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(text('선택', 'Choose')),
          ),
        ],
      ),
    );
    if (!owns(owner) || draft != _draft) return;
    if (accepted != true) {
      setState(() {
        _busy = false;
      });
      return;
    }
    try {
      await input.choose(
        BackupTimeChoice(
          review: field,
          offsetSeconds: offset,
          acknowledgedPossibleIds: acknowledged,
        ),
      );
      if (!owns(owner)) return;
      await _validate();
    } catch (_) {
      if (!owns(owner)) return;
      setState(() {
        _busy = false;
        _field = null;
        _offset = null;
        _possibleAcknowledged = false;
        _error = text(
          '선택이 만료됐거나 저장되지 않았어요. 전체 검증을 다시 해주세요.',
          'The choice expired or could not be saved. Validate again.',
        );
      });
    }
  }

  Future<void> _validate() async {
    final owner = _owner;
    final input = _input;
    setState(() {
      _busy = true;
      _error = null;
      _clearDraft();
    });
    try {
      final selected = await input.revalidate();
      if (!owns(owner)) {
        await selected.dispose();
        return;
      }
      if (selected is BackupRestoreInput) {
        _finish(selected);
        return;
      }
      if (selected is! BackupTimeReviewInput) {
        await selected.dispose();
        throw const BackupTimeReviewStale();
      }
      if (selected != input) {
        _retired.add(input);
        _input = selected;
      }
      _cursor = null;
      _previous.clear();
      await _load();
    } catch (_) {
      if (!owns(owner)) return;
      setState(() {
        _busy = false;
        _error = text(
          '전체 검증을 완료하지 못했어요. 다시 검증하거나 취소 후 백업을 다시 선택해주세요.',
          'Full validation did not complete. Retry, or cancel and select the backup again.',
        );
      });
    }
  }

  Future<void> _recurrence(BackupTimeReviewIssue issue) async {
    final callback = widget.onReviewRecurrence;
    if (callback == null) return;
    final owner = _owner;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await callback(_input, issue);
      if (owns(owner)) await _validate();
    } catch (_) {
      if (owns(owner)) {
        setState(() {
          _busy = false;
          _error = text(
            '반복 규칙 검토를 완료하지 못했어요.',
            'Recurrence review did not complete.',
          );
        });
      }
    }
  }

  Future<void> _cancel() async {
    if (_closing) return;
    _owner++;
    setState(() {
      _closing = true;
      _busy = true;
      _error = null;
    });
    try {
      for (final old in List<BackupRestoreSelection>.of(_retired)) {
        await old.dispose();
        _retired.remove(old);
      }
      await _input.dispose();
      if (mounted) _finish(null);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _closing = false;
        _busy = false;
        _cleanupFailed = true;
        _error = text(
          '임시 데이터 정리를 완료하지 못했어요. 취소를 다시 눌러 정리를 재시도해주세요.',
          'Temporary data cleanup failed. Press Cancel again to retry cleanup.',
        );
      });
    }
  }

  void _finish(BackupRestoreInput? ready) {
    final owner = ++_owner;
    setState(() {
      _allowPop = true;
      _busy = true;
      _closing = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && owner == _owner) {
        Navigator.of(context).pop(ready);
      } else if (ready != null) {
        unawaited(ready.dispose().catchError((Object _) {}));
      }
    });
  }

  String _kind(BackupTimeFieldKind kind) => switch (kind) {
    BackupTimeFieldKind.scheduleOccurrence => text('일정 시각', 'Schedule time'),
    BackupTimeFieldKind.scheduleStartedAt => text('시작 기록', 'Start record'),
    BackupTimeFieldKind.scheduleFinishedAt => text(
      '완료 기록',
      'Completion record',
    ),
    BackupTimeFieldKind.templateCreatedAt => text(
      '템플릿 생성 시각',
      'Template creation time',
    ),
    BackupTimeFieldKind.templateUpdatedAt => text(
      '템플릿 수정 시각',
      'Template update time',
    ),
    BackupTimeFieldKind.recurrenceRule => text('반복 규칙', 'Recurrence rule'),
  };

  String _reason(BackupTimeIssueReason reason) => switch (reason) {
    BackupTimeIssueReason.unknownZone => text(
      '시간대를 찾을 수 없어요.',
      'The time zone is unavailable.',
    ),
    BackupTimeIssueReason.nonexistentCivil => text(
      '이 시간대에는 없는 시각이에요.',
      'This local time does not exist.',
    ),
    BackupTimeIssueReason.repeatedCivil => text(
      '두 번 나타나는 시각이에요. 어느 시각인지 선택해주세요.',
      'This time occurs twice. Choose an occurrence.',
    ),
    BackupTimeIssueReason.changedOffset => text(
      '저장된 UTC 오프셋과 현재 규칙이 달라요.',
      'The saved UTC offset differs from current rules.',
    ),
    BackupTimeIssueReason.missingInstantOffset => text(
      '절대시각을 확인하려면 시간대와 발생 시각을 선택해야 해요.',
      'Choose a time zone and occurrence to identify the instant.',
    ),
    BackupTimeIssueReason.recurrenceOrder => text(
      '반복 일정의 이후 회차를 검토해야 해요.',
      'Review the following recurrence occurrences.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final disabled = _busy || _cleanupFailed;
    final issue = _selected;
    return PopScope<BackupRestoreInput?>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(text('백업 시간 확인', 'Review backup times')),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                text(
                  '시간 정보를 확인한 뒤 백업 전체를 검증합니다. 이 화면에서는 현재 앱 데이터를 교체하지 않습니다.',
                  'Review the time information, then validate the entire backup. This screen does not replace current app data.',
                ),
              ),
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _error!,
                    key: const Key('backup-time-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_page != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    text(
                      '확인이 필요한 항목 ${_input.summary.issueCount}개',
                      '${_input.summary.issueCount} items need review',
                    ),
                  ),
                ),
                for (final item in _page!.items)
                  Card(
                    child: ListTile(
                      key: ValueKey('backup-time-issue-${item.id}'),
                      isThreeLine: false,
                      title: Text(
                        item.name.isEmpty ? _kind(item.kind) : item.name,
                      ),
                      subtitle: Text(
                        '${_kind(item.kind)}\n${_reason(item.reason)}\n${text('백업 원문', 'Original backup value')}: ${item.originalLiteral}\n${text('검토 중 값', 'Current value')}: ${item.currentLiteral}\n${item.zone ?? ''}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: disabled ? null : () => _edit(item),
                    ),
                  ),
                Wrap(
                  spacing: 8,
                  children: [
                    if (_previous.isNotEmpty)
                      TextButton(
                        key: const Key('backup-time-previous'),
                        onPressed: disabled
                            ? null
                            : () {
                                _cursor = _previous.removeLast();
                                _load();
                              },
                        child: Text(text('이전 항목', 'Previous items')),
                      ),
                    if (_page!.nextCursor != null)
                      TextButton(
                        key: const Key('backup-time-next'),
                        onPressed: disabled
                            ? null
                            : () {
                                _previous.add(_cursor);
                                _cursor = _page!.nextCursor;
                                _load();
                              },
                        child: Text(text('다음 항목', 'Next items')),
                      ),
                  ],
                ),
              ],
              if (issue != null) ...[
                const Divider(),
                Text(issue.name, style: Theme.of(context).textTheme.titleLarge),
                if (issue.kind == BackupTimeFieldKind.recurrenceRule) ...[
                  Text(
                    text(
                      '반복 규칙은 회차와 제외 기록을 함께 검토해야 합니다.',
                      'The rule, occurrences, and exclusions must be reviewed together.',
                    ),
                  ),
                  FilledButton(
                    key: const Key('backup-time-recurrence'),
                    onPressed: disabled || widget.onReviewRecurrence == null
                        ? null
                        : () => _recurrence(issue),
                    child: Text(text('반복 규칙 검토', 'Review recurrence')),
                  ),
                ] else ...[
                  if (issue.kind == BackupTimeFieldKind.scheduleOccurrence)
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          key: const Key('backup-time-date'),
                          onPressed: disabled ? null : () => _pickCivil(true),
                          child: Text(text('날짜 선택', 'Choose date')),
                        ),
                        TextButton(
                          key: const Key('backup-time-clock'),
                          onPressed: disabled ? null : () => _pickCivil(false),
                          child: Text(text('시간 선택', 'Choose time')),
                        ),
                      ],
                    ),
                  Text(_civil!.toCivilIso8601String()),
                  TextButton(
                    key: const Key('backup-time-zone'),
                    onPressed: disabled ? null : _pickZone,
                    child: Text(
                      _zone.isEmpty
                          ? text('시간대 선택', 'Choose time zone')
                          : _zone,
                    ),
                  ),
                  FilledButton(
                    key: const Key('review-backup-time-field'),
                    onPressed: disabled || _zone.isEmpty ? null : _reviewField,
                    child: Text(text('가능한 시각 확인', 'Review occurrences')),
                  ),
                  if (_field != null) ...[
                    if (_field!.choices.isEmpty)
                      Text(
                        text(
                          '이 시각은 존재하지 않습니다. 제안된 시각을 검토하거나 직접 변경해주세요.',
                          'This time does not exist. Review the suggestion or choose another time.',
                        ),
                      ),
                    if (_field!.nextValidCivil != null &&
                        issue.kind == BackupTimeFieldKind.scheduleOccurrence)
                      TextButton(
                        key: const Key('backup-time-gap-proposal'),
                        onPressed: disabled
                            ? null
                            : () {
                                setState(() {
                                  _civil = _field!.nextValidCivil;
                                  _changed();
                                });
                              },
                        child: Text(
                          '${text('제안 시각 검토', 'Review suggested time')}: ${_field!.nextValidCivil!.toCivilIso8601String()}',
                        ),
                      ),
                    for (final value in _field!.choices)
                      CheckboxListTile(
                        key: ValueKey(
                          'backup-time-offset-${value.offsetSeconds}',
                        ),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          '${_offsetLabel(value.offsetSeconds)}\n${value.instantUtc.toIso8601String()}',
                        ),
                        value: _offset == value.offsetSeconds,
                        onChanged: disabled
                            ? null
                            : (checked) {
                                setState(() {
                                  _possibleAcknowledged = false;
                                  _offset = checked == true
                                      ? value.offsetSeconds
                                      : null;
                                });
                              },
                      ),
                    if (_offset != null &&
                        issue.kind ==
                            BackupTimeFieldKind.scheduleOccurrence) ...[
                      if (_proof == null)
                        Text(
                          text(
                            '겹침 검증을 완료하지 못했어요. 가능한 시각을 다시 확인해주세요.',
                            'Overlap validation is missing. Review occurrences again.',
                          ),
                          key: const Key('backup-time-missing-proof'),
                        ),
                      if (_proof?.conflicts.isNotEmpty == true)
                        Text(
                          '${text('다른 일정 또는 준비 시간과 겹쳐요. 시간을 다시 선택해주세요.', 'This overlaps another appointment or its preparation. Choose another time.')}\n${_proof!.conflicts.map((item) => item.other.schedule.scheduleName).toSet().join(', ')}',
                          key: const Key('backup-time-known-conflict'),
                        ),
                      if (_proof?.possibleOverlaps.isNotEmpty == true) ...[
                        Text(
                          text(
                            '다음 일정은 정확한 겹침을 아직 확인할 수 없어요.',
                            'Exact overlap is still uncertain for these appointments.',
                          ),
                        ),
                        for (final item in _proof!.possibleOverlaps)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              '${item.name}\n${item.originalCivil == null ? '' : CivilDateTime.fromFields(item.originalCivil!).toCivilIso8601String()} · ${item.timeZoneId ?? ''}',
                            ),
                          ),
                        CheckboxListTile(
                          key: const Key('backup-time-possible-ack'),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _possibleAcknowledged,
                          onChanged: disabled
                              ? null
                              : (value) => setState(
                                  () => _possibleAcknowledged = value == true,
                                ),
                          title: Text(
                            text(
                              '겹침이 불확실한 일정이 있음을 확인했어요. 남은 시간 문제를 해결해야 복원할 수 있어요.',
                              'I understand that overlap is uncertain. Remaining time issues must be resolved before restoring.',
                            ),
                          ),
                        ),
                      ],
                    ],
                    FilledButton(
                      key: const Key('choose-backup-time-field'),
                      onPressed: disabled || !_canChoose ? null : _confirm,
                      child: Text(text('이 시각 선택', 'Choose this occurrence')),
                    ),
                  ],
                ],
              ],
              const SizedBox(height: 16),
              OutlinedButton(
                key: const Key('revalidate-backup-time'),
                onPressed: disabled ? null : _validate,
                child: Text(text('전체 다시 검증', 'Validate entire backup')),
              ),
              TextButton(
                key: const Key('cancel-backup-time'),
                onPressed: _closing ? null : _cancel,
                child: Text(text('취소', 'Cancel')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
