import 'package:on_time_front/domain/entities/schedule_deletion.dart';
import 'package:on_time_front/domain/entities/schedule_save.dart';
import 'package:on_time_front/core/time/schedule_time_resolution.dart';
import 'package:on_time_front/core/startup/startup_dependency_scope.dart';
import 'package:on_time_front/domain/entities/schedule_start_rejected.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/core/logging/app_logger.dart';
import 'package:on_time_front/domain/entities/schedule_not_found.dart';
import 'dart:async';
import 'package:on_time_front/domain/entities/preparation_snapshot_validation.dart';

import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/early_start_session_entity.dart';
import 'package:on_time_front/domain/entities/preparation_action_event_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_with_time_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/entities/timed_preparation_snapshot_entity.dart';
import 'package:on_time_front/domain/repositories/early_start_session_repository.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';
import 'package:on_time_front/domain/repositories/timed_preparation_repository.dart';
import 'package:on_time_front/domain/use-cases/cancel_schedule_alarm_use_case.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';

enum SchedulePreparationPromptStatus { ready, rejected, unavailable }

typedef RestoredSessionCallback =
    void Function({
      required DateTime? startedAt,
      required List<PreparationActionEventEntity> actionEvents,
    });

class SchedulePreparationPromptResult {
  const SchedulePreparationPromptResult._({
    required this.status,
    this.schedule,
  });

  const SchedulePreparationPromptResult.ready(
    ScheduleWithPreparationEntity schedule,
  ) : this._(status: SchedulePreparationPromptStatus.ready, schedule: schedule);

  const SchedulePreparationPromptResult.rejected()
    : this._(status: SchedulePreparationPromptStatus.rejected);

  const SchedulePreparationPromptResult.unavailable()
    : this._(status: SchedulePreparationPromptStatus.unavailable);

  final SchedulePreparationPromptStatus status;
  final ScheduleWithPreparationEntity? schedule;
}

Future<void> disposePreparationSession(
  SchedulePreparationSessionUseCase resource,
) => StartupDependencyScope.release(resource, resource.dispose);

@Singleton(dispose: disposePreparationSession)
class SchedulePreparationSessionUseCase {
  SchedulePreparationSessionUseCase(
    this._scheduleRepository,
    this._preparationRepository,
    this._timedPreparationRepository,
    this._earlyStartSessionRepository,
    this._cancelScheduleAlarmUseCase,
    this._reconcileAlarmsUseCase, {
    @ignoreParam AlarmOperationCoordinator? operations,
  }) : _operations = operations ?? AlarmOperationCoordinator.shared {
    StartupDependencyScope.own(this, dispose);
    _operations.addListener(_discardOldGenerations);
  }

  final ScheduleRepository _scheduleRepository;
  final PreparationRepository _preparationRepository;
  final TimedPreparationRepository _timedPreparationRepository;
  final EarlyStartSessionRepository _earlyStartSessionRepository;
  final CancelScheduleAlarmUseCase _cancelScheduleAlarmUseCase;
  final ReconcileAlarmsUseCase _reconcileAlarmsUseCase;
  final AlarmOperationCoordinator _operations;
  final _starts = <(int, String), Future<DateTime>>{};
  final _runs = <(int, String), _StartRun>{};
  final _projections = <(int, String), TimedPreparationSnapshotEntity>{};
  final _epochs = <(int, String), int>{};

  void dispose() {
    _operations.removeListener(_discardOldGenerations);
    _starts.clear();
    _runs.clear();
    _projections.clear();
    _epochs.clear();
  }

  void _discardOldGenerations() {
    final generation = _operations.generation;
    // Queued futures keep their own completion/lease; dropping lookup entries
    // never cancels their native work or releases the shared operation owner.
    _starts.removeWhere((key, _) => key.$1 != generation);
    _runs.removeWhere((key, _) => key.$1 != generation);
    _projections.removeWhere((key, _) => key.$1 != generation);
    _epochs.removeWhere((key, _) => key.$1 != generation);
  }

