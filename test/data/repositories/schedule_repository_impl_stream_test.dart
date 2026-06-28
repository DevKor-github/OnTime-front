import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/data/data_sources/schedule_local_data_source.dart';
import 'package:on_time_front/data/data_sources/schedule_remote_data_source.dart';
import 'package:on_time_front/data/repositories/schedule_repository_impl.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/timed_preparation_snapshot_entity.dart';
import 'package:on_time_front/domain/repositories/timed_preparation_repository.dart';

class FakeScheduleLocalDataSource implements ScheduleLocalDataSource {
  @override
  Future<void> createSchedule(ScheduleEntity scheduleEntity) async {}

  @override
  Future<void> deleteSchedule(ScheduleEntity scheduleEntity) async {}

  @override
  Future<ScheduleEntity> getScheduleById(String id) async {
    throw UnimplementedError();
  }

  @override
  Future<List<ScheduleEntity>> getSchedulesByDate(
    DateTime startDate,
    DateTime? endDate,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<void> updateSchedule(ScheduleEntity scheduleEntity) async {}
}

class FakeScheduleRemoteDataSource implements ScheduleRemoteDataSource {
  FakeScheduleRemoteDataSource({
    required this.getSchedulesByDateHandler,
    Future<ScheduleEntity> Function(String id)? getScheduleByIdHandler,
    Future<void> Function(ScheduleEntity schedule)? updateScheduleHandler,
  }) : getScheduleByIdHandler =
           getScheduleByIdHandler ?? ((_) async => throw UnimplementedError()),
       updateScheduleHandler = updateScheduleHandler ?? ((_) async {});

  Future<List<ScheduleEntity>> Function(DateTime startDate, DateTime? endDate)
  getSchedulesByDateHandler;
  Future<ScheduleEntity> Function(String id) getScheduleByIdHandler;
  Future<void> Function(ScheduleEntity schedule) updateScheduleHandler;

  @override
  Future<void> createSchedule(ScheduleEntity schedule) async {}

  @override
  Future<void> deleteSchedule(ScheduleEntity schedule) async {}

  @override
  Future<void> finishSchedule(String scheduleId, int latenessTime) async {}

  @override
  Future<void> startSchedule(String scheduleId) async {}

  @override
  Future<ScheduleEntity> getScheduleById(String id) async {
    return getScheduleByIdHandler(id);
  }

  @override
  Future<List<ScheduleEntity>> getSchedulesByDate(
    DateTime startDate,
    DateTime? endDate,
  ) {
    return getSchedulesByDateHandler(startDate, endDate);
  }

  @override
  Future<void> updateSchedule(
    ScheduleEntity schedule, {
    bool includePreparationSource = false,
  }) {
    return updateScheduleHandler(schedule);
  }
}

class FakeTimedPreparationRepository implements TimedPreparationRepository {
  @override
  Future<void> clearTimedPreparation(String scheduleId) async {}

  @override
  Future<TimedPreparationSnapshotEntity?> getTimedPreparationSnapshot(
    String scheduleId,
  ) async {
    return null;
  }

