import 'package:on_time_front/domain/entities/preparation_action_event_entity.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:rxdart/rxdart.dart';
import 'package:on_time_front/domain/entities/schedule_not_found.dart';
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
    'pending callers share failure, then retry the same instance and timestamp',
    () async {
      final schedules = _FakeScheduleRepository()
        ..startBarrier = Completer<void>()
        ..failStarts = 1;
      final early = _FakeEarlyStartSessionRepository();
      final owner = AlarmOperationCoordinator(LocalDataOperationGate());
      final useCase = SchedulePreparationSessionUseCase(
        schedules,
        _FakePreparationRepository(),
        _FakeTimedPreparationRepository(),
        early,
        _FakeCancelScheduleAlarmUseCase(),
        _FakeReconcileAlarmsUseCase(),
        operations: owner,
      );
      addTearDown(useCase.dispose);
      final schedule = _scheduleWithPreparation('pending');
      final time = DateTime.utc(2026, 9, 1);
      final first = useCase.startEarlySession(schedule, startedAt: time);
      final second = useCase.startEarlySession(
        schedule,
        startedAt: time.add(const Duration(minutes: 1)),
      );
      var completed = false;
      final firstError = expectLater(first, throwsStateError);
      final secondError = expectLater(
        second,
        throwsStateError,
      ).then((_) => completed = true);
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      expect(early.sessions, isEmpty);
      schedules.startBarrier!.complete();
      await Future.wait([firstError, secondError]);
      final retried = await useCase.startEarlySession(
        schedule,
        startedAt: time.add(const Duration(minutes: 2)),
      );
      expect(retried.startedAt, time);
      expect(schedules.requestedTimes, [time, time]);
      expect(early.sessions[schedule.id]!.startedAt, time);
      owner.dispose();
    },
  );

  test(
    'snapshot failure is partial and retry preserves a newer skip projection',
    () async {
      final schedules = _FakeScheduleRepository();
      final snapshots = _FakeTimedPreparationRepository()..failWrites = 1;
      final owner = AlarmOperationCoordinator(LocalDataOperationGate());
      final useCase = SchedulePreparationSessionUseCase(
        schedules,
        _FakePreparationRepository(),
        snapshots,
        _FakeEarlyStartSessionRepository(),
        _FakeCancelScheduleAlarmUseCase(),
        _FakeReconcileAlarmsUseCase(),
        operations: owner,
      );
      addTearDown(useCase.dispose);
      final schedule = _scheduleWithPreparation('partial');
      final time = DateTime.utc(2026);
      final first = await useCase.startEarlySession(schedule, startedAt: time);
      expect(first.hasPendingRecovery, isTrue);
      final event = PreparationActionEventEntity.skipStep(
        stepId: schedule.preparation.preparationStepList.first.id,
        occurredAt: time.add(const Duration(seconds: 2)),
      );
      await useCase.saveTimedPreparationSnapshot(
        schedule,
        startedAt: time,
        actionEvents: [event],
      );
      final retry = await useCase.startEarlySession(
        schedule,
        startedAt: time.add(const Duration(minutes: 2)),
      );
      expect(retry.startedAt, time);
      expect(retry.hasPendingRecovery, isFalse);
      expect(schedules.startedScheduleIds, [schedule.id]);
      expect(snapshots.snapshots[schedule.id]!.actionEvents, [event]);
      owner.dispose();
    },
  );

  test(
    'replacement generation does not reuse an old flight or write old runtime',
    () async {
      final gate = LocalDataOperationGate();
      final owner = AlarmOperationCoordinator(gate);
      final schedules = _FakeScheduleRepository()
        ..startBarrier = Completer<void>();
      final early = _FakeEarlyStartSessionRepository();
      final useCase = SchedulePreparationSessionUseCase(
        schedules,
        _FakePreparationRepository(),
        _FakeTimedPreparationRepository(),
        early,
        _FakeCancelScheduleAlarmUseCase(),
        _FakeReconcileAlarmsUseCase(),
        operations: owner,
      );
      addTearDown(useCase.dispose);
      final schedule = _scheduleWithPreparation('same-id');
      final old = useCase.startEarlySession(
        schedule,
        startedAt: DateTime.utc(2026),
      );
      final oldFailure = expectLater(
        old,
        throwsA(isA<AlarmOperationInvalidated>()),
      );
      await Future<void>.delayed(Duration.zero);
      await gate.run(() async {}, replacesData: true);
      schedules.startBarrier!.complete();
      await oldFailure;
      expect(early.sessions, isEmpty);
      final freshTime = DateTime.utc(2027);
      expect(
        (await useCase.startEarlySession(
          schedule,
          startedAt: freshTime,
        )).startedAt,
        freshTime,
      );
      expect(schedules.startedScheduleIds, [schedule.id, schedule.id]);
      owner.dispose();
    },
  );

  test(
    'marker failure keeps durable run and a bounded retry preserves its clock',
    () async {
      final schedules = _FakeScheduleRepository();
      final early = _FakeEarlyStartSessionRepository()..failWrites = 1;
      final snapshots = _FakeTimedPreparationRepository();
      final owner = AlarmOperationCoordinator(LocalDataOperationGate());
      final session = SchedulePreparationSessionUseCase(
        schedules,
        _FakePreparationRepository(),
        snapshots,
        early,
        _FakeCancelScheduleAlarmUseCase(),
        _FakeReconcileAlarmsUseCase(),
        operations: owner,
      );
      addTearDown(session.dispose);
      final schedule = _scheduleWithPreparation('marker');
      final first = await session.startEarlySession(
        schedule,
        startedAt: DateTime.utc(2026),
      );
      expect(first.hasPendingRecovery, isTrue);
      expect(snapshots.snapshots[schedule.id], isNotNull);
      expect(early.sessions, isEmpty);
      final retry = await session.startEarlySession(
        schedule,
        startedAt: DateTime.utc(2027),
      );
      expect(retry.hasPendingRecovery, isFalse);
      expect(retry.startedAt, first.startedAt);
      expect(schedules.startedScheduleIds, [schedule.id]);
      owner.dispose();
    },
  );

  test(
    'finish while start cleanup is pending cannot resurrect the run',
    () async {
      final schedules = _FakeScheduleRepository();
      final snapshots = _FakeTimedPreparationRepository();
      final early = _FakeEarlyStartSessionRepository();
      final cancel = _FakeCancelScheduleAlarmUseCase()
        ..barrier = Completer<void>();
      final owner = AlarmOperationCoordinator(LocalDataOperationGate());
      final session = SchedulePreparationSessionUseCase(
        schedules,
        _FakePreparationRepository(),
        snapshots,
        early,
        cancel,
        _FakeReconcileAlarmsUseCase(),
        operations: owner,
      );
      addTearDown(session.dispose);
      final schedule = _scheduleWithPreparation('finish');
      final start = session.startEarlySession(
        schedule,
        startedAt: DateTime.utc(2026),
      );
      final stale = expectLater(
        start,
        throwsA(isA<AlarmOperationInvalidated>()),
      );
      await cancel.entered.future;
      final finish = session.finishSchedulePreparation(
        schedule.id,
        latenessTime: 0,
      );
      await Future<void>.delayed(Duration.zero);
      cancel.barrier!.complete();
      await finish;
      await stale;
      expect(snapshots.snapshots, isEmpty);
      expect(early.sessions, isEmpty);
      expect(schedules.finishedSchedules, [(schedule.id, 0)]);
      owner.dispose();
    },
  );

  test(
    'dispose detaches the shared listener without releasing in-flight ownership',
    () async {
      final owner = AlarmOperationCoordinator(LocalDataOperationGate());
      final schedules = _FakeScheduleRepository()
        ..startBarrier = Completer<void>();
      final early = _FakeEarlyStartSessionRepository();
      final session = SchedulePreparationSessionUseCase(
        schedules,
        _FakePreparationRepository(),
        _FakeTimedPreparationRepository(),
        early,
        _FakeCancelScheduleAlarmUseCase(),
        _FakeReconcileAlarmsUseCase(),
        operations: owner,
      );
      final future = session.startEarlySession(
        _scheduleWithPreparation('dispose'),
        startedAt: DateTime.utc(2026),
      );
      final failure = expectLater(
        future,
        throwsA(isA<AlarmOperationInvalidated>()),
      );
      await Future<void>.delayed(Duration.zero);
      // Observe shared-owner subscription lifetime without adding a production debug API.
      // ignore: invalid_use_of_protected_member
      expect(owner.hasListeners, isTrue);
      session.dispose();
      // Observe shared-owner subscription lifetime without adding a production debug API.
      // ignore: invalid_use_of_protected_member
      expect(owner.hasListeners, isFalse);
      var released = false;
      final following = owner.cleanup(() async {
        released = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(released, isFalse);
      schedules.startBarrier!.complete();
      await failure;
      await following;
      expect(early.sessions, isEmpty);
      owner.dispose();
    },
  );

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
      addTearDown(useCase.dispose);
      final schedule = _scheduleWithPreparation('schedule-1');
      final startedAt = DateTime.utc(2026, 6, 28, 8);

      await useCase.startEarlySession(schedule, startedAt: startedAt);
      await useCase.startSchedulePreparation(schedule.id);

      expect(
        earlyStartSessionRepository.sessions[schedule.id],
        EarlyStartSessionEntity(scheduleId: schedule.id, startedAt: startedAt),
      );
      expect(scheduleRepository.startedScheduleIds, [schedule.id, schedule.id]);
      expect(cancelScheduleAlarmUseCase.cancelledScheduleIds, [schedule.id]);

      final snapshot = timedPreparationRepository.snapshots[schedule.id]!;
      expect(snapshot.preparation, schedule.preparation);
      expect(snapshot.savedAt, startedAt);
      expect(snapshot.scheduleFingerprint, schedule.cacheFingerprint);
    },
  );

  test(
    'cancellation failure does not undo committed start or skip its snapshot',
    () async {
      final schedules = _FakeScheduleRepository();
      final snapshots = _FakeTimedPreparationRepository();
      final early = _FakeEarlyStartSessionRepository();
      final reconcile = _FakeReconcileAlarmsUseCase();
      final useCase = SchedulePreparationSessionUseCase(
        schedules,
        _FakePreparationRepository(),
        snapshots,
        early,
        _FakeCancelScheduleAlarmUseCase()..fails = true,
        reconcile,
      );
      addTearDown(useCase.dispose);
      final schedule = _scheduleWithPreparation('schedule-1');
      await useCase.startEarlySession(schedule, startedAt: DateTime.utc(2026));
      expect(schedules.startedScheduleIds, [schedule.id]);
      expect(snapshots.snapshots[schedule.id], isNotNull);
      expect(reconcile.callCount, 1);
    },
  );

  test(
    'cancellation failure after finish still clears completed runtime',
    () async {
      final schedules = _FakeScheduleRepository();
      final snapshots = _FakeTimedPreparationRepository();
      final early = _FakeEarlyStartSessionRepository();
      final reconcile = _FakeReconcileAlarmsUseCase();
      final useCase = SchedulePreparationSessionUseCase(
        schedules,
        _FakePreparationRepository(),
        snapshots,
        early,
        _FakeCancelScheduleAlarmUseCase()..fails = true,
        reconcile,
      );
      addTearDown(useCase.dispose);
      await useCase.finishSchedulePreparation('schedule-1', latenessTime: 7);
      expect(schedules.finishedSchedules, [('schedule-1', 7)]);
      expect(snapshots.clearedScheduleIds, ['schedule-1']);
      expect(early.clearedScheduleIds, ['schedule-1']);
      expect(reconcile.callCount, 1);
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
      addTearDown(useCase.dispose);
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
      addTearDown(useCase.dispose);
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
      addTearDown(useCase.dispose);
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
      addTearDown(useCase.dispose);
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

  test('database failure retains both prompt kinds as unavailable', () async {
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
    addTearDown(useCase.dispose);

    final readyPrompt = await useCase.resolvePromptedSchedule(
      scheduleId: 'ready-prompt',
      startPreparation: false,
    );
    final startPrompt = await useCase.resolvePromptedSchedule(
      scheduleId: 'start-prompt',
      startPreparation: true,
    );

    expect(readyPrompt.status, SchedulePreparationPromptStatus.unavailable);
    expect(startPrompt.status, SchedulePreparationPromptStatus.unavailable);
    expect(cancelScheduleAlarmUseCase.cancelledScheduleIds, isEmpty);
  });

  test(
    'BehaviorSubject replay resolves the loaded map and stream errors stay unavailable',
    () async {
      final repository = _FakeScheduleRepository();
      repository.schedulesById['recurring-occurrence'] = _scheduleEntity(
        'recurring-occurrence',
        preparationDefinitionId: 'dedicated-definition',
      );
      final preparations = _ReplayPreparationRepository();
      final useCase = SchedulePreparationSessionUseCase(
        repository,
        preparations,
        _FakeTimedPreparationRepository(),
        _FakeEarlyStartSessionRepository(),
        _FakeCancelScheduleAlarmUseCase(),
        _FakeReconcileAlarmsUseCase(),
      );
      addTearDown(useCase.dispose);
      var result = await useCase.resolvePromptedSchedule(
        scheduleId: 'recurring-occurrence',
        startPreparation: false,
        isCurrent: () => true,
      );
      expect(result.status, SchedulePreparationPromptStatus.ready);
      expect(result.schedule!.id, 'recurring-occurrence');
      expect(result.schedule!.preparationDefinitionId, 'dedicated-definition');
      expect(
        result.schedule!.preparation.preparationStepList.single.preparationName,
        'Pack',
      );
      preparations.fail = true;
      result = await useCase.resolvePromptedSchedule(
        scheduleId: 'recurring-occurrence',
        startPreparation: false,
        isCurrent: () => true,
      );
      expect(result.status, SchedulePreparationPromptStatus.unavailable);
      await preparations.subject.close();
    },
  );

  test(
    'definitive missing is rejected without treating storage failure as missing',
    () async {
      final repository = _FakeScheduleRepository();
      final useCase = SchedulePreparationSessionUseCase(
        repository,
        _FakePreparationRepository(),
        _FakeTimedPreparationRepository(),
        _FakeEarlyStartSessionRepository(),
        _FakeCancelScheduleAlarmUseCase(),
        _FakeReconcileAlarmsUseCase(),
      );
      addTearDown(useCase.dispose);
      final result = await useCase.resolvePromptedSchedule(
        scheduleId: 'missing',
        startPreparation: false,
        isCurrent: () => true,
      );
      expect(result.status, SchedulePreparationPromptStatus.rejected);
    },
  );

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
      addTearDown(useCase.dispose);
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
  String? preparationDefinitionId,
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
    preparationDefinitionId: preparationDefinitionId,
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

  int failStarts = 0;
  Completer<void>? startBarrier;
  final requestedTimes = <DateTime?>[];
  @override
  Future<DateTime> startSchedule(
    String scheduleId, {
    DateTime? startedAt,
  }) async {
    startedScheduleIds.add(scheduleId);
    requestedTimes.add(startedAt);
    await startBarrier?.future;
    if (failStarts-- > 0) throw StateError('start write failed');
    return startedAt ?? DateTime.utc(2026);
  }

  @override
  Future<void> finishSchedule(String scheduleId, int latenessTime) async {
    finishedSchedules.add((scheduleId, latenessTime));
  }

  @override
  Future<ScheduleEntity> getScheduleById(String id) async {
    if (id == 'missing') throw ScheduleNotFound(id);
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
  int failWrites = 0;

  @override
  Future<void> saveTimedPreparationSnapshot(
    String scheduleId,
    TimedPreparationSnapshotEntity snapshot,
  ) async {
    if (failWrites-- > 0) throw StateError('snapshot write failed');
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
  int failWrites = 0;
  final sessions = <String, EarlyStartSessionEntity>{};
  final clearedScheduleIds = <String>[];

  @override
  Future<void> markStarted({
    required String scheduleId,
    required DateTime startedAt,
  }) async {
    if (failWrites-- > 0) throw StateError('marker unavailable');
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
  bool fails = false;
  Completer<void>? barrier;
  final entered = Completer<void>();

  @override
  Future<void> call(String scheduleId) async {
    cancelledScheduleIds.add(scheduleId);
    if (!entered.isCompleted) entered.complete();
    await barrier?.future;
    if (fails) throw const AlarmCleanupIncomplete();
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

class _ReplayPreparationRepository extends _FakePreparationRepository {
  final subject = BehaviorSubject<Map<String, PreparationEntity>>.seeded({});
  bool fail = false;
  @override
  Stream<Map<String, PreparationEntity>> get preparationStream =>
      subject.stream;
  @override
  Future<void> getPreparationByScheduleId(String scheduleId) async {
    if (fail) {
      subject.addError(StateError('storage'));
    } else {
      subject.add({scheduleId: _preparation('definition-step')});
    }
  }
}
