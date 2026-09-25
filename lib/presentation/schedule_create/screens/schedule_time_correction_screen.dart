import 'package:collection/collection.dart';
import 'package:on_time_front/domain/entities/time_correction_conflict.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:on_time_front/core/time/civil_time_resolver.dart';
import 'package:on_time_front/core/time/time_zone_rules.dart';
import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'package:on_time_front/domain/entities/schedule_save.dart';
import 'package:on_time_front/domain/entities/schedule_time_correction.dart';
import 'package:on_time_front/domain/entities/schedule_time_resolution.dart';
import 'package:on_time_front/domain/use-cases/schedule_time_correction_workflow.dart';
import 'package:on_time_front/presentation/recurring/recurrence_labels.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_date_time/screens/schedule_time_zone_picker.dart';
import 'package:on_time_front/presentation/shared/components/civil_date_time_picker.dart';

/// A dedicated review does not expose normal aggregate editing permissions.
class ScheduleTimeCorrectionScreen extends StatefulWidget {
  const ScheduleTimeCorrectionScreen({
    super.key,
    required this.scheduleId,
    required this.workflow,
    this.onSaved,
  });
  final String scheduleId;
  final ScheduleTimeCorrectionWorkflow workflow;
  final VoidCallback? onSaved;

  @override
  State<ScheduleTimeCorrectionScreen> createState() =>
      _ScheduleTimeCorrectionScreenState();
}

