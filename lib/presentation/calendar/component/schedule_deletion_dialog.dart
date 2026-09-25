import 'dart:async';
import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'package:on_time_front/presentation/shared/time/schedule_zoned_time.dart';

import 'package:flutter/material.dart';
import 'package:on_time_front/core/time/schedule_time_resolution.dart';
import 'package:on_time_front/domain/entities/schedule_deletion.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
import 'package:on_time_front/domain/use-cases/delete_schedule_use_case.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/recurring/recurrence_scope_sheet.dart';

Future<bool> showScheduleDeletionDialog(
  BuildContext context, {
  required ScheduleEntity schedule,
  required DeleteScheduleUseCase deletions,
  RecurringEditScope? scope,
}) async {
  var selectedScope = scope ?? RecurringEditScope.occurrence;
  if (scope == null &&
      schedule.isRecurring &&
      !schedule.isStarted &&
      !schedule.preparationFrozen &&
      schedule.doneStatus == ScheduleDoneStatus.notEnded &&
      (ScheduleTimeResolver.resolve(
            schedule,
            nowUtc: DateTime.now(),
          ).instantUtc?.isAfter(DateTime.now().toUtc()) ??
          false)) {
    final selected = await showRecurrenceScope(context, deleting: true);
    if (selected == null || !context.mounted) return false;
    selectedScope = selected;
  }
  if (!context.mounted) return false;
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ScheduleDeletionDialog(
          scheduleId: schedule.id,
          scope: selectedScope,
          deletions: deletions,
        ),
      ) ??
      false;
}

class _ScheduleDeletionDialog extends StatefulWidget {
  const _ScheduleDeletionDialog({
    required this.scheduleId,
    required this.scope,
    required this.deletions,
  });
  final String scheduleId;
  final RecurringEditScope scope;
  final DeleteScheduleUseCase deletions;
  @override
  State<_ScheduleDeletionDialog> createState() =>
      _ScheduleDeletionDialogState();
}

class _ScheduleDeletionDialogState extends State<_ScheduleDeletionDialog> {
  ScheduleDeletionIntent? _intent;
  ScheduleDeletionCommit? _commit;
  ScheduleDeletionResult? _result;
  Object? _failure;
  bool _working = false;
  bool _loading = true;
  bool _delayed = false;
  Timer? _delay;
  late final int _generation;
  @override
  void initState() {
    super.initState();
    _generation = widget.deletions.currentGeneration;
    _prepare();
  }

  @override
  void dispose() {
    _delay?.cancel();
    super.dispose();
  }

  Future<void> _prepare() async {
    try {
      final intent = await widget.deletions.prepare(
        widget.scheduleId,
        scope: widget.scope,
      );
      if (mounted && _current) {
        setState(() {
          _intent = intent;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted && _current) {
        setState(() {
          _failure = error;
          _loading = false;
        });
      }
    }
  }

  bool get _current => widget.deletions.isCurrentGeneration(_generation);
  Future<void> _delete() async {
    if (_working || _intent == null || !_current) return;
    setState(() {
      _working = true;
      _failure = null;
      _delayed = false;
    });
    _delay = Timer(const Duration(seconds: 10), () {
      if (mounted && _current) setState(() => _delayed = true);
    });
    try {
      final result = _commit == null
          ? await widget.deletions.confirm(
              _intent!,
              onCommitted: (commit) {
                if (mounted &&
                    widget.deletions.isCurrentGeneration(commit.generation)) {
                  setState(() => _commit = commit);
                }
              },
            )
          : await widget.deletions.retryCleanup(_commit!);
      if (mounted &&
          widget.deletions.isCurrentGeneration(result.commit.generation)) {
        setState(() {
          _commit = result.commit;
          _result = result;
        });
      }
    } catch (error) {
      if (mounted && _current) setState(() => _failure = error);
    } finally {
      _delay?.cancel();
      if (mounted && _current) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final commit = _commit;
    final failed = _failure != null && commit == null;
    final protected =
        _failure is ScheduleDeletionRejected &&
        (_failure as ScheduleDeletionRejected).failure ==
            ScheduleDeletionFailure.protected;
    final complete = _result?.cleanup == ScheduleDeletionCleanup.complete;
    final title = (commit?.alreadyAbsent ?? false)
        ? l10n.scheduleDeletionAbsentTitle
        : commit != null
        ? l10n.scheduleDeletionRemovedTitle
        : failed
        ? l10n.scheduleDeleteFailedTitle
        : l10n.scheduleDeleteConfirmTitle;
    final description = commit != null
        ? complete
              ? commit.alreadyAbsent
                    ? l10n.scheduleDeletionAlreadyAbsent
                    : l10n.scheduleDeletionComplete
              : _working && !_delayed
              ? l10n.scheduleDeletionCleaning
              : l10n.scheduleDeletionPending
        : failed
        ? protected
              ? l10n.scheduleDeletionPreparationActive
              : l10n.scheduleDeleteFailedDescription
        : widget.scope == RecurringEditScope.following
        ? l10n.scheduleDeletionFollowingConsequences
        : l10n.scheduleDeletionConsequences;
    final schedule = _intent?.snapshot.schedule;
    return PopScope(
      canPop: !_working,
      child: AlertDialog(
        scrollable: true,
        title: Text(title),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        buttonPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        actionsOverflowButtonSpacing: 8,
        content: Semantics(
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_loading) const LinearProgressIndicator(),
              if (schedule != null && commit == null) ...[
                Text(
                  schedule.scheduleName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.scope == RecurringEditScope.following
                      ? l10n.scheduleDeletionFollowing
                      : l10n.scheduleDeletionOnlySelected,
                ),
                const SizedBox(height: 12),
                ScheduleZonedTime(
                  civil: CivilDateTime.fromFields(schedule.scheduleTime),
                  timeZoneId: schedule.timeZoneId,
                  resolution: ScheduleTimeResolver.resolve(
                    schedule,
                    nowUtc: DateTime.now(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (!_loading) Text(description),
              if ((commit?.alreadyAbsent ?? false) && !complete)
                Text(l10n.scheduleDeletionAlreadyAbsent),
              if (_working) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
        actions: [
          if (_intent != null && !failed && commit == null)
            TextButton(
              onPressed: _working ? null : _delete,
              child: Text(l10n.deleteScheduleConfirmAction),
            ),
          if (commit != null && !complete && _current)
            TextButton(
              onPressed: _working ? null : _delete,
              child: Text(l10n.scheduleDeletionRetryCleanup),
            ),
          TextButton(
            onPressed: _working && commit == null
                ? null
                : () => Navigator.of(context).pop(commit != null),
            child: Text(commit != null || failed ? l10n.ok : l10n.cancel),
          ),
        ],
      ),
    );
  }
}
