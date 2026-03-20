import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:on_time_front/data/repositories/schedule_repository_impl.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/timed_preparation_snapshot_entity.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';
import 'package:on_time_front/domain/repositories/timed_preparation_repository.dart';
import 'package:uuid/uuid.dart';

import '../../helpers/mock.mocks.dart';

class FakeTimedPreparationRepository implements TimedPreparationRepository {
  final List<String> clearedIds = [];

  @override
  Future<void> clearTimedPreparation(String scheduleId) async {
    clearedIds.add(scheduleId);
  }

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
  late MockScheduleLocalDataSource mockScheduleLocalDataSource;
  late MockScheduleRemoteDataSource mockScheduleRemoteDataSource;
  late FakeTimedPreparationRepository fakeTimedPreparationRepository;
  late ScheduleRepository scheduleRepository;

  final uuid = Uuid();
  final scheduleEntityId = uuid.v7();

  final tPlaceEntity = PlaceEntity(
    id: uuid.v7(),
    placeName: 'Office',
  );

  final tScheduleEntity = ScheduleEntity(
    id: scheduleEntityId,
    place: tPlaceEntity,
    scheduleName: 'Meeting',
    scheduleTime: DateTime.now(),
    moveTime: Duration(minutes: 10),
    isChanged: false,
    isStarted: false,
    scheduleSpareTime: Duration(minutes: 5),
    scheduleNote: 'Discuss project updates',
  );

  final tStartDate = DateTime.now();
  final tEndDate = DateTime.now().add(Duration(days: 1));

  setUp(() {
    mockScheduleLocalDataSource = MockScheduleLocalDataSource();
    mockScheduleRemoteDataSource = MockScheduleRemoteDataSource();
    fakeTimedPreparationRepository = FakeTimedPreparationRepository();
    scheduleRepository = ScheduleRepositoryImpl(
      scheduleLocalDataSource: mockScheduleLocalDataSource,
      scheduleRemoteDataSource: mockScheduleRemoteDataSource,
      timedPreparationRepository: fakeTimedPreparationRepository,
    );
  });

  group('createSchedule', () {
    test(
      'when successful [createSchedule] should create a schedule with the given schedule entity',
      () async {
        when(mockScheduleRemoteDataSource.createSchedule(tScheduleEntity))
            .thenAnswer((_) async {});

        await scheduleRepository.createSchedule(tScheduleEntity);

        verify(mockScheduleRemoteDataSource.createSchedule(tScheduleEntity));
        expect(fakeTimedPreparationRepository.clearedIds, isEmpty);
      },
    );

    test(
      'when ScheduleRemoteDataSource throws an exception [createSchedule] should throw an exception',
      () async {
        when(mockScheduleRemoteDataSource.createSchedule(tScheduleEntity))
            .thenThrow(Exception());

        final call = scheduleRepository.createSchedule(tScheduleEntity);

        expect(call, throwsException);
        expect(fakeTimedPreparationRepository.clearedIds, isEmpty);
      },
    );
  });

  group('deleteSchedule', () {
    test(
      'when successful [deleteSchedule] clears timed cache for schedule id',
      () async {
        when(mockScheduleRemoteDataSource.deleteSchedule(tScheduleEntity))
            .thenAnswer((_) async {});

        await scheduleRepository.deleteSchedule(tScheduleEntity);

        verify(mockScheduleRemoteDataSource.deleteSchedule(tScheduleEntity));
        expect(fakeTimedPreparationRepository.clearedIds, [scheduleEntityId]);
      },
    );

    test(
      'when ScheduleRemoteDataSource throws an exception [deleteSchedule] should throw and not clear cache',
      () async {
        when(mockScheduleRemoteDataSource.deleteSchedule(tScheduleEntity))
            .thenThrow(Exception());

        final call = scheduleRepository.deleteSchedule(tScheduleEntity);

        expect(call, throwsException);
        expect(fakeTimedPreparationRepository.clearedIds, isEmpty);
      },
    );
  });

  group('getScheduleById', () {
    test(
      'when schedule is not ended [getScheduleById] should not clear timed cache',
      () async {
        when(mockScheduleRemoteDataSource.getScheduleById(scheduleEntityId))
            .thenAnswer((_) async => Future.value(tScheduleEntity));

        final schedule =
            await scheduleRepository.getScheduleById(scheduleEntityId);

        expect(schedule, tScheduleEntity);
        expect(fakeTimedPreparationRepository.clearedIds, isEmpty);
      },
    );

    test(
      'when schedule is ended [getScheduleById] should clear timed cache',
      () async {
        final endedSchedule = tScheduleEntity.copyWith(
          doneStatus: ScheduleDoneStatus.normalEnd,
        );
        when(mockScheduleRemoteDataSource.getScheduleById(scheduleEntityId))
            .thenAnswer((_) async => Future.value(endedSchedule));

        final schedule =
            await scheduleRepository.getScheduleById(scheduleEntityId);

        expect(schedule.doneStatus, ScheduleDoneStatus.normalEnd);
        expect(fakeTimedPreparationRepository.clearedIds, [scheduleEntityId]);
      },
    );

    test(
      'when ScheduleRemoteDataSource throws an exception [getScheduleById] should throw an exception',
      () async {
        when(mockScheduleRemoteDataSource.getScheduleById(scheduleEntityId))
            .thenThrow(Exception());

        final getScheduleById = scheduleRepository.getScheduleById;

        expect(getScheduleById(scheduleEntityId), throwsException);
        expect(fakeTimedPreparationRepository.clearedIds, isEmpty);
      },
    );
  });

