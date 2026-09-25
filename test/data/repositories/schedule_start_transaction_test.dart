import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/domain/entities/early_start_session_entity.dart';
import 'package:on_time_front/domain/entities/preparation_action_event_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/entities/timed_preparation_snapshot_entity.dart';
import 'package:on_time_front/domain/repositories/early_start_session_repository.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';
import 'package:on_time_front/domain/use-cases/schedule_preparation_session_use_case.dart';
import 'package:on_time_front/domain/use-cases/cancel_schedule_alarm_use_case.dart';
import '../../helpers/noop_alarm_reconciliation.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/repositories/schedule_repository_impl.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/repositories/timed_preparation_repository.dart';

void main() {
  late AppDatabase db;
  late ScheduleRepositoryImpl repository;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = ScheduleRepositoryImpl(
      database: db,
      timedPreparationRepository: _Runtime(),
    );
    await db.userDao.putUser(
      const UserEntity(
        id: 'local-profile',
        spareTime: Duration.zero,
        note: '',
        isOnboardingCompleted: true,
      ),
    );
    await repository.createSchedule(
      ScheduleEntity(
        id: 'one',
        place: const PlaceEntity(id: 'place', placeName: 'place'),
        scheduleName: 'one',
        scheduleTime: DateTime.utc(2026, 10),
        moveTime: Duration.zero,
        isChanged: false,
        isStarted: false,
        scheduleSpareTime: Duration.zero,
        scheduleNote: '',
      ),
    );
  });
  tearDown(() async {
    await repository.dispose();
    await db.close();
  });
  Future<int> revision() async =>
      (await db.select(db.users).getSingle()).dataRevision;

  test(
    'a failed revision write rolls back the schedule transition and retry succeeds',
    () async {
      final before = await revision();
      await db.customStatement(
        "CREATE TRIGGER reject_revision BEFORE UPDATE OF data_revision ON users BEGIN SELECT RAISE(ABORT, 'revision failed'); END",
      );
      await expectLater(repository.startSchedule('one'), throwsA(anything));
      final failed = await repository.getScheduleById('one');
      expect(failed.isStarted, isFalse);
      expect(failed.startedAt, isNull);
      expect(failed.preparationFrozen, isFalse);
      expect(await revision(), before);
      await db.customStatement('DROP TRIGGER reject_revision');
      await repository.startSchedule('one');
      expect((await repository.getScheduleById('one')).isStarted, isTrue);
      expect(await revision(), before + 1);
    },
  );

  test(
    'concurrent and repeated starts preserve first timestamp and one revision',
    () async {
      final before = await revision();
      await Future.wait([
        repository.startSchedule('one'),
        repository.startSchedule('one'),
      ]);
      final first = await repository.getScheduleById('one');
      await repository.startSchedule('one');
      expect(
        (await repository.getScheduleById('one')).startedAt,
        first.startedAt,
      );
      expect(await revision(), before + 1);
      expect(first.preparationFrozen, isTrue);
    },
  );

  for (final (confirmation, missing) in [
    (false, false),
    (true, false),
    (false, true),
  ]) {
    test(
      'fresh session respects valid run vs explicit confirmation=$confirmation missing=$missing without overwriting durable first start',
      () async {
        final t0 = DateTime.utc(2026, 1, 1);
        final t1 = t0.add(const Duration(hours: 1));
        final t2 = t1.add(const Duration(hours: 1));
        await repository.startSchedule('one', startedAt: t0);
        final before = await revision();
        final schedule =
            ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
              await repository.getScheduleById('one'),
              const PreparationWithTimeEntity(
                preparationStepList: [
                  PreparationStepWithTimeEntity(
                    id: 'step',
                    preparationName: 'prep',
                    preparationTime: Duration(minutes: 10),
                    nextPreparationId: null,
                  ),
                ],
              ),
            );
        final skip = PreparationActionEventEntity.skipStep(
          stepId: 'step',
          occurredAt: t1.add(const Duration(seconds: 1)),
        );
        final runtime = _Runtime();
        if (!missing) {
          runtime.snapshots['one'] = TimedPreparationSnapshotEntity(
            preparation: schedule.preparation,
            savedAt: t1,
            scheduleFingerprint: schedule.cacheFingerprint,
            startedAt: t1,
            requiresConfirmation: confirmation,
            actionEvents: [skip],
          );
        }
        final owner = AlarmOperationCoordinator(LocalDataOperationGate());
        final early = _Early();
        final session = SchedulePreparationSessionUseCase(
          repository,
          _Preparation(),
          runtime,
          early,
          _Cancel(),
          NoopAlarmReconciliation(),
          operations: owner,
        );
        addTearDown(session.dispose);
        final receipt = await session.startEarlySession(
          schedule,
          startedAt: t2,
        );
        expect(receipt.durableStartedAt!.toUtc(), t0);
        expect(receipt.startedAt.toUtc(), (confirmation || missing) ? t2 : t1);
        expect(
          runtime.snapshots['one']!.startedAt!.toUtc(),
          (confirmation || missing) ? t2 : t1,
        );
        expect(
          runtime.snapshots['one']!.actionEvents,
          (confirmation || missing) ? isEmpty : [skip],
        );
        expect(
          (await repository.getScheduleById('one')).startedAt!.toUtc(),
          t0,
        );
        expect(await revision(), before);
        owner.dispose();
      },
    );
  }

  test('completed and deleted occurrences cannot restart', () async {
    await repository.finishSchedule('one', 0);
    final before = await revision();
    await expectLater(repository.startSchedule('one'), throwsA(anything));
    expect(
      (await repository.getScheduleById('one')).doneStatus,
      ScheduleDoneStatus.normalEnd,
    );
    expect(await revision(), before);
    await repository.deleteSchedule(await repository.getScheduleById('one'));
    await expectLater(repository.startSchedule('one'), throwsA(anything));
  });
}

class _Runtime implements TimedPreparationRepository {
  final snapshots = <String, TimedPreparationSnapshotEntity>{};
  @override
  Future<void> clearTimedPreparation(String id) async {
    snapshots.remove(id);
  }

  @override
  Future<TimedPreparationSnapshotEntity?> getTimedPreparationSnapshot(
    String id,
  ) async => snapshots[id];
  @override
  Future<void> saveTimedPreparationSnapshot(
    String id,
    TimedPreparationSnapshotEntity value,
  ) async {
    snapshots[id] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Preparation implements PreparationRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Cancel implements CancelScheduleAlarmUseCase {
  @override
  Future<void> call(String id) async {}
}

class _Early implements EarlyStartSessionRepository {
  final sessions = <String, EarlyStartSessionEntity>{};
  @override
  Future<void> clear(String id) async {
    sessions.remove(id);
  }

  @override
  Future<EarlyStartSessionEntity?> getSession(String id) async => sessions[id];
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
}
