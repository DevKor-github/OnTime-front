import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/entities/early_start_session_entity.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
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
import 'package:on_time_front/domain/use-cases/schedule_preparation_session_use_case.dart';

void main() {
  test(
    'early start begins the schedule preparation session once and saves progress',
    () async {
      final scheduleRepository = _FakeScheduleRepository();
      final timedPreparationRepository = _FakeTimedPreparationRepository();
      final earlyStartSessionRepository = _FakeEarlyStartSessionRepository();
      final cancelScheduleAlarmUseCase = _FakeCancelScheduleAlarmUseCase();
      final useCase = SchedulePreparationSessionUseCase(
        scheduleRepository,
        _FakePreparationRepository(),
        timedPreparationRepository,
        earlyStartSessionRepository,
        cancelScheduleAlarmUseCase,
        _FakeReconcileAlarmsUseCase(),
      );
      final schedule = _scheduleWithPreparation('schedule-1');
      final startedAt = DateTime.utc(2026, 6, 28, 8);

      await useCase.startEarlySession(schedule, startedAt: startedAt);
      await useCase.startSchedulePreparation(schedule.id);

      expect(
        earlyStartSessionRepository.sessions[schedule.id],
        EarlyStartSessionEntity(scheduleId: schedule.id, startedAt: startedAt),
      );
      expect(scheduleRepository.startedScheduleIds, [schedule.id]);
      expect(cancelScheduleAlarmUseCase.cancelledScheduleIds, [schedule.id]);

      final snapshot = timedPreparationRepository.snapshots[schedule.id]!;
      expect(snapshot.preparation, schedule.preparation);
      expect(snapshot.savedAt, startedAt);
      expect(snapshot.scheduleFingerprint, schedule.cacheFingerprint);
    },
  );

  test(
    'matching timed preparation snapshot restores elapsed session progress',
    () async {
      final timedPreparationRepository = _FakeTimedPreparationRepository();
      final useCase = SchedulePreparationSessionUseCase(
        _FakeScheduleRepository(),
        _FakePreparationRepository(),
        timedPreparationRepository,
        _FakeEarlyStartSessionRepository(),
        _FakeCancelScheduleAlarmUseCase(),
        _FakeReconcileAlarmsUseCase(),
      );
      final schedule = _scheduleWithPreparation('schedule-1');
      final now = DateTime.utc(2026, 6, 28, 8, 10);
      final savedPreparation = schedule.preparation.timeElapsed(
        const Duration(minutes: 4),
      );
      timedPreparationRepository.snapshots[schedule.id] =
          TimedPreparationSnapshotEntity(
            preparation: savedPreparation,
            savedAt: now.subtract(const Duration(minutes: 2)),
            scheduleFingerprint: schedule.cacheFingerprint,
          );

      final restored = await useCase.restoreTimedPreparationIfValid(
        schedule,
        now: now,
      );

      expect(
        restored.preparation.currentStep!.elapsedTime,
        const Duration(minutes: 6),
      );
      expect(timedPreparationRepository.clearedScheduleIds, isEmpty);
    },
  );

  test(
    'stale timed preparation snapshot clears persisted session state',
    () async {
      final timedPreparationRepository = _FakeTimedPreparationRepository();
      final earlyStartSessionRepository = _FakeEarlyStartSessionRepository();
      final useCase = SchedulePreparationSessionUseCase(
        _FakeScheduleRepository(),
        _FakePreparationRepository(),
        timedPreparationRepository,
        earlyStartSessionRepository,
        _FakeCancelScheduleAlarmUseCase(),
        _FakeReconcileAlarmsUseCase(),
      );
      final schedule = _scheduleWithPreparation('schedule-1');
      final startedAt = DateTime.utc(2026, 6, 28, 7, 50);
      earlyStartSessionRepository.sessions[schedule.id] =
          EarlyStartSessionEntity(
            scheduleId: schedule.id,
            startedAt: startedAt,
          );
      timedPreparationRepository.snapshots[schedule.id] =
          TimedPreparationSnapshotEntity(
            preparation: schedule.preparation.timeElapsed(
              const Duration(minutes: 4),
            ),
            savedAt: startedAt,
            scheduleFingerprint: 'old-fingerprint',
          );

      final restored = await useCase.restoreTimedPreparationIfValid(
        schedule,
        now: DateTime.utc(2026, 6, 28, 8),
      );

      expect(restored, schedule);
      expect(timedPreparationRepository.clearedScheduleIds, [schedule.id]);
      expect(earlyStartSessionRepository.clearedScheduleIds, [schedule.id]);
    },
  );

  test(
    'ended prompted schedule is rejected and scheduled delivery is cancelled',
    () async {
      final scheduleRepository = _FakeScheduleRepository();
      final preparationRepository = _FakePreparationRepository();
      final cancelScheduleAlarmUseCase = _FakeCancelScheduleAlarmUseCase();
      final useCase = SchedulePreparationSessionUseCase(
        scheduleRepository,
        preparationRepository,
        _FakeTimedPreparationRepository(),
        _FakeEarlyStartSessionRepository(),
        cancelScheduleAlarmUseCase,
        _FakeReconcileAlarmsUseCase(),
      );
      scheduleRepository.schedulesById['schedule-1'] = _scheduleEntity(
        'schedule-1',
        doneStatus: ScheduleDoneStatus.normalEnd,
      );

      final result = await useCase.resolvePromptedSchedule(
        scheduleId: 'schedule-1',
        startPreparation: false,
      );

      expect(result.status, SchedulePreparationPromptStatus.rejected);
      expect(result.schedule, isNull);
      expect(cancelScheduleAlarmUseCase.cancelledScheduleIds, ['schedule-1']);
      expect(preparationRepository.loadedScheduleIds, isEmpty);
    },
  );

  test(
    'valid prompted schedule loads preparation and returns ready schedule',
    () async {
      final scheduleRepository = _FakeScheduleRepository();
      final preparationRepository = _FakePreparationRepository();
      final cancelScheduleAlarmUseCase = _FakeCancelScheduleAlarmUseCase();
      final useCase = SchedulePreparationSessionUseCase(
        scheduleRepository,
        preparationRepository,
        _FakeTimedPreparationRepository(),
        _FakeEarlyStartSessionRepository(),
        cancelScheduleAlarmUseCase,
        _FakeReconcileAlarmsUseCase(),
      );
      final schedule = _scheduleEntity('schedule-1');
      final preparation = _preparation('prep-1');
      final expectedSchedule =
          ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
            schedule,
            PreparationWithTimeEntity.fromPreparation(preparation),
          );
      scheduleRepository.schedulesById[schedule.id] = schedule;
      preparationRepository.preparationsById[schedule.id] = preparation;

      final result = await useCase.resolvePromptedSchedule(
        scheduleId: schedule.id,
        startPreparation: false,
        scheduleFingerprint: expectedSchedule.cacheFingerprint,
      );

      expect(result.status, SchedulePreparationPromptStatus.ready);
      expect(result.schedule, expectedSchedule);
      expect(preparationRepository.loadedScheduleIds, [schedule.id]);
      expect(cancelScheduleAlarmUseCase.cancelledScheduleIds, isEmpty);
    },
  );

  test('prompt validation failure rejects only non-start prompts', () async {
    final scheduleRepository = _FakeScheduleRepository()
      ..throwingIds.addAll({'ready-prompt', 'start-prompt'});
    final cancelScheduleAlarmUseCase = _FakeCancelScheduleAlarmUseCase();
    final useCase = SchedulePreparationSessionUseCase(
      scheduleRepository,
      _FakePreparationRepository(),
      _FakeTimedPreparationRepository(),
      _FakeEarlyStartSessionRepository(),
      cancelScheduleAlarmUseCase,
      _FakeReconcileAlarmsUseCase(),
    );

    final readyPrompt = await useCase.resolvePromptedSchedule(
      scheduleId: 'ready-prompt',
      startPreparation: false,
    );
    final startPrompt = await useCase.resolvePromptedSchedule(
      scheduleId: 'start-prompt',
      startPreparation: true,
    );

    expect(readyPrompt.status, SchedulePreparationPromptStatus.rejected);
    expect(startPrompt.status, SchedulePreparationPromptStatus.unavailable);
    expect(cancelScheduleAlarmUseCase.cancelledScheduleIds, ['ready-prompt']);
  });

  test(
    'finish completes the preparation session and clears scheduled delivery',
    () async {
      final scheduleRepository = _FakeScheduleRepository();
      final timedPreparationRepository = _FakeTimedPreparationRepository();
      final earlyStartSessionRepository = _FakeEarlyStartSessionRepository();
      final cancelScheduleAlarmUseCase = _FakeCancelScheduleAlarmUseCase();
      final reconcileAlarmsUseCase = _FakeReconcileAlarmsUseCase();
      final useCase = SchedulePreparationSessionUseCase(
        scheduleRepository,
        _FakePreparationRepository(),
        timedPreparationRepository,
        earlyStartSessionRepository,
        cancelScheduleAlarmUseCase,
        reconcileAlarmsUseCase,
      );
      final schedule = _scheduleWithPreparation('schedule-1');
      timedPreparationRepository.snapshots[schedule.id] =
          TimedPreparationSnapshotEntity(
            preparation: schedule.preparation,
            savedAt: DateTime.utc(2026, 6, 28, 8),
            scheduleFingerprint: schedule.cacheFingerprint,
          );
      earlyStartSessionRepository.sessions[schedule.id] =
          EarlyStartSessionEntity(
            scheduleId: schedule.id,
            startedAt: DateTime.utc(2026, 6, 28, 7, 55),
          );

      await useCase.finishSchedulePreparation(schedule.id, latenessTime: 7);
      await pumpEventQueue();

      expect(scheduleRepository.startedScheduleIds, [schedule.id]);
      expect(scheduleRepository.finishedSchedules, [(schedule.id, 7)]);
      expect(cancelScheduleAlarmUseCase.cancelledScheduleIds, [schedule.id]);
      expect(timedPreparationRepository.clearedScheduleIds, [schedule.id]);
      expect(earlyStartSessionRepository.clearedScheduleIds, [schedule.id]);
      expect(reconcileAlarmsUseCase.callCount, 1);
    },
  );
}