class _ScheduleTimeCorrectionScreenState
    extends State<ScheduleTimeCorrectionScreen> {
  ScheduleTimeCorrectionReview? _review;
  DateTime? _civil;
  String _zone = '';
  int? _offset;
  List<CivilTimeOccurrence> _choices = const [];
  ScheduleSaveReceipt? _receipt;
  ScheduleTimeCorrectionCommand? _command;
  ScheduleTimeCorrectionCommand? _confirmedCommand;
  String? _confirmedComparison;
  bool _busy = false;
  bool _confirming = false;
  bool _needsReview = false;
  bool _failed = false;
  ScheduleSaveFailure? _failure;
  List<TimeCorrectionConflict> _conflicts = const [];
  int _owner = 0;
  int _selection = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ScheduleTimeCorrectionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scheduleId != widget.scheduleId ||
        oldWidget.workflow != widget.workflow) {
      _load();
    }
  }

  bool _owns(int owner, [int? selection]) =>
      mounted &&
      owner == _owner &&
      (selection == null || selection == _selection);

  Future<void> _load() async {
    final owner = ++_owner;
    setState(() {
      _busy = true;
      _review = null;
      _receipt = null;
      _command = null;
      _confirmedCommand = null;
      _confirmedComparison = null;
      _confirming = false;
      _needsReview = false;
      _failed = false;
      _failure = null;
      _conflicts = const [];
    });
    try {
      final review = await widget.workflow.repository.review(widget.scheduleId);
      if (!_owns(owner)) return;
      setState(() {
        _review = review;
        _civil = CivilDateTime.fromFields(
          review.snapshot.schedule.scheduleTime,
        ).toUtcCarrier();
        _zone = review.snapshot.schedule.timeZoneId;
        _offset = review.snapshot.schedule.occurrenceOffsetSeconds;
        _resolve();
        _busy = false;
      });
    } catch (_) {
      if (!_owns(owner)) return;
      setState(() {
        _busy = false;
        _failed = true;
      });
    }
  }

  void _resolve() {
    _selection++;
    _command = null;
    _confirmedCommand = null;
    _confirmedComparison = null;
    _choices = _civil != null && TimeZoneRules.contains(_zone)
        ? CivilTimeResolver.resolve(_civil!, _zone)
        : const [];
    if (!_choices.any((value) => value.offsetSeconds == _offset)) {
      _offset = _choices.length == 1 ? _choices.single.offsetSeconds : null;
    }
    _failure = null;
    _conflicts = const [];
    _failed = false;
  }

  Future<void> _pickCivil(bool dateOnly) async {
    final owner = _owner, selection = _selection;
    final result = await showCivilDateTimePicker(
      context: context,
      initialCivil: _civil!,
      dateOnly: dateOnly,
      title: recurrenceText(
        context,
        dateOnly ? '날짜' : '시간',
        dateOnly ? 'Date' : 'Time',
      ),
    );
    if (result == null || !_owns(owner, selection)) return;
    setState(() {
      _civil = result;
      _offset = null;
      _resolve();
    });
  }

  Future<void> _pickZone() async {
    final owner = _owner, selection = _selection;
    final result = await showScheduleTimeZonePicker(
      context: context,
      currentZone: _zone,
      civil: _civil,
      offsetSeconds: _offset,
      isCurrent: () => _owns(owner, selection),
    );
    if (result == null || !_owns(owner, selection)) return;
    setState(() {
      _zone = result;
      _offset = null;
      _resolve();
    });
  }

  DateTime? get _selectedInstant {
    for (final value in _choices) {
      if (value.offsetSeconds == _offset) return value.instantUtc;
    }
    return null;
  }

  DateTime? get _oldInstant {
    final original = _review?.snapshot.schedule;
    if (original?.occurrenceOffsetSeconds == null) return null;
    try {
      return CivilDateTime.fromFields(
        original!.scheduleTime,
      ).atOffset(original.occurrenceOffsetSeconds!);
    } on FormatException {
      return null;
    }
  }

  Future<void> _confirm() async {
    if (_busy || _confirming || _needsReview || _receipt != null) return;
    final owner = _owner, selection = _selection;
    final instant = _selectedInstant;
    if (_review == null || instant == null || _review!.blockedBy != null) {
      return;
    }
    var command = _command ??= ScheduleTimeCorrectionCommand(
      review: _review!,
      civil: CivilDateTime.fromFields(_civil!),
      timeZoneId: _zone,
      offsetSeconds: _offset!,
      mutationId: const Uuid().v7(),
    );
    var comparison = _confirmedComparison ?? _comparison();
    setState(() => _confirming = true);
    try {
      // An accepted command may already have committed when its response was
      // lost. Replay its exact receipt identity before attempting a new review.
      if (!identical(command, _confirmedCommand)) {
        final proof = await widget.workflow.repository.reviewChoice(command);
        if (!mounted || !_owns(owner, selection)) return;
        if (proof.conflicts.isNotEmpty) {
          setState(() {
            _conflicts = proof.conflicts;
            _confirming = false;
          });
          return;
        }
        final acknowledged = proof.possibleOverlaps.map((e) => e.id).toSet();
        if (!const SetEquality<String>().equals(
          command.acknowledgedUncertainIds,
          acknowledged,
        )) {
          command = ScheduleTimeCorrectionCommand(
            review: command.review,
            civil: command.civil,
            timeZoneId: command.timeZoneId,
            offsetSeconds: command.offsetSeconds,
            mutationId: command.mutationId,
            acknowledgedUncertainIds: acknowledged,
          );
          _command = command;
        }
        if (proof.possibleOverlaps.isNotEmpty) {
          comparison +=
              '\n\n${recurrenceText(context, '다음 일정은 정확한 충돌 판정이 불가능해요. 해당 일정의 새 시작·알림은 보류됩니다. 각 일정을 나중에 확인할 때 다시 충돌을 검사해요.', 'Exact overlap is uncertain for these appointments. Their new starts and alarms remain on hold. Their individual time reviews will check overlaps again.')}';
          comparison +=
              '\n${proof.possibleOverlaps.map(_possibleImpact).join('\n\n')}';
        }
      }
    } on ScheduleSaveRejected catch (error) {
      if (!_owns(owner, selection)) return;
      setState(() {
        _confirming = false;
        _failure = error.failure;
        _needsReview = error.failure != ScheduleSaveFailure.invalid;
      });
      return;
    } catch (_) {
      if (!_owns(owner, selection)) return;
      setState(() {
        _confirming = false;
        _failed = true;
      });
      return;
    }
    if (!mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          recurrenceText(
            context,
            '변경할 시간을 확인하세요',
            'Confirm the corrected time',
          ),
        ),
        content: SingleChildScrollView(child: Text(comparison)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(recurrenceText(context, '취소', 'Cancel')),
          ),
          FilledButton(
            key: const Key('confirm-time-correction'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(recurrenceText(context, '확인 후 저장', 'Confirm and save')),
          ),
        ],
      ),
    );
    if (!_owns(owner, selection)) return;
    setState(() => _confirming = false);
    if (accepted != true) return;
    _confirmedCommand = command;
    _confirmedComparison = comparison;
    setState(() {
      _busy = true;
      _failed = false;
      _failure = null;
    });
    try {
      final receipt = await widget.workflow.confirm(command);
      if (!_owns(owner, selection)) return;
      _saved(receipt);
    } on ScheduleTimeCorrectionConflict catch (error) {
      if (!_owns(owner, selection)) return;
      setState(() {
        _busy = false;
        _conflicts = error.proof.conflicts;
      });
    } on ScheduleSaveRejected catch (error) {
      if (!_owns(owner, selection)) return;
      setState(() {
        _busy = false;
        _failure = error.failure;
        _needsReview = error.failure != ScheduleSaveFailure.invalid;
      });
    } catch (_) {
      if (!_owns(owner, selection)) return;
      setState(() {
        _busy = false;
        _failed = true;
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
    final owner = _owner;
    setState(() => _busy = true);
    final receipt = await widget.workflow.retryDelivery(_receipt!);
    if (_owns(owner)) _saved(receipt);
  }

  String _possibleImpact(TimeCorrectionPossibleOverlap value) {
    final status = ScheduleTimeResolutionStatus.values.firstWhereOrNull(
      (status) => status.name == value.reason,
    );
    return [
      value.name,
      if (value.originalCivil != null)
        '${_format(value.originalCivil!)} · ${value.timeZoneId ?? ''}',
      if (value.rule != null)
        '${recurrenceLabel(context, value.rule!)} · ${recurrenceEndLabel(context, value.rule!)}',
      if (status != null) _reason(status),
    ].join('\n');
  }

  String _format(DateTime value) => DateFormat.yMd(
    Localizations.localeOf(context).toString(),
  ).add_Hms().format(value);

  String _comparison() {
    final original = _review!.snapshot.schedule;
    final instant = _selectedInstant;
    final previous = _oldInstant;
    return [
      '${recurrenceText(context, '저장된 시간', 'Saved time')}: ${_format(original.scheduleTime)} · ${original.timeZoneId}',
      if (previous != null)
        '${recurrenceText(context, '기존 순간', 'Previous instant')}: ${previous.toIso8601String()}',
      '${recurrenceText(context, '선택한 시간', 'Selected time')}: ${_format(_civil!)} · $_zone',
      if (instant != null) ...[
        '${recurrenceText(context, '새 순간', 'New instant')}: ${instant.toIso8601String()}',
        '${recurrenceText(context, '기기 시각', 'Device time')}: ${_format(instant.toLocal())} ${instant.toLocal().timeZoneName}',
        if (previous != null)
          '${recurrenceText(context, '시간 차이(초)', 'Difference (seconds)')}: ${instant.difference(previous).inMicroseconds / Duration.microsecondsPerSecond}',
      ],
    ].join('\n\n');
  }

  String _reason(ScheduleTimeResolutionStatus status) => switch (status) {
    ScheduleTimeResolutionStatus.unknownZone => recurrenceText(
      context,
      '저장된 시간대를 찾을 수 없어요. 시간대를 직접 선택해주세요.',
      'The saved time zone is unavailable. Choose a time zone.',
    ),
    ScheduleTimeResolutionStatus.nonexistent => recurrenceText(
      context,
      '시간대 전환으로 존재하지 않는 시각이에요.',
      'This wall time does not exist because of a time zone transition.',
    ),
    ScheduleTimeResolutionStatus.ambiguous => recurrenceText(
      context,
      '두 번 발생하는 시각이에요. 원하는 순간을 선택해주세요.',
      'This time occurs twice. Select the intended occurrence.',
    ),
    ScheduleTimeResolutionStatus.changed => recurrenceText(
      context,
      '시간대 규칙이 달라졌어요. 변경할 순간을 확인해주세요.',
      'Time zone rules changed. Review the intended instant.',
    ),
    ScheduleTimeResolutionStatus.historicalUncertain => recurrenceText(
      context,
      '과거의 정확한 순간을 확인할 수 없어요. 저장된 기록은 유지됩니다.',
      'The historical instant is uncertain. The saved record is preserved.',
    ),
    _ => recurrenceText(
      context,
      '저장된 시간 정보를 확인하세요.',
      'Review the saved time information.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final review = _review;
    final blocked =
        _busy ||
        _confirming ||
        _needsReview ||
        review?.blockedBy != null ||
        _receipt != null;
    final gap =
        _civil != null && _choices.isEmpty && TimeZoneRules.contains(_zone)
        ? CivilTimeResolver.nextValidCivilTime(_civil!, _zone)
        : null;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            recurrenceText(context, '일정 시간 확인', 'Review schedule time'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (_busy) const LinearProgressIndicator(),
          if (review != null) ...[
            const SizedBox(height: 16),
            Text(review.snapshot.schedule.scheduleName),
            Text(_reason(review.resolution.status)),
            if (review.snapshot.schedule.isRecurring)
              Text(
                recurrenceText(
                  context,
                  '이번 회차의 시간만 변경하며 원래 반복 날짜와 준비 기록을 유지합니다.',
                  'Only this occurrence changes; its original recurrence date and preparation records are preserved.',
                ),
              ),
            if (review.blockedBy != null)
              Text(
                recurrenceText(
                  context,
                  '진행 중이거나 지난 기록은 이 화면에서 변경할 수 없어요.',
                  'Running or historical records cannot be changed here.',
                ),
              ),
            const SizedBox(height: 16),
            Text(_comparison(), key: const Key('time-correction-comparison')),
            ListTile(
              key: const Key('correction-date'),
              title: Text(recurrenceText(context, '날짜', 'Date')),
              subtitle: Text(_format(_civil!)),
              onTap: blocked ? null : () => _pickCivil(true),
            ),
            ListTile(
              key: const Key('correction-time'),
              title: Text(recurrenceText(context, '시간', 'Time')),
              subtitle: Text(_format(_civil!)),
              onTap: blocked ? null : () => _pickCivil(false),
            ),
            ListTile(
              key: const Key('correction-zone'),
              title: Text(_zone),
              subtitle: Text(
                recurrenceText(context, '시간대를 직접 선택', 'Choose time zone'),
              ),
              onTap: blocked ? null : _pickZone,
            ),
            if (gap != null)
              TextButton(
                key: const Key('correction-gap-proposal'),
                onPressed: blocked
                    ? null
                    : () => setState(() {
                        _civil = gap;
                        _offset = null;
                        _resolve();
                      }),
                child: Text(
                  '${recurrenceText(context, '다음 유효 시각 선택', 'Select next valid time')}: ${_format(gap)}',
                ),
              ),
            for (final choice in _choices)
              ListTile(
                key: ValueKey('correction-offset-${choice.offsetSeconds}'),
                leading: Icon(
                  _offset == choice.offsetSeconds
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                title: Text(
                  CivilTimeResolver.formatUtcOffset(choice.offsetSeconds),
                ),
                subtitle: Text(choice.instantUtc.toIso8601String()),
                selected: choice.offsetSeconds == _offset,
                onTap: blocked
                    ? null
                    : () => setState(() {
                        _offset = choice.offsetSeconds;
                        _selection++;
                        _command = null;
                        _confirmedCommand = null;
                        _confirmedComparison = null;
                        _conflicts = const [];
                        _failure = null;
                      }),
              ),
            if (_receipt == null)
              FilledButton(
                key: const Key('review-time-correction'),
                onPressed: blocked || _selectedInstant == null
                    ? null
                    : _confirm,
                child: Text(
                  recurrenceText(context, '변경 내용 확인', 'Review changes'),
                ),
              ),
          ],
          if (_conflicts.isNotEmpty)
            Text(
              '${recurrenceText(context, '다른 약속의 준비 시간과 겹쳐요. 시간을 다시 선택해주세요.', 'This overlaps another appointment or its preparation. Choose another time.')}\n${_conflicts.map((e) => e.other.schedule.scheduleName).toSet().join(', ')}',
              key: const Key('time-correction-overlap'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_failure != null || _failed) ...[
            Text(
              _failure == ScheduleSaveFailure.invalid
                  ? recurrenceText(
                      context,
                      '새 준비 시작과 약속 시각이 모두 현재보다 나중이어야 해요. 시각을 다시 선택해주세요.',
                      'Both the new preparation start and appointment must be in the future. Choose another time.',
                    )
                  : recurrenceText(
                      context,
                      '일정이나 시간 기준이 바뀌었거나 작업을 마칠 수 없어요. 최신 기록을 다시 확인해주세요.',
                      'The schedule or time authority changed, or the operation could not finish. Review the latest record.',
                    ),
            ),
            TextButton(
              onPressed: _busy ? null : _load,
              child: Text(
                recurrenceText(context, '최신 기록 다시 확인', 'Review latest record'),
              ),
            ),
          ],
          if (_receipt?.deliveryPending ?? false) ...[
            Text(
              recurrenceText(
                context,
                '시간은 저장되었지만 알림 동기화가 아직 끝나지 않았어요.',
                'The time was saved. Notification synchronization is still pending.',
              ),
            ),
            TextButton(
              onPressed: _busy ? null : _retryDelivery,
              child: Text(
                recurrenceText(
                  context,
                  '알림 동기화 다시 시도',
                  'Retry notification synchronization',
                ),
              ),
            ),
          ],
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: Text(recurrenceText(context, '닫기', 'Close')),
          ),
        ],
      ),
    );
  }
}
