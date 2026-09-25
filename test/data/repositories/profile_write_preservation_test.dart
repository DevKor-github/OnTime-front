import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/data_sources/preparation_local_data_source.dart';
import 'package:on_time_front/data/repositories/preparation_repository_impl.dart';
import 'package:on_time_front/data/repositories/alarm_repository_impl.dart';
import 'package:on_time_front/data/repositories/schedule_repository_impl.dart';
import 'package:on_time_front/data/repositories/user_repository_impl.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/timed_preparation_snapshot_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/repositories/timed_preparation_repository.dart';

void main() {
  late AppDatabase db;
  late UserRepositoryImpl users;
  late PreparationRepositoryImpl preparations;
  late ScheduleRepositoryImpl schedules;
  const id = 'local-profile';
  const preparation = PreparationEntity(
    preparationStepList: [
      PreparationStepEntity(
        id: 'step',
        preparationName: 'Pack',
        preparationTime: Duration(minutes: 2),
      ),
    ],
  );

  Future<User> row() => db.select(db.users).getSingle();

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    users = UserRepositoryImpl(db);
    preparations = PreparationRepositoryImpl(
      preparationLocalDataSource: PreparationLocalDataSourceImpl(
        appDatabase: db,
      ),
      userRepository: users,
      database: db,
    );
    schedules = ScheduleRepositoryImpl(
      database: db,
      timedPreparationRepository: _NoopTimers(),
    );
    await db
        .into(db.users)
        .insert(
          UsersCompanion.insert(
            id: const Value(id),
            spareTime: 5,
            note: 'keep note',
            isOnboardingCompleted: const Value(true),
            eligibleOutcomeCount: const Value(10),
            onTimeOutcomeCount: const Value(8),
            alarmsEnabled: const Value(false),
            alarmOffsetMinutes: const Value(7),
            detailedNotificationContent: const Value(true),
            dataRevision: const Value(42),
            lastExportedRevision: const Value(42),
            lastExportedAt: Value(DateTime.utc(2026, 1, 3)),
            firstDurableDataAt: Value(DateTime.utc(2026, 1, 1)),
            lastDurableDataAt: Value(DateTime.utc(2026, 1, 2)),
          ),
        );
  });

  tearDown(() async {
    await preparations.dispose();
    await schedules.dispose();
    await users.dispose();
    await db.close();
  });

  void preservesMetadata(User actual, User before) {
    expect(actual.alarmsEnabled, before.alarmsEnabled);
    expect(actual.alarmOffsetMinutes, before.alarmOffsetMinutes);
    expect(
      actual.detailedNotificationContent,
      before.detailedNotificationContent,
    );
    expect(actual.lastExportedRevision, before.lastExportedRevision);
    expect(actual.lastExportedAt, before.lastExportedAt);
    expect(actual.firstDurableDataAt, before.firstDurableDataAt);
  }

  test(
    'alarm repository returns preserved offset and detail preference from the DB',
    () async {
      final repository = AlarmRepositoryImpl(
        database: db,
        scheduleRepository: schedules,
        preparationRepository: preparations,
      );
      final before = await row();
      final result = await repository.updateAlarmSettings(alarmsEnabled: true);
      expect(result.alarmsEnabled, true);
      expect(result.defaultAlarmOffsetMinutes, 7);
      expect(result.detailedNotificationContent, true);
      final after = await row();
      expect(after.dataRevision, 43);
      expect(after.eligibleOutcomeCount, before.eligibleOutcomeCount);
      expect(after.lastExportedRevision, before.lastExportedRevision);
      await repository.updateAlarmSettings(alarmsEnabled: true);
      expect(await row(), after);
    },
  );

  test(
    'score reset starts a new aggregate without recounting old completions',
    () async {
      await schedules.createSchedule(_schedule('old'));
      await schedules.createSchedule(_schedule('new'));
      await schedules.finishSchedule('old', 0);
      await db.userDao.resetScore(id);
      final reset = await row();
      await schedules.finishSchedule('old', 0);
      expect(await row(), reset);
      await schedules.finishSchedule('new', 3);
      final after = await row();
      expect(after.eligibleOutcomeCount, 1);
      expect(after.onTimeOutcomeCount, 0);
      expect(after.dataRevision, reset.dataRevision + 1);
      preservesMetadata(after, reset);
    },
  );

  test(
    'spare time preserves preferences, scores and export metadata',
    () async {
      final before = await row();
      await preparations.updateSpareTime(const Duration(minutes: 15));
      final after = await row();
      preservesMetadata(after, before);
      expect(after.spareTime, 15);
      expect(after.note, before.note);
      expect(after.isOnboardingCompleted, true);
      expect(after.eligibleOutcomeCount, 10);
      expect(after.onTimeOutcomeCount, 8);
      expect(after.dataRevision, 43);
    },
  );

  test(
    'repeated initial creation cannot replace an existing profile',
    () async {
      final before = await row();
      await db.userDao.createUser(
        const UserEntity(
          id: id,
          spareTime: Duration.zero,
          note: 'stale',
          eligibleOutcomeCount: 0,
        ),
      );
      expect(await row(), before);
    },
  );

  test('same preferences and empty score reset are exact no-ops', () async {
    final before = await row();
    await preparations.updateSpareTime(const Duration(minutes: 5));
    await db.userDao.updateAlarmSettings(userId: id, enabled: false);
    await db.userDao.updateDetailedNotificationContent(
      userId: id,
      enabled: true,
    );
    expect(await row(), before);
    await db.userDao.resetScore(id);
    final reset = await row();
    expect(reset.dataRevision, 43);
    preservesMetadata(reset, before);
    expect(reset.eligibleOutcomeCount, 0);
    expect(reset.onTimeOutcomeCount, 0);
    await db.userDao.resetScore(id);
    expect(await row(), reset);
  });

  test(
    'finish and spare time changes retain both results with one revision each',
    () async {
      await schedules.createSchedule(_schedule('one'));
      final before = await row();
      await Future.wait([
        schedules.finishSchedule('one', 0),
        preparations.updateSpareTime(const Duration(minutes: 15)),
      ]);
      final after = await row();
      preservesMetadata(after, before);
      expect(after.eligibleOutcomeCount, 11);
      expect(after.onTimeOutcomeCount, 9);
      expect(after.spareTime, 15);
      expect(after.dataRevision, before.dataRevision + 2);
      await schedules.finishSchedule('one', 0);
      expect(await row(), after);
    },
  );

  test(
    'concurrent finishes count distinct schedules once and duplicate only once',
    () async {
      await schedules.createSchedule(_schedule('one'));
      await schedules.createSchedule(_schedule('two'));
      final before = await row();
      await Future.wait([
        schedules.finishSchedule('one', 0),
        schedules.finishSchedule('one', 0),
        schedules.finishSchedule('two', 3),
      ]);
      final after = await row();
      preservesMetadata(after, before);
      expect(after.eligibleOutcomeCount, 12);
      expect(after.onTimeOutcomeCount, 9);
      expect(after.dataRevision, before.dataRevision + 2);
    },
  );

  test('revision failure rolls back setting and profile changes', () async {
    final before = await row();
    await _rejectRevision(db);
    await expectLater(
      preparations.updateSpareTime(const Duration(minutes: 15)),
      throwsA(anything),
    );
    expect(await row(), before);
    await expectLater(
      db.userDao.updateAlarmSettings(userId: id, enabled: true),
      throwsA(anything),
    );
    expect(await row(), before);
    await expectLater(
      db.userDao.updateDetailedNotificationContent(userId: id, enabled: false),
      throwsA(anything),
    );
    expect(await row(), before);
    await expectLater(db.userDao.resetScore(id), throwsA(anything));
    expect(await row(), before);
    await db.customStatement('DROP TRIGGER reject_revision');
    await preparations.updateSpareTime(const Duration(minutes: 15));
    expect((await row()).dataRevision, 43);
    await db.userDao.updateAlarmSettings(userId: id, enabled: true);
    expect((await row()).dataRevision, 44);
    expect((await row()).alarmsEnabled, isTrue);
    await db.userDao.updateDetailedNotificationContent(
      userId: id,
      enabled: false,
    );
    expect((await row()).dataRevision, 45);
    expect((await row()).detailedNotificationContent, isFalse);
    await db.userDao.resetScore(id);
    final recovered = await row();
    expect(recovered.dataRevision, 46);
    expect(recovered.eligibleOutcomeCount, 0);
    expect(recovered.onTimeOutcomeCount, 0);
    expect(recovered.note, before.note);
    expect(recovered.lastExportedRevision, before.lastExportedRevision);
    expect(recovered.firstDurableDataAt, before.firstDurableDataAt);
    await db.userDao.updateAlarmSettings(userId: id, enabled: true);
    await db.userDao.updateDetailedNotificationContent(
      userId: id,
      enabled: false,
    );
    await db.userDao.resetScore(id);
    expect(await row(), recovered);
  });

  test(
    'revision failure rolls back schedule result and score together',
    () async {
      await schedules.createSchedule(_schedule('one'));
      final before = await row();
      await _rejectRevision(db);
      await expectLater(schedules.finishSchedule('one', 0), throwsA(anything));
      expect(await row(), before);
      final schedule = await schedules.getScheduleById('one');
      expect(schedule.doneStatus, ScheduleDoneStatus.notEnded);
      expect(schedule.scoreContributionRecorded, false);
      await db.customStatement('DROP TRIGGER reject_revision');
      await schedules.finishSchedule('one', 0);
      final recovered = await row();
      expect(recovered.dataRevision, before.dataRevision + 1);
      expect(recovered.eligibleOutcomeCount, before.eligibleOutcomeCount + 1);
      expect(recovered.onTimeOutcomeCount, before.onTimeOutcomeCount + 1);
      final finished = await schedules.getScheduleById('one');
      expect(finished.doneStatus, ScheduleDoneStatus.normalEnd);
      expect(finished.scoreContributionRecorded, isTrue);
      await schedules.finishSchedule('one', 0);
      expect(await row(), recovered);
    },
  );

  test(
    'onboarding preparation and profile roll back if revision fails',
    () async {
      final before = await row();
      await _rejectRevision(db);
      await expectLater(
        preparations.createDefaultPreparation(
          preparationEntity: preparation,
          spareTime: const Duration(minutes: 15),
          note: 'new note',
        ),
        throwsA(anything),
      );
      expect(await row(), before);
      expect(
        (await preparations.getDefualtPreparation()).preparationStepList,
        isEmpty,
      );
      await db.customStatement('DROP TRIGGER reject_revision');
      await preparations.createDefaultPreparation(
        preparationEntity: preparation,
        spareTime: const Duration(minutes: 15),
        note: 'new note',
      );
      final after = await row();
      preservesMetadata(after, before);
      expect(after.dataRevision, 43);
      expect(after.note, 'new note');
      expect(after.eligibleOutcomeCount, 10);
      expect(await preparations.getDefualtPreparation(), preparation);
      await preparations.createDefaultPreparation(
        preparationEntity: preparation,
        spareTime: const Duration(minutes: 15),
        note: 'new note',
      );
      expect(await row(), after);
    },
  );

  test(
    'multiple preparation steps are a no-op even when caller omits links',
    () async {
      const steps = PreparationEntity(
        preparationStepList: [
          PreparationStepEntity(
            id: 'a',
            preparationName: 'Wash',
            preparationTime: Duration(minutes: 2),
          ),
          PreparationStepEntity(
            id: 'b',
            preparationName: 'Pack',
            preparationTime: Duration(minutes: 3),
          ),
        ],
      );
      await preparations.createDefaultPreparation(
        preparationEntity: steps,
        spareTime: const Duration(minutes: 5),
        note: 'keep note',
      );
      final before = await row();
      expect(before.dataRevision, 43);
      await preparations.createDefaultPreparation(
        preparationEntity: steps,
        spareTime: const Duration(minutes: 5),
        note: 'keep note',
      );
      expect(await row(), before);
      final stored = await preparations.getDefualtPreparation();
      expect(stored.preparationStepList.map((s) => s.id), ['a', 'b']);
      expect(stored.preparationStepList.first.nextPreparationId, 'b');
    },
  );

  test(
    'missing profile rejects updates and never reports a successful mutation',
    () async {
      await db.delete(db.users).go();
      await expectLater(
        preparations.updateSpareTime(const Duration(minutes: 1)),
        throwsStateError,
      );
      await expectLater(
        db.userDao.updateAlarmSettings(userId: id, enabled: true),
        throwsStateError,
      );
      await expectLater(
        db.userDao.updateDetailedNotificationContent(userId: id, enabled: true),
        throwsStateError,
      );
      await expectLater(db.userDao.resetScore(id), throwsStateError);
      await expectLater(
        db.userDao.markDurableDataChanged(id),
        throwsStateError,
      );
      expect(await db.select(db.users).get(), isEmpty);
    },
  );

  test(
    'empty profile starts without a durable revision and creation is race safe',
    () async {
      await db.delete(db.users).go();
      await Future.wait([users.getUser(), users.getUser()]);
      final initial = await row();
      expect(initial.dataRevision, 0);
      expect(initial.firstDurableDataAt, isNull);
      await preparations.updateSpareTime(const Duration(minutes: 1));
      final changed = await row();
      expect(changed.dataRevision, 1);
      expect(changed.firstDurableDataAt, isNotNull);
    },
  );

  test(
    'raw revision update notifies DB watchers and failed profile write publishes no success',
    () async {
      final notifications = <User>[];
      final subscription = db
          .select(db.users)
          .watchSingle()
          .listen(notifications.add);
      await db.select(db.users).watchSingle().first;
      final next = db
          .select(db.users)
          .watchSingle()
          .firstWhere((u) => u.dataRevision == 43);
      await db.userDao.markDurableDataChanged(id);
      expect((await next.timeout(const Duration(seconds: 3))).dataRevision, 43);
      await _rejectRevision(db);
      await expectLater(
        preparations.updateSpareTime(const Duration(minutes: 15)),
        throwsA(anything),
      );
      await db.select(db.users).watchSingle().first;
      expect(notifications.any((u) => u.spareTime == 15), false);
      await subscription.cancel();
    },
  );
}

Future<void> _rejectRevision(AppDatabase db) => db.customStatement('''
CREATE TRIGGER reject_revision BEFORE UPDATE OF data_revision ON users
BEGIN SELECT RAISE(ABORT, 'injected revision failure'); END
''');

ScheduleEntity _schedule(String id) => ScheduleEntity(
  id: id,
  place: const PlaceEntity(id: 'place', placeName: 'Office'),
  scheduleName: id,
  timeZoneId: 'Asia/Seoul',
  occurrenceOffsetSeconds: 32400,
  scheduleTime: DateTime(2026, 10, 1, 9),
  moveTime: const Duration(minutes: 10),
  isChanged: false,
  isStarted: false,
  scheduleSpareTime: Duration.zero,
  scheduleNote: '',
);

class _NoopTimers implements TimedPreparationRepository {
  @override
  Future<void> clearTimedPreparation(String scheduleId) async {}
  @override
  Future<TimedPreparationSnapshotEntity?> getTimedPreparationSnapshot(
    String scheduleId,
  ) async => null;
  @override
  Future<void> saveTimedPreparationSnapshot(
    String scheduleId,
    TimedPreparationSnapshotEntity snapshot,
  ) async {}
}