  @override
  Future<void> saveTimedPreparationSnapshot(
    String scheduleId,
    TimedPreparationSnapshotEntity snapshot,
  ) async {}
}

void main() {
  test(
    'watchSchedulesByDate emits inclusive-start exclusive-end schedules sorted by time',
    () async {
      final startDate = DateTime(2026, 3, 1);
      final endDate = DateTime(2026, 4, 1);
      final insideLater = _schedule(
        id: 'inside-later',
        scheduleTime: DateTime(2026, 3, 20, 13),
      );
      final insideStart = _schedule(
        id: 'inside-start',
        scheduleTime: startDate,
      );
      final before = _schedule(
        id: 'before',
        scheduleTime: DateTime(2026, 2, 28, 23, 59),
      );
      final exclusiveEnd = _schedule(
        id: 'exclusive-end',
        scheduleTime: endDate,
      );

      final repository = ScheduleRepositoryImpl(
        scheduleLocalDataSource: FakeScheduleLocalDataSource(),
        scheduleRemoteDataSource: FakeScheduleRemoteDataSource(
          getSchedulesByDateHandler: (_, __) async => [
            insideLater,
            before,
            exclusiveEnd,
            insideStart,
          ],
        ),
        timedPreparationRepository: FakeTimedPreparationRepository(),
      );

      final rangeStream = repository.watchSchedulesByDate(startDate, endDate);
      await repository.getSchedulesByDate(startDate, endDate);

      final schedules = await rangeStream.firstWhere(
        (schedules) => schedules.length == 2,
      );

      expect(schedules.map((schedule) => schedule.id), [
        'inside-start',
        'inside-later',
      ]);
    },
  );

  test(
    'active date range watches update only when their visible schedules change',
    () async {
      final marchStart = DateTime(2026, 3, 1);
      final marchEnd = DateTime(2026, 4, 1);
      final aprilStart = DateTime(2026, 4, 1);
      final aprilEnd = DateTime(2026, 5, 1);
      final marchSchedule = _schedule(
        id: 'march',
        scheduleTime: DateTime(2026, 3, 20, 9),
      );
      final aprilSchedule = _schedule(
        id: 'april',
        scheduleTime: DateTime(2026, 4, 10, 9),
      );

      final repository = ScheduleRepositoryImpl(
        scheduleLocalDataSource: FakeScheduleLocalDataSource(),
        scheduleRemoteDataSource: FakeScheduleRemoteDataSource(
          getSchedulesByDateHandler: (startDate, _) async {
            if (startDate == marchStart) {
              return [marchSchedule];
            }
            return [aprilSchedule];
          },
        ),
        timedPreparationRepository: FakeTimedPreparationRepository(),
      );
      final marchEvents = <List<ScheduleEntity>>[];
      final aprilEvents = <List<ScheduleEntity>>[];
      final marchSubscription = repository
          .watchSchedulesByDate(marchStart, marchEnd)
          .listen(marchEvents.add);
      final aprilSubscription = repository
          .watchSchedulesByDate(aprilStart, aprilEnd)
          .listen(aprilEvents.add);
      addTearDown(marchSubscription.cancel);
      addTearDown(aprilSubscription.cancel);
      await pumpEventQueue();

      await repository.getSchedulesByDate(marchStart, marchEnd);
      await pumpEventQueue();

      expect(marchEvents.map((event) => event.map((s) => s.id).toList()), [
        <String>[],
        ['march'],
      ]);
      expect(aprilEvents.map((event) => event.map((s) => s.id).toList()), [
        <String>[],
      ]);

      await repository.getSchedulesByDate(aprilStart, aprilEnd);
      await pumpEventQueue();

      expect(marchEvents.map((event) => event.map((s) => s.id).toList()), [
        <String>[],
        ['march'],
      ]);
      expect(aprilEvents.map((event) => event.map((s) => s.id).toList()), [
        <String>[],
        ['april'],
      ]);
    },
  );

  test(
    'getSchedulesByDate upserts existing schedule by id in stream cache',
    () async {
      final startDate = DateTime(2026, 3, 1);
      final endDate = DateTime(2026, 4, 1);

      final initialSchedule = ScheduleEntity(
        id: 'schedule-1',
        place: PlaceEntity(id: 'place-1', placeName: 'Old Place'),
        scheduleName: 'Old Name',
        scheduleTime: DateTime(2026, 3, 20, 9, 0),
        moveTime: const Duration(minutes: 10),
        isChanged: false,
        isStarted: false,
        scheduleSpareTime: const Duration(minutes: 5),
        scheduleNote: 'old',
      );

      final refreshedSchedule = ScheduleEntity(
        id: 'schedule-1',
        place: PlaceEntity(id: 'place-1', placeName: 'New Place'),
        scheduleName: 'New Name',
        scheduleTime: DateTime(2026, 3, 20, 9, 0),
        moveTime: const Duration(minutes: 25),
        isChanged: true,
        isStarted: false,
        scheduleSpareTime: const Duration(minutes: 15),
        scheduleNote: 'new',
      );

      var callCount = 0;
      final remote = FakeScheduleRemoteDataSource(
        getSchedulesByDateHandler: (_, __) async {
          callCount += 1;
          return callCount == 1 ? [initialSchedule] : [refreshedSchedule];
        },
      );

      final repository = ScheduleRepositoryImpl(
        scheduleLocalDataSource: FakeScheduleLocalDataSource(),
        scheduleRemoteDataSource: remote,
        timedPreparationRepository: FakeTimedPreparationRepository(),
      );

      await repository.getSchedulesByDate(startDate, endDate);
      await repository.getSchedulesByDate(startDate, endDate);

      final latest = await repository.scheduleStream.firstWhere(
        (schedules) =>
            schedules.length == 1 && schedules.first.scheduleName == 'New Name',
      );

      expect(latest.length, 1);
      expect(latest.first.id, 'schedule-1');
      expect(latest.first.scheduleName, 'New Name');
      expect(latest.first.place.placeName, 'New Place');
      expect(latest.first.moveTime, const Duration(minutes: 25));
    },
  );

  test('updateSchedule refreshes edited schedule into stream cache', () async {
    final initialSchedule = ScheduleEntity(
      id: 'schedule-1',
      place: PlaceEntity(id: 'place-1', placeName: 'Old Place'),
      scheduleName: 'Old Name',
      scheduleTime: DateTime(2026, 3, 20, 9, 0),
      moveTime: const Duration(minutes: 10),
      isChanged: false,
      isStarted: false,
      scheduleSpareTime: const Duration(minutes: 5),
      scheduleNote: 'old',
    );

    final editedSchedule = ScheduleEntity(
      id: 'schedule-1',
      place: PlaceEntity(id: 'place-1', placeName: 'New Place'),
      scheduleName: 'Edited Name',
      scheduleTime: DateTime(2026, 3, 20, 10, 30),
      moveTime: const Duration(minutes: 20),
      isChanged: false,
      isStarted: false,
      scheduleSpareTime: const Duration(minutes: 15),
      scheduleNote: 'updated',
    );

    final repository = ScheduleRepositoryImpl(
      scheduleLocalDataSource: FakeScheduleLocalDataSource(),
      scheduleRemoteDataSource: FakeScheduleRemoteDataSource(
        getSchedulesByDateHandler: (_, __) async => [initialSchedule],
        getScheduleByIdHandler: (_) async => editedSchedule,
      ),
      timedPreparationRepository: FakeTimedPreparationRepository(),
    );

    await repository.createSchedule(initialSchedule);
    await repository.updateSchedule(editedSchedule);

    final latest = await repository.scheduleStream.firstWhere(
      (schedules) =>
          schedules.length == 1 &&
          schedules.first.scheduleName == 'Edited Name' &&
          schedules.first.scheduleTime == DateTime(2026, 3, 20, 10, 30),
    );

    expect(latest.length, 1);
    expect(latest.first.id, 'schedule-1');
    expect(latest.first.scheduleName, 'Edited Name');
    expect(latest.first.place.placeName, 'New Place');
    expect(latest.first.moveTime, const Duration(minutes: 20));
    expect(latest.first.scheduleSpareTime, const Duration(minutes: 15));
  });
}

ScheduleEntity _schedule({required String id, required DateTime scheduleTime}) {
  return ScheduleEntity(
    id: id,
    place: const PlaceEntity(id: 'place-1', placeName: 'Office'),
    scheduleName: id,
    scheduleTime: scheduleTime,
    moveTime: const Duration(minutes: 10),
    isChanged: false,
    isStarted: false,
    scheduleSpareTime: const Duration(minutes: 5),
    scheduleNote: '',
  );
}
