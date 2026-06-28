import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
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
    await saveTimedPreparationSnapshot(schedule, savedAt: startedAt);
  }

  Future<void> startSchedulePreparation(String scheduleId) async {
    if (!_startedScheduleIds.add(scheduleId)) return;
    await _scheduleRepository.startSchedule(scheduleId);
  }

  Future<bool> hasEarlyStartSession(String scheduleId) async {
    return await _earlyStartSessionRepository.getSession(scheduleId) != null;
  }

  Future<void> saveTimedPreparationSnapshot(
    ScheduleWithPreparationEntity schedule, {
    DateTime? savedAt,
  }) {
    final snapshot = TimedPreparationSnapshotEntity(
      preparation: schedule.preparation,
      savedAt: savedAt ?? DateTime.now(),
      scheduleFingerprint: schedule.cacheFingerprint,
    );
    return _timedPreparationRepository.saveTimedPreparationSnapshot(
      schedule.id,
      snapshot,
    );
  }

  Future<ScheduleWithPreparationEntity> restoreTimedPreparationIfValid(
    ScheduleWithPreparationEntity schedule, {
    required DateTime now,
  }) async {
    final snapshot = await _timedPreparationRepository
        .getTimedPreparationSnapshot(schedule.id);
    if (snapshot == null) return schedule;
    if (snapshot.scheduleFingerprint != schedule.cacheFingerprint) {
      await clearPersistedState(schedule.id);
      return schedule;
    }

    final elapsedSinceSave = now.difference(snapshot.savedAt);
    final restoredPreparation = elapsedSinceSave.isNegative
        ? snapshot.preparation
        : snapshot.preparation.timeElapsed(elapsedSinceSave);

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
}