  group('getSchedulesByDate', () {
    test(
      'when successful [getSchedulesByDate] should return schedules',
      () async {
        final schedules = [tScheduleEntity];
        when(mockScheduleRemoteDataSource.getSchedulesByDate(
                tStartDate, tEndDate))
            .thenAnswer((_) async => Future.value(schedules));

        final result =
            await scheduleRepository.getSchedulesByDate(tStartDate, tEndDate);

        expect(result, schedules);
        expect(fakeTimedPreparationRepository.clearedIds, isEmpty);
      },
    );

    test(
      'when mixed statuses [getSchedulesByDate] clears cache only for ended schedules',
      () async {
        final endedNormal = tScheduleEntity.copyWith(
          doneStatus: ScheduleDoneStatus.normalEnd,
        );
        final endedLate = ScheduleEntity(
          id: uuid.v7(),
          place: tPlaceEntity,
          scheduleName: 'Late End',
          scheduleTime: DateTime.now().add(Duration(hours: 1)),
          moveTime: Duration(minutes: 10),
          isChanged: false,
          isStarted: false,
          scheduleSpareTime: Duration(minutes: 5),
          scheduleNote: 'note',
          doneStatus: ScheduleDoneStatus.lateEnd,
        );
        final ongoing = ScheduleEntity(
          id: uuid.v7(),
          place: tPlaceEntity,
          scheduleName: 'Not Ended',
          scheduleTime: DateTime.now().add(Duration(hours: 2)),
          moveTime: Duration(minutes: 10),
          isChanged: false,
          isStarted: false,
          scheduleSpareTime: Duration(minutes: 5),
          scheduleNote: 'note',
          doneStatus: ScheduleDoneStatus.notEnded,
        );
        final endedAbnormal = ScheduleEntity(
          id: uuid.v7(),
          place: tPlaceEntity,
          scheduleName: 'Abnormal End',
          scheduleTime: DateTime.now().add(Duration(hours: 3)),
          moveTime: Duration(minutes: 10),
          isChanged: false,
          isStarted: false,
          scheduleSpareTime: Duration(minutes: 5),
          scheduleNote: 'note',
          doneStatus: ScheduleDoneStatus.abnormalEnd,
        );

        final schedules = [endedNormal, ongoing, endedLate, endedAbnormal];
        when(mockScheduleRemoteDataSource.getSchedulesByDate(
                tStartDate, tEndDate))
            .thenAnswer((_) async => Future.value(schedules));

        await scheduleRepository.getSchedulesByDate(tStartDate, tEndDate);

        expect(
          fakeTimedPreparationRepository.clearedIds,
          [endedNormal.id, endedLate.id, endedAbnormal.id],
        );
      },
    );

    test(
      'when ScheduleRemoteDataSource throws an exception [getSchedulesByDate] should throw an exception',
      () async {
        when(mockScheduleRemoteDataSource.getSchedulesByDate(
                tStartDate, tEndDate))
            .thenThrow(Exception());

        final getscheduleByDate = scheduleRepository.getSchedulesByDate;

        expect(getscheduleByDate(tStartDate, tEndDate), throwsException);
        expect(fakeTimedPreparationRepository.clearedIds, isEmpty);
      },
    );
  });

  group('updateSchedule', () {
    test(
      'when successful [updateSchedule] clears timed cache for schedule id',
      () async {
        when(mockScheduleRemoteDataSource.updateSchedule(tScheduleEntity))
            .thenAnswer((_) async {});

        await scheduleRepository.updateSchedule(tScheduleEntity);

        verify(mockScheduleRemoteDataSource.updateSchedule(tScheduleEntity));
        expect(fakeTimedPreparationRepository.clearedIds, [scheduleEntityId]);
      },
    );

    test(
      'when ScheduleRemoteDataSource throws an exception [updateSchedule] should throw and not clear cache',
      () async {
        when(mockScheduleRemoteDataSource.updateSchedule(tScheduleEntity))
            .thenThrow(Exception());

        final call = scheduleRepository.updateSchedule(tScheduleEntity);

        expect(call, throwsException);
        expect(fakeTimedPreparationRepository.clearedIds, isEmpty);
      },
    );
  });

  group('finishSchedule', () {
    test(
      'when successful [finishSchedule] clears timed cache for schedule id',
      () async {
        when(mockScheduleRemoteDataSource.createSchedule(tScheduleEntity))
            .thenAnswer((_) async {});
        when(mockScheduleRemoteDataSource.finishSchedule(scheduleEntityId, 0))
            .thenAnswer((_) async {});

        await scheduleRepository.createSchedule(tScheduleEntity);
        await scheduleRepository.finishSchedule(scheduleEntityId, 0);

        verify(
            mockScheduleRemoteDataSource.finishSchedule(scheduleEntityId, 0));
        expect(fakeTimedPreparationRepository.clearedIds, [scheduleEntityId]);
      },
    );

    test(
      'when ScheduleRemoteDataSource throws an exception [finishSchedule] should throw and not clear cache',
      () async {
        when(mockScheduleRemoteDataSource.finishSchedule(scheduleEntityId, 0))
            .thenThrow(Exception());

        final call = scheduleRepository.finishSchedule(scheduleEntityId, 0);

        expect(call, throwsException);
        expect(fakeTimedPreparationRepository.clearedIds, isEmpty);
      },
    );
  });
}