  Future<PreparationStartReceipt> startEarlySession(
    ScheduleWithPreparationEntity schedule, {
    required DateTime startedAt,
    bool Function()? isCurrent,
  }) {
    final lease = _operations.capture();
    final key = (lease.generation, schedule.id);
    if (_runs[key] != null &&
        _runs[key]!.fingerprint != schedule.cacheFingerprint) {
      _runs.remove(key);
      _projections.remove(key);
    }
    final run = _runs.putIfAbsent(
      key,
      () => _StartRun(startedAt, schedule.cacheFingerprint),
    );
    if (run.flight != null) return run.flight!;
    final future = _startEarly(schedule, run, lease, isCurrent);
    run.flight = future;
    future.then<void>(
      (_) {
        run.flight = null;
      },
      onError: (Object _, StackTrace __) {
        run.flight = null;
      },
    );
    return future;
  }

  Future<PreparationStartReceipt> _startEarly(
    ScheduleWithPreparationEntity schedule,
    _StartRun run,
    AlarmOperationLease lease,
    bool Function()? isCurrent,
  ) async {
    final key = (lease.generation, schedule.id);
    bool current() =>
        lease.isCurrent &&
        identical(_runs[key], run) &&
        (isCurrent?.call() ?? true);
    if (!current()) throw const AlarmOperationInvalidated();
    await _operations.run(lease, () async {
      if (!current()) throw const AlarmOperationInvalidated();
      if (!run.initialized) {
        final authoritative = await _scheduleRepository.getScheduleById(
          schedule.id,
        );
        if (!current()) throw const AlarmOperationInvalidated();
        final stored = await _timedPreparationRepository
            .getTimedPreparationSnapshot(schedule.id);
        if (!current()) throw const AlarmOperationInvalidated();
        final validated = stored == null
            ? null
            : validatePreparationSnapshot(stored, schedule);
        if (authoritative.retainedRecurringReference &&
            (!authoritative.isStarted ||
                validated == null ||
                validated.requiresConfirmation ||
                validated.startedAt == null)) {
          throw ScheduleStartRejected(schedule.id);
        }
        // A view owner is not a Preparation Run identity. Only a validated
        // active snapshot resumes a previous run; DB startedAt alone never does.
        if (validated != null &&
            !validated.requiresConfirmation &&
            validated.startedAt != null) {
          run.startedAt = validated.startedAt!;
          _projections[key] = validated;
        }
        run.initialized = true;
      }
      if (!run.committed) {
        run.durableStartedAt = await _scheduleRepository.startSchedule(
          schedule.id,
          startedAt: run.startedAt,
        );
        run.committed = true;
      } else {
        final existing = await _scheduleRepository.getScheduleById(schedule.id);
        if (_isEnded(existing.doneStatus)) {
          throw ScheduleStartRejected(schedule.id);
        }
      }
    });
    if (!current()) throw const AlarmOperationInvalidated();
    var partial = false;
    try {
      await _operations.run(lease, () async {
        if (!current()) throw const AlarmOperationInvalidated();
        await _earlyStartSessionRepository.markStarted(
          scheduleId: schedule.id,
          startedAt: run.startedAt,
        );
      });
    } on AlarmOperationInvalidated {
      rethrow;
    } catch (_) {
      partial = true;
    }
    if (!current()) throw const AlarmOperationInvalidated();
    try {
      // A retry uses the latest projection, never the initial empty event list.
      if (!_projections.containsKey(key)) {
        _projections[key] = TimedPreparationSnapshotEntity(
          preparation: schedule.preparation,
          savedAt: run.startedAt,
          scheduleFingerprint: schedule.cacheFingerprint,
          startedAt: run.startedAt,
        );
      }
      await _persistProjection(schedule.id, lease, isCurrent: current);
    } on AlarmOperationInvalidated {
      rethrow;
    } catch (_) {
      partial = true;
    }
    if (!current()) throw const AlarmOperationInvalidated();
    try {
      await _cancelScheduleAlarmUseCase(schedule.id);
    } on AlarmOperationInvalidated {
      rethrow;
    } catch (_) {
      partial = true;
    }
    if (!current()) throw const AlarmOperationInvalidated();
    requestAlarmReconciliation(_reconcileAlarmsUseCase);
    return PreparationStartReceipt(
      startedAt: run.startedAt,
      durableStartedAt: run.durableStartedAt,
      actionEvents: _projections[key]?.actionEvents ?? const [],
      hasPendingRecovery: partial,
    );
  }

