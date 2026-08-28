import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/repositories/schedule_repository_impl.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/timed_preparation_snapshot_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/repositories/timed_preparation_repository.dart';

void main() {
  late AppDatabase database;
  late ScheduleRepositoryImpl repository;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = ScheduleRepositoryImpl(
      database: database,
      timedPreparationRepository: _NoopTimedPreparationRepository(),
    );
    await database.userDao.putUser(
      const UserEntity(
        id: 'local-profile',
        spareTime: Duration.zero,
        note: '',
        isOnboardingCompleted: true,
      ),
    );
  });

  tearDown(() async {
    await repository.dispose();
    await database.close();
  });

  test('normal and late finishes contribute once while deletion preserves aggregate', () async {
    await repository.createSchedule(_schedule('on-time'));
    await repository.createSchedule(_schedule('late'));

    await repository.finishSchedule('on-time', 0);
    await repository.finishSchedule('on-time', 0);
    await repository.finishSchedule('late', 4);
    await repository.deleteSchedule(await repository.getScheduleById('on-time'));

    final user = (await database.userDao.getUserById('local-profile'))!;
    expect(user.eligibleOutcomeCount, 2);
    expect(user.onTimeOutcomeCount, 1);
    expect(user.scoreOrNull, 50);
  });
}

ScheduleEntity _schedule(String id) => ScheduleEntity(
  id: id,
  place: const PlaceEntity(id: 'place', placeName: 'Office'),
  scheduleName: id,
  timeZoneId: 'Asia/Seoul',
  occurrenceOffsetSeconds: 9 * 60 * 60,
  scheduleTime: DateTime(2026, 9, 1, 9),
  moveTime: const Duration(minutes: 10),
  isChanged: false,
  isStarted: false,
  scheduleSpareTime: Duration.zero,
  scheduleNote: '',
);

class _NoopTimedPreparationRepository implements TimedPreparationRepository {
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