ScheduleWithPreparationEntity _scheduleWithPreparation(String id) {
  final schedule = _scheduleEntity(id);
  return ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
    schedule,
    const PreparationWithTimeEntity(
      preparationStepList: [
        PreparationStepWithTimeEntity(
          id: 'prep-1',
          preparationName: 'Pack',
          preparationTime: Duration(minutes: 15),
          nextPreparationId: null,
        ),
      ],
    ),
  );
}

ScheduleEntity _scheduleEntity(
  String id, {
  ScheduleDoneStatus doneStatus = ScheduleDoneStatus.notEnded,
}) {
  return ScheduleWithPreparationEntity(
    id: id,
    place: const PlaceEntity(id: 'place-1', placeName: 'Office'),
    scheduleName: 'Meeting',
    scheduleTime: DateTime.utc(2026, 6, 28, 9),
    moveTime: const Duration(minutes: 10),
    isChanged: false,
    isStarted: false,
    scheduleSpareTime: const Duration(minutes: 5),
    scheduleNote: '',
    doneStatus: doneStatus,
    preparation: const PreparationWithTimeEntity(preparationStepList: []),
  );
}

PreparationEntity _preparation(String id) {
  return PreparationEntity(
    preparationStepList: [
      PreparationStepEntity(
        id: id,
        preparationName: 'Pack',
        preparationTime: const Duration(minutes: 15),
      ),
    ],
  );
}