  Future<DateTime> startSchedulePreparation(
    String scheduleId, {
    bool Function()? isCurrent,
    String? expectedFingerprint,
  }) {
    final lease = _operations.capture();
    if (isCurrent != null || expectedFingerprint != null) {
      // Each guarded command owns its own intent. Do not coalesce a new intent
      // with an older cancelled command merely because the schedule ID matches.
      return _operations.run(lease, () async {
        if (!(isCurrent?.call() ?? true)) {
          throw ScheduleStartRejected(scheduleId);
        }
        return _scheduleRepository.startSchedule(
          scheduleId,
          isCurrent: isCurrent,
          expectedFingerprint: expectedFingerprint,
        );
      });
    }
    final key = (lease.generation, scheduleId);
    final pending = _starts[key];
    if (pending != null) return pending;
    final future = _operations.run(lease, () async {
      return _scheduleRepository.startSchedule(scheduleId);
    });
    _starts[key] = future;
    future.then<void>(
      (_) {
        if (identical(_starts[key], future)) _starts.remove(key);
      },
      onError: (Object _, StackTrace __) {
        if (identical(_starts[key], future)) _starts.remove(key);
      },
    );
    return future;
  }

  Future<bool> hasEarlyStartSession(String scheduleId) async {
    return await _earlyStartSessionRepository.getSession(scheduleId) != null;
  }

  Future<EarlyStartSessionEntity?> getEarlyStartSession(String scheduleId) {
    return _earlyStartSessionRepository.getSession(scheduleId);
  }

  Future<void> saveTimedPreparationSnapshot(
    ScheduleWithPreparationEntity schedule, {
    DateTime? savedAt,
    DateTime? startedAt,
    List<PreparationActionEventEntity> actionEvents = const [],
    bool persist = true,
  }) {
    final snapshot = TimedPreparationSnapshotEntity(
      preparation: schedule.preparation,
      savedAt: savedAt ?? DateTime.now(),
      scheduleFingerprint: schedule.cacheFingerprint,
      startedAt: startedAt,
      actionEvents: actionEvents,
    );
    final lease = _operations.capture();
    _projections[(lease.generation, schedule.id)] = snapshot;
    return persist
        ? _persistProjection(schedule.id, lease)
        : Future<void>.value();
  }

  Future<void> _persistProjection(
    String scheduleId,
    AlarmOperationLease lease, {
    bool Function()? isCurrent,
  }) {
    final key = (lease.generation, scheduleId);
    final epoch = _epochs[key] ?? 0;
    return _operations.run(lease, () async {
      if ((_epochs[key] ?? 0) != epoch || !(isCurrent?.call() ?? true)) return;
      final latest = _projections[key];
      if (latest != null) {
        await _timedPreparationRepository.saveTimedPreparationSnapshot(
          scheduleId,
          latest,
        );
      }
    });
  }

  Future<ScheduleWithPreparationEntity> restoreTimedPreparationIfValid(
    ScheduleWithPreparationEntity schedule, {
    required DateTime now,
    RestoredSessionCallback? onRestoredSession,
    void Function()? onInvalidated,
  }) async {
    final lease = _operations.capture();
    final interpretation =
        schedule.timeResolution ??
        ScheduleTimeResolver.resolve(schedule, nowUtc: now.toUtc());
    if (interpretation.instantUtc == null) {
      await clearPersistedState(schedule.id);
      onInvalidated?.call();
      return ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
        schedule,
        schedule.preparation,
        timeResolution: interpretation,
      );
    }
    final stored = await _timedPreparationRepository
        .getTimedPreparationSnapshot(schedule.id);
    lease.check();
    if (stored == null) {
      if (schedule.requiresStartConfirmation) onInvalidated?.call();
      return schedule;
    }
    final snapshot = validatePreparationSnapshot(stored, schedule);
    if (schedule.requiresStartConfirmation ||
        snapshot == null ||
        snapshot.requiresConfirmation) {
      await clearPersistedState(schedule.id);
      await _operations.run(
        lease,
        () => _timedPreparationRepository.saveTimedPreparationSnapshot(
          schedule.id,
          TimedPreparationSnapshotEntity(
            preparation: schedule.preparation,
            savedAt: now,
            scheduleFingerprint: schedule.cacheFingerprint,
            requiresConfirmation: true,
          ),
        ),
      );
      onInvalidated?.call();
      return schedule;
    }

