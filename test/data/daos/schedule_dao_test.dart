import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/domain/entities/schedule_not_found.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/daos/schedule_dao.dart';
import 'package:on_time_front/data/tables/schedule_with_place_model.dart';
import 'package:uuid/uuid.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ScheduleDao scheduleDao;
  late AppDatabase appDatabase;

  final uuid = Uuid();
  final scheduleEntityId = uuid.v7();

  final placeModel = Place(id: uuid.v7(), placeName: 'Test Place');

  // sql database does not support DateTime to the precision of milliseconds
  final scheduleTime = DateTime(2022, 1, 1, 12, 0, 0, 0);
  final startDate = scheduleTime.subtract(Duration(days: 1));
  final endDate = scheduleTime.add(Duration(days: 1));

  final scheduleModel = Schedule(
    requiresStartConfirmation: false,
    id: scheduleEntityId,
    placeId: placeModel.id,
    scheduleName: 'Test Schedule',
    timeZoneId: 'Asia/Seoul',
    scheduleTime: scheduleTime,
    moveTime: Duration(minutes: 10),
    isChanged: false,
    isStarted: false,
    scheduleSpareTime: Duration(minutes: 5),
    scheduleNote: 'Test Note',
    latenessTime: 0,
    doneStatus: 'notEnded',
    preparationTemplateDeleted: false,
    preparationFrozen: false,
    scoreContributionRecorded: false,
    recurringOverrides: '',
  );

  final scheduleWithPlaceModel = ScheduleWithPlace(
    schedule: scheduleModel,
    place: placeModel,
  );

  setUp(() {
    appDatabase = AppDatabase.forTesting(NativeDatabase.memory());
    scheduleDao = ScheduleDao(appDatabase);
  });

  tearDown(() async {
    await appDatabase.close();
  });
  test(
    'missing schedule has typed absence while database failure stays an error',
    () async {
      await expectLater(
        scheduleDao.getScheduleById('missing'),
        throwsA(isA<ScheduleNotFound>()),
      );
      await appDatabase.customStatement('DROP TABLE schedules');
      await expectLater(
        scheduleDao.getScheduleById('missing'),
        throwsA(isNot(isA<ScheduleNotFound>())),
      );
    },
  );
  test(
    'watch preserves ascending schedule time for reverse insertion order',
    () async {
      for (final hour in [15, 10, 8]) {
        await scheduleDao.createSchedule(
          ScheduleWithPlace(
            schedule: scheduleModel.copyWith(
              id: 'at-$hour',
              scheduleTime: DateTime(2030, 1, 1, hour),
            ),
            place: placeModel,
          ),
        );
      }
      final rows = await scheduleDao.watchScheduleList().first;
      expect(rows.map((r) => r.schedule.scheduleTime.hour), [8, 10, 15]);
      expect(
        rows.map((r) => r.schedule.aggregateIncarnation).toSet(),
        hasLength(3),
      );
    },
  );
  group('createSchedule', () {
    test('should insert a schedule into the database', () async {
      final result = await scheduleDao.createSchedule(scheduleWithPlaceModel);
      expect(
        result.toScheduleEntity(),
        scheduleWithPlaceModel.toScheduleEntity(),
      );
      expect(result.schedule.aggregateIncarnation, hasLength(32));
      expect(result.schedule.aggregateVersion, 0);
    });
  });

  group('updateSchedule', () {
    test('should update a schedule in the database', () async {
      //arange
      await appDatabase
          .into(appDatabase.places)
          .insert(placeModel.toCompanion(false));
      await appDatabase
          .into(appDatabase.schedules)
          .insertReturning(scheduleModel.toCompanion(false));

      final updatedScheduleModel = scheduleModel.copyWith(
        scheduleName: 'Updated Schedule',
      );

      //act
      final result = await scheduleDao.updateSchedule(updatedScheduleModel);

      //assert
      expect(
        ScheduleWithPlace(
          schedule: result,
          place: placeModel,
        ).toScheduleEntity(),
        ScheduleWithPlace(
          schedule: updatedScheduleModel,
          place: placeModel,
        ).toScheduleEntity(),
      );
      expect(result.aggregateIncarnation, hasLength(32));
      expect(result.aggregateVersion, 1);
      expect(result, (await scheduleDao.getScheduleById(result.id)).schedule);
    });
  });
  group('deleteSchedule', () {
    test('should delete a schedule from the database', () async {
      //arange
      await appDatabase
          .into(appDatabase.places)
          .insert(placeModel.toCompanion(false));
      await appDatabase
          .into(appDatabase.schedules)
          .insertReturning(scheduleModel.toCompanion(false));

      appDatabase.select(appDatabase.schedules).get().then((value) {
        expect(value, isNotEmpty);
      });

      //act
      await scheduleDao.deleteSchedule(scheduleModel);

      //assert
      appDatabase.select(appDatabase.schedules).get().then((value) {
        expect(value, isEmpty);
      });
    });
  });
  group('getScheduleById', () {
    test('should return a schedule from the database of given [id]', () async {
      //arange
      await appDatabase
          .into(appDatabase.places)
          .insert(placeModel.toCompanion(false));
      await appDatabase
          .into(appDatabase.schedules)
          .insertReturning(scheduleModel.toCompanion(false));

      //act
      final result = await scheduleDao.getScheduleById(scheduleModel.id);

      //
      expect(
        result.toScheduleEntity(),
        scheduleWithPlaceModel.toScheduleEntity(),
      );
      expect(result.schedule.aggregateIncarnation, hasLength(32));
      expect(result.schedule.aggregateVersion, 0);
    });
  });

  group('getSchedulesByDate', () {
    test('includes start date and excludes exact end date', () async {
      final rangeStart = DateTime(2026, 2, 1);
      final rangeEnd = DateTime(2026, 3, 1);
      final startBoundarySchedule = scheduleModel.copyWith(
        id: uuid.v7(),
        scheduleTime: rangeStart,
      );
      final lastDaySchedule = scheduleModel.copyWith(
        id: uuid.v7(),
        scheduleTime: DateTime(2026, 2, 28, 23, 59),
      );
      final endBoundarySchedule = scheduleModel.copyWith(
        id: uuid.v7(),
        scheduleTime: rangeEnd,
      );

      await appDatabase
          .into(appDatabase.places)
          .insert(placeModel.toCompanion(false));
      await appDatabase
          .into(appDatabase.schedules)
          .insertReturning(startBoundarySchedule.toCompanion(false));
      await appDatabase
          .into(appDatabase.schedules)
          .insertReturning(lastDaySchedule.toCompanion(false));
      await appDatabase
          .into(appDatabase.schedules)
          .insertReturning(endBoundarySchedule.toCompanion(false));

      final result = await scheduleDao.getSchedulesByDate(rangeStart, rangeEnd);

      expect(
        result.map((scheduleWithPlace) => scheduleWithPlace.schedule.id),
        unorderedEquals([startBoundarySchedule.id, lastDaySchedule.id]),
      );
    });

    test(
      'should return a list of schedules between [startDate] and [endDate]',
      () async {
        //arange
        final laterDate = scheduleTime.add(Duration(days: 4));
        final laterScheduleModel = scheduleModel.copyWith(
          id: uuid.v7(),
          scheduleTime: laterDate,
        );

        await appDatabase
            .into(appDatabase.places)
            .insert(placeModel.toCompanion(false));
        await appDatabase
            .into(appDatabase.schedules)
            .insertReturning(scheduleModel.toCompanion(false));
        await appDatabase
            .into(appDatabase.schedules)
            .insertReturning(laterScheduleModel.toCompanion(false));

        //act
        final result = await scheduleDao.getSchedulesByDate(startDate, endDate);

        //assert
        expect(result.map((row) => row.toScheduleEntity()), [
          scheduleWithPlaceModel.toScheduleEntity(),
        ]);
        expect(result.single.schedule.aggregateIncarnation, hasLength(32));
        expect(result.single.schedule.aggregateVersion, 0);
      },
    );

    test(
      'should return a list of schedules later then [startDate] if [endDate] is null',
      () async {
        //arange
        final laterDate = DateTime(2022, 1, 4, 0, 0, 0, 0);
        final laterScheduleModel = scheduleModel.copyWith(
          id: uuid.v7(),
          scheduleTime: laterDate,
        );
        final laterScheduleWithPlaceModel = ScheduleWithPlace(
          schedule: laterScheduleModel,
          place: placeModel,
        );

        await appDatabase
            .into(appDatabase.places)
            .insert(placeModel.toCompanion(false));
        await appDatabase
            .into(appDatabase.schedules)
            .insertReturning(scheduleModel.toCompanion(false));
        await appDatabase
            .into(appDatabase.schedules)
            .insertReturning(laterScheduleModel.toCompanion(false));

        //act
        final result = await scheduleDao.getSchedulesByDate(startDate, null);

        //assert
        expect(result.map((row) => row.toScheduleEntity()), [
          scheduleWithPlaceModel.toScheduleEntity(),
          laterScheduleWithPlaceModel.toScheduleEntity(),
        ]);
      },
    );
  });
}
