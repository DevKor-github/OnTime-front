import 'dart:async';

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
    await _cancelScheduleAlarmUseCase(schedule.id);
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
  }) async {
    final snapshot = await _timedPreparationRepository
        .getTimedPreparationSnapshot(schedule.id);
    if (snapshot == null) return schedule;
    if (snapshot.scheduleFingerprint != schedule.cacheFingerprint &&
        !_canRestoreAcrossFingerprintMismatch(snapshot, schedule)) {
      await clearPersistedState(schedule.id);
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
    await _cancelScheduleAlarmUseCase(scheduleId);
    await clearPersistedState(scheduleId);
    unawaited(_reconcileAlarmsUseCase());
  }

  Future<SchedulePreparationPromptResult> resolvePromptedSchedule({
    required String scheduleId,
    required bool startPreparation,
    String? scheduleFingerprint,
  }) async {
    try {
      final schedule = await _scheduleRepository.getScheduleById(scheduleId);
      if (_isEnded(schedule.doneStatus)) {
        await _cancelScheduleAlarmUseCase(scheduleId);
        return const SchedulePreparationPromptResult.rejected();
      }

      final preparationFuture = _preparationRepository.preparationStream
          .map((preparations) => preparations[scheduleId])
          .where((preparation) => preparation != null)
          .cast<PreparationEntity>()
          .first;
      await _preparationRepository.getPreparationByScheduleId(scheduleId);
      final preparation = await preparationFuture;
      final scheduleWithPreparation =
          ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
            schedule,
            PreparationWithTimeEntity.fromPreparation(preparation),
          );

      if (scheduleFingerprint != null &&
          scheduleFingerprint != scheduleWithPreparation.cacheFingerprint &&
          !startPreparation) {
        await _cancelScheduleAlarmUseCase(scheduleId);
        return const SchedulePreparationPromptResult.rejected();
      }

      return SchedulePreparationPromptResult.ready(scheduleWithPreparation);
    } catch (_) {
      if (startPreparation) {
        return const SchedulePreparationPromptResult.unavailable();
      }
      await _cancelScheduleAlarmUseCase(scheduleId);
      return const SchedulePreparationPromptResult.rejected();
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

  bool _canRestoreAcrossFingerprintMismatch(
    TimedPreparationSnapshotEntity snapshot,
    ScheduleWithPreparationEntity schedule,
  ) {
    return _scheduleTimingFingerprintPrefix(snapshot.scheduleFingerprint) ==
            _scheduleTimingFingerprintPrefix(schedule.cacheFingerprint) &&
        _hasSamePreparationShape(snapshot.preparation, schedule.preparation);
  }

  String _scheduleTimingFingerprintPrefix(String fingerprint) {
    final parts = fingerprint.split('|');
    if (parts.length < 4) {
      return fingerprint;
    }
    return '${parts[0]}|${parts[1]}|${parts[2]}|';
  }

  bool _hasSamePreparationShape(
    PreparationWithTimeEntity left,
    PreparationWithTimeEntity right,
  ) {
    final leftSteps = left.preparationStepList;
    final rightSteps = right.preparationStepList;
    if (leftSteps.length != rightSteps.length) {
      return false;
    }
    for (var index = 0; index < leftSteps.length; index++) {
      final leftStep = leftSteps[index];
      final rightStep = rightSteps[index];
      if (leftStep.preparationName != rightStep.preparationName ||
          leftStep.preparationTime != rightStep.preparationTime) {
        return false;
      }
    }
    return true;
  }
}
