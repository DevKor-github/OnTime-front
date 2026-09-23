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

@Singleton()
class SchedulePreparationSessionUseCase {
  SchedulePreparationSessionUseCase(
    this._scheduleRepository,
    this._preparationRepository,
    this._timedPreparationRepository,
    this._earlyStartSessionRepository,
    this._cancelScheduleAlarmUseCase,
    this._reconcileAlarmsUseCase,
  );

  final ScheduleRepository _scheduleRepository;
  final PreparationRepository _preparationRepository;
  final TimedPreparationRepository _timedPreparationRepository;
  final EarlyStartSessionRepository _earlyStartSessionRepository;
  final CancelScheduleAlarmUseCase _cancelScheduleAlarmUseCase;
  final ReconcileAlarmsUseCase _reconcileAlarmsUseCase;
  final Set<String> _startedScheduleIds = {};

  Future<void> startEarlySession(
    ScheduleWithPreparationEntity schedule, {
    required DateTime startedAt,
  }) async {
    await _earlyStartSessionRepository.markStarted(
      scheduleId: schedule.id,
      startedAt: startedAt,
    );
    await startSchedulePreparation(schedule.id);
    requestAlarmReconciliation(_reconcileAlarmsUseCase);
    if (!await _cancelDelivery(schedule.id)) return;
    await saveTimedPreparationSnapshot(
      schedule,
      savedAt: startedAt,
      startedAt: startedAt,
      actionEvents: const [],
    );
  }

  Future<void> startSchedulePreparation(String scheduleId) async {
    if (!_startedScheduleIds.add(scheduleId)) return;
    await _scheduleRepository.startSchedule(scheduleId);
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
  }) {
    final snapshot = TimedPreparationSnapshotEntity(
      preparation: schedule.preparation,
      savedAt: savedAt ?? DateTime.now(),
      scheduleFingerprint: schedule.cacheFingerprint,
      startedAt: startedAt,
      actionEvents: actionEvents,
    );
    return _timedPreparationRepository.saveTimedPreparationSnapshot(
      schedule.id,
      snapshot,
    );
  }

  Future<ScheduleWithPreparationEntity> restoreTimedPreparationIfValid(
    ScheduleWithPreparationEntity schedule, {
    required DateTime now,
    RestoredSessionCallback? onRestoredSession,
    void Function()? onInvalidated,
  }) async {
    final stored = await _timedPreparationRepository
        .getTimedPreparationSnapshot(schedule.id);
    if (stored == null) return schedule;
    final snapshot = validatePreparationSnapshot(stored, schedule);
    if (snapshot == null || snapshot.requiresConfirmation) {
      await clearPersistedState(schedule.id);
      await _timedPreparationRepository.saveTimedPreparationSnapshot(
        schedule.id,
        TimedPreparationSnapshotEntity(
          preparation: schedule.preparation,
          savedAt: now,
          scheduleFingerprint: schedule.cacheFingerprint,
          requiresConfirmation: true,
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
    );
  }

  Future<void> clearPersistedState(String scheduleId) async {
    await _timedPreparationRepository.clearTimedPreparation(scheduleId);
    await _earlyStartSessionRepository.clear(scheduleId);
    _startedScheduleIds.remove(scheduleId);
  }

  Future<void> finishSchedulePreparation(
    String scheduleId, {
    required int latenessTime,
  }) async {
    await startSchedulePreparation(scheduleId);
    await _scheduleRepository.finishSchedule(scheduleId, latenessTime);
    requestAlarmReconciliation(_reconcileAlarmsUseCase);
    if (!await _cancelDelivery(scheduleId)) return;
    await clearPersistedState(scheduleId);
  }

  Future<SchedulePreparationPromptResult> resolvePromptedSchedule({
    required String scheduleId,
    required bool startPreparation,
    String? scheduleFingerprint,
    bool Function()? isCurrent,
  }) async {
    bool current() => isCurrent?.call() ?? true;
    try {
      final schedule = await _scheduleRepository.getScheduleById(scheduleId);
      if (!current()) {
        return const SchedulePreparationPromptResult.unavailable();
      }
      if (_isEnded(schedule.doneStatus)) {
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
          );
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
