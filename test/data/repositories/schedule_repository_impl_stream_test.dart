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
  FakeScheduleRemoteDataSource({required this.getSchedulesByDateHandler});

  Future<List<ScheduleEntity>> Function(DateTime startDate, DateTime? endDate)
      getSchedulesByDateHandler;

  @override
  Future<void> createSchedule(ScheduleEntity schedule) async {}

  @override
  Future<void> deleteSchedule(ScheduleEntity schedule) async {}

  @override
  Future<void> finishSchedule(String scheduleId, int latenessTime) async {}

  @override
  Future<ScheduleEntity> getScheduleById(String id) async {
    throw UnimplementedError();
  }

  @override
  Future<List<ScheduleEntity>> getSchedulesByDate(
    DateTime startDate,
    DateTime? endDate,
  ) {
    return getSchedulesByDateHandler(startDate, endDate);
  }

  @override
  Future<void> updateSchedule(ScheduleEntity schedule) async {}
}

class FakeTimedPreparationRepository implements TimedPreparationRepository {
  @override
  Future<void> clearTimedPreparation(String scheduleId) async {}

  @override
  Future<TimedPreparationSnapshotEntity?> getTimedPreparationSnapshot(
      String scheduleId) async {
    return null;
  }

  @override
  Future<void> saveTimedPreparationSnapshot(
    String scheduleId,
    TimedPreparationSnapshotEntity snapshot,
  ) async {}
}

void main() {
  test('getSchedulesByDate upserts existing schedule by id in stream cache',
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
  });
}