    final startedAt = snapshot.startedAt;
    onRestoredSession?.call(
      startedAt: startedAt,
      actionEvents: snapshot.actionEvents,
    );
    final restoredPreparation = startedAt == null
        ? _restoreElapsedSnapshot(snapshot, now)
        : _derivePreparationRun(
            schedule.preparation,
            startedAt: startedAt,
            actionEvents: snapshot.actionEvents,
            now: now,
          );

    return ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
      schedule,
      restoredPreparation,
      timeResolution:
          schedule.timeResolution ??
          ScheduleTimeResolver.resolve(schedule, nowUtc: now.toUtc()),
    );
  }

  /// Read-only: opening or cancelling deletion confirmation changes no run state.
  Future<void> assertDeletionAllowed(
    ScheduleEditSnapshot snapshot, {
    required AlarmOperationLease lease,
  }) async {
    lease.check();
    final schedule = snapshot.schedule;
    if (schedule.isStarted) {
      throw const ScheduleDeletionRejected(ScheduleDeletionFailure.protected);
    }
    // A finalized outcome cannot be revived by stale reconstructible progress.
    if (_isEnded(schedule.doneStatus)) return;
    final key = (lease.generation, schedule.id);
    if (_starts.containsKey(key) || _runs[key]?.flight != null) {
      throw const ScheduleDeletionRejected(ScheduleDeletionFailure.protected);
    }
    final early = await _earlyStartSessionRepository.getSession(schedule.id);
    lease.check();
    final stored = await _timedPreparationRepository
        .getTimedPreparationSnapshot(schedule.id);
    lease.check();
    if (stored == null && early == null) return;
    final resolution = ScheduleTimeResolver.resolve(
      schedule,
      nowUtc: DateTime.now().toUtc(),
    );
    if (resolution.instantUtc == null) {
      throw const ScheduleDeletionRejected(ScheduleDeletionFailure.unavailable);
    }
    final value =
        ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
          schedule,
          PreparationWithTimeEntity.fromPreparation(snapshot.preparation),
          timeResolution: resolution,
        );
    final valid = stored == null
        ? null
        : validatePreparationSnapshot(stored, value);
    if (valid != null &&
        valid.startedAt != null &&
        !valid.requiresConfirmation) {
      throw const ScheduleDeletionRejected(ScheduleDeletionFailure.protected);
    }
    if (early != null || (stored != null && valid == null)) {
      throw const ScheduleDeletionRejected(ScheduleDeletionFailure.unavailable);
    }
  }

  /// Caller holds the existing delivery owner. Never enqueue recursively here.
  Future<void> clearDeletedStateUnderOwner(
    String scheduleId, {
    required AlarmOperationLease lease,
    required Future<bool> Function() isCurrent,
  }) async {
    Future<void> check() async {
      lease.check();
      if (!await isCurrent()) throw const AlarmOperationInvalidated();
      lease.check();
    }

    await check();
    final key = (lease.generation, scheduleId);
    _runs.remove(key);
    _projections.remove(key);
    _epochs[key] = (_epochs[key] ?? 0) + 1;
    await _timedPreparationRepository.clearTimedPreparation(scheduleId);
    await check();
    await _earlyStartSessionRepository.clear(scheduleId);
    await check();
  }

  Future<void> clearPersistedState(String scheduleId) {
    final lease = _operations.capture();
    final key = (lease.generation, scheduleId);
    _runs.remove(key);
    _projections.remove(key);
    _epochs[key] = (_epochs[key] ?? 0) + 1;
    return _operations.run(lease, () async {
      await _timedPreparationRepository.clearTimedPreparation(scheduleId);
      await _earlyStartSessionRepository.clear(scheduleId);
    });
  }

  Future<void> finishSchedulePreparation(
    String scheduleId, {
    required int latenessTime,
  }) async {
    final lease = _operations.capture();
    final key = (lease.generation, scheduleId);
    _runs.remove(key);
    _projections.remove(key);
    _epochs[key] = (_epochs[key] ?? 0) + 1;
    await _operations.run(lease, () async {
      try {
        await _scheduleRepository.startSchedule(scheduleId);
      } on ScheduleStartRejected {
        /* Already finished is idempotent. */
      }
      await _scheduleRepository.finishSchedule(scheduleId, latenessTime);
    });
    lease.check();
    requestAlarmReconciliation(_reconcileAlarmsUseCase);
    if (!await _cancelDelivery(scheduleId)) return;
    lease.check();
    await clearPersistedState(scheduleId);
  }

  Future<SchedulePreparationPromptResult> resolvePromptedSchedule({
    required String scheduleId,
    required bool startPreparation,
    String? scheduleFingerprint,
    bool Function()? isCurrent,
  }) async {
    final evaluationNow = DateTime.now().toUtc();
    bool current() => isCurrent?.call() ?? true;
    try {
      final schedule = await _scheduleRepository.getScheduleById(scheduleId);
      if (!current()) {
        return const SchedulePreparationPromptResult.unavailable();
      }
      if (_isEnded(schedule.doneStatus) ||
          schedule.retainedRecurringReference) {
        if (isCurrent == null && !await _cancelDelivery(scheduleId)) {
          return const SchedulePreparationPromptResult.unavailable();
        }
        return const SchedulePreparationPromptResult.rejected();
      }
      // Subscribe first, but retain only a finite snapshot of the loaded map.
      // No uncancelled firstWhere waiter survives a failed preparation lookup.
      PreparationEntity? preparation;
      Object? streamError;
      final firstSnapshot = Completer<void>();
      final subscription = _preparationRepository.preparationStream.listen(
        (preparations) {
          preparation = preparations[scheduleId];
          if (!firstSnapshot.isCompleted) firstSnapshot.complete();
        },
        onError: (Object error, StackTrace stack) {
          streamError = error;
          if (!firstSnapshot.isCompleted) firstSnapshot.complete();
        },
        onDone: () {
          if (!firstSnapshot.isCompleted) firstSnapshot.complete();
        },
      );
      try {
        await _preparationRepository.getPreparationByScheduleId(scheduleId);
        if (!current()) {
          return const SchedulePreparationPromptResult.unavailable();
        }
        // The repository publishes the loaded map before completing the load.
        // Wait for stream delivery, not an arbitrary timer or cached firstWhere.
        await firstSnapshot.future;
        if (!current() || streamError != null) {
          return const SchedulePreparationPromptResult.unavailable();
        }
      } finally {
        await subscription.cancel();
      }
      if (!current() || preparation == null) {
        return const SchedulePreparationPromptResult.unavailable();
      }
      final combined =
          ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
            schedule,
            PreparationWithTimeEntity.fromPreparation(preparation!),
            timeResolution: ScheduleTimeResolver.resolve(
              schedule,
              nowUtc: evaluationNow,
            ),
          );
      if (combined.timeResolution!.instantUtc == null) {
        return const SchedulePreparationPromptResult.unavailable();
      }
      if (scheduleFingerprint != null &&
          scheduleFingerprint != combined.cacheFingerprint &&
          !startPreparation) {
        if (isCurrent == null && !await _cancelDelivery(scheduleId)) {
          return const SchedulePreparationPromptResult.unavailable();
        }
        return const SchedulePreparationPromptResult.rejected();
      }
      return SchedulePreparationPromptResult.ready(combined);
    } on ScheduleNotFound {
      return current()
          ? const SchedulePreparationPromptResult.rejected()
          : const SchedulePreparationPromptResult.unavailable();
    } catch (_) {
      return const SchedulePreparationPromptResult.unavailable();
    }
  }

  Future<bool> _cancelDelivery(String scheduleId) async {
    try {
      await _cancelScheduleAlarmUseCase(scheduleId);
      return true;
    } on AlarmOperationInvalidated {
      // The old DB action must not write/clear transient state in a new store.
      return false;
    } catch (error) {
      AppLogger.debug(
        '[PreparationSession] delivery cleanup incomplete errorType=${error.runtimeType}',
      );
      return true; // Durable start/finish succeeded; ownership remains for retry.
    }
  }

  bool _isEnded(ScheduleDoneStatus doneStatus) {
    return doneStatus == ScheduleDoneStatus.normalEnd ||
        doneStatus == ScheduleDoneStatus.lateEnd ||
        doneStatus == ScheduleDoneStatus.abnormalEnd;
  }

  PreparationWithTimeEntity _restoreElapsedSnapshot(
    TimedPreparationSnapshotEntity snapshot,
    DateTime now,
  ) {
    final elapsedSinceSave = now.difference(snapshot.savedAt);
    return elapsedSinceSave.isNegative
        ? snapshot.preparation
        : snapshot.preparation.timeElapsed(elapsedSinceSave);
  }

  PreparationWithTimeEntity _derivePreparationRun(
    PreparationWithTimeEntity source, {
    required DateTime startedAt,
    required List<PreparationActionEventEntity> actionEvents,
    required DateTime now,
  }) {
    var preparation = _resetPreparationProgress(source);
    var cursor = startedAt;
    final orderedEvents =
        actionEvents.where((event) => !event.occurredAt.isAfter(now)).toList()
          ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

    for (final event in orderedEvents) {
      if (event.occurredAt.isAfter(cursor)) {
        preparation = preparation.timeElapsed(
          event.occurredAt.difference(cursor),
        );
        cursor = event.occurredAt;
      }

      switch (event.type) {
        case PreparationActionEventType.start:
          cursor = event.occurredAt;
        case PreparationActionEventType.skipStep:
          preparation = _skipCurrentStepForEvent(preparation, event);
          cursor = event.occurredAt;
        case PreparationActionEventType.finish:
          return preparation.timeElapsed(now.difference(cursor));
      }
    }

    if (now.isAfter(cursor)) {
      preparation = preparation.timeElapsed(now.difference(cursor));
    }
    return preparation;
  }

  PreparationWithTimeEntity _resetPreparationProgress(
    PreparationWithTimeEntity source,
  ) {
    return PreparationWithTimeEntity(
      preparationStepList: [
        for (final step in source.preparationStepList)
          PreparationStepWithTimeEntity(
            id: step.id,
            preparationName: step.preparationName,
            preparationTime: step.preparationTime,
            nextPreparationId: step.nextPreparationId,
          ),
      ],
    );
  }

  PreparationWithTimeEntity _skipCurrentStepForEvent(
    PreparationWithTimeEntity preparation,
    PreparationActionEventEntity event,
  ) {
    final current = preparation.currentStep;
    if (current == null) {
      return preparation;
    }
    final eventStepId = event.stepId;
    final eventStepStillExists =
        eventStepId != null &&
        preparation.preparationStepList.any((step) => step.id == eventStepId);
    if (eventStepStillExists && current.id != eventStepId) {
      return preparation;
    }
    return preparation.copyWith(
      preparationStepList: [
        for (final step in preparation.preparationStepList)
          step.id == current.id ? step.copyWith(isDone: true) : step,
      ],
    );
  }
}

class PreparationStartReceipt {
  const PreparationStartReceipt({
    required this.startedAt,
    this.durableStartedAt,
    this.actionEvents = const [],
    this.hasPendingRecovery = false,
  });
  final DateTime? durableStartedAt;
  final List<PreparationActionEventEntity> actionEvents;
  final DateTime startedAt;
  final bool hasPendingRecovery;
}

class _StartRun {
  _StartRun(this.startedAt, this.fingerprint);
  final String fingerprint;
  DateTime startedAt;
  DateTime? durableStartedAt;
  bool initialized = false;
  bool committed = false;
  Future<PreparationStartReceipt>? flight;
}