class _FakeScheduleRepository implements ScheduleRepository {
  final startedScheduleIds = <String>[];
  final finishedSchedules = <(String, int)>[];
  final schedulesById = <String, ScheduleEntity>{};
  final throwingIds = <String>{};

  @override
  Stream<Set<ScheduleEntity>> get scheduleStream => const Stream.empty();

  @override
  Stream<List<ScheduleEntity>> watchSchedulesByDate(
    DateTime startDate,
    DateTime endDate,
  ) => const Stream.empty();

  @override
  Future<void> startSchedule(String scheduleId) async {
    startedScheduleIds.add(scheduleId);
  }

  @override
  Future<void> finishSchedule(String scheduleId, int latenessTime) async {
    finishedSchedules.add((scheduleId, latenessTime));
  }

  @override
  Future<ScheduleEntity> getScheduleById(String id) async {
    if (throwingIds.contains(id)) {
      throw Exception('schedule unavailable');
    }
    return schedulesById[id] ?? _scheduleWithPreparation(id);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePreparationRepository implements PreparationRepository {
  final controller =
      StreamController<Map<String, PreparationEntity>>.broadcast();
  final loadedScheduleIds = <String>[];
  final preparationsById = <String, PreparationEntity>{};

  @override
  Stream<Map<String, PreparationEntity>> get preparationStream =>
      controller.stream;

  @override
  Future<void> getPreparationByScheduleId(String scheduleId) async {
    loadedScheduleIds.add(scheduleId);
    final preparation = preparationsById[scheduleId];
    if (preparation != null) {
      controller.add({scheduleId: preparation});
    }
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTimedPreparationRepository implements TimedPreparationRepository {
  final snapshots = <String, TimedPreparationSnapshotEntity>{};
  final clearedScheduleIds = <String>[];

  @override
  Future<void> saveTimedPreparationSnapshot(
    String scheduleId,
    TimedPreparationSnapshotEntity snapshot,
  ) async {
    snapshots[scheduleId] = snapshot;
  }

  @override
  Future<TimedPreparationSnapshotEntity?> getTimedPreparationSnapshot(
    String scheduleId,
  ) async {
    return snapshots[scheduleId];
  }

  @override
  Future<void> clearTimedPreparation(String scheduleId) async {
    clearedScheduleIds.add(scheduleId);
    snapshots.remove(scheduleId);
  }
}

class _FakeEarlyStartSessionRepository implements EarlyStartSessionRepository {
  final sessions = <String, EarlyStartSessionEntity>{};
  final clearedScheduleIds = <String>[];

  @override
  Future<void> markStarted({
    required String scheduleId,
    required DateTime startedAt,
  }) async {
    sessions[scheduleId] = EarlyStartSessionEntity(
      scheduleId: scheduleId,
      startedAt: startedAt,
    );
  }

  @override
  Future<EarlyStartSessionEntity?> getSession(String scheduleId) async {
    return sessions[scheduleId];
  }

  @override
  Future<void> clear(String scheduleId) async {
    clearedScheduleIds.add(scheduleId);
    sessions.remove(scheduleId);
  }
}

class _FakeCancelScheduleAlarmUseCase implements CancelScheduleAlarmUseCase {
  final cancelledScheduleIds = <String>[];

  @override
  Future<void> call(String scheduleId) async {
    cancelledScheduleIds.add(scheduleId);
  }
}

class _FakeReconcileAlarmsUseCase implements ReconcileAlarmsUseCase {
  int callCount = 0;

  @override
  Future<AlarmReconciliationResult> call() async {
    callCount += 1;
    final now = DateTime.utc(2026, 6, 28, 8);
    return AlarmReconciliationResult(
      status: AlarmReconciliationStatus.armed,
      nativeAlarmProvider: AlarmProvider.none,
      fallbackProvider: AlarmProvider.localNotification,
      armedScheduleIds: const [],
      skippedScheduleCount: 0,
      failures: const [],
      scheduleWindowStart: now,
      scheduleWindowEnd: now,
      alarmCoverageStart: now,
      alarmCoverageEnd: now,
    );
  }
}
