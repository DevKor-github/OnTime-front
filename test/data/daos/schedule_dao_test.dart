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
    id: scheduleEntityId,
    placeId: placeModel.id,
    scheduleName: 'Test Schedule',
    scheduleTime: scheduleTime,
    moveTime: Duration(minutes: 10),
    isChanged: false,
    isStarted: false,
    scheduleSpareTime: Duration(minutes: 5),
    scheduleNote: 'Test Note',
    latenessTime: 0,
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
  group(
    'createSchedule',
    () {
      test(
        'should insert a schedule into the database',
        () async {
          final result =
              await scheduleDao.createSchedule(scheduleWithPlaceModel);
          expect(result, equals(scheduleWithPlaceModel));
        },
      );
    },
  );

  group('updateSchedule', () {
    test(
      'should update a schedule in the database',
      () async {
        //arange
        await appDatabase.into(appDatabase.places).insert(
              placeModel.toCompanion(false),
            );
        await appDatabase.into(appDatabase.schedules).insertReturning(
              scheduleModel.toCompanion(false),
            );

        final updatedScheduleModel = scheduleModel.copyWith(
          scheduleName: 'Updated Schedule',
        );

        //act
        final result = await scheduleDao.updateSchedule(updatedScheduleModel);

        //assert
        expect(result, equals(updatedScheduleModel));
      },
    );
  });
  group(
    'deleteSchedule',
    () {
      test(
        'should delete a schedule from the database',
        () async {
          //arange
          await appDatabase.into(appDatabase.places).insert(
                placeModel.toCompanion(false),
              );
          await appDatabase.into(appDatabase.schedules).insertReturning(
                scheduleModel.toCompanion(false),
              );

          appDatabase.select(appDatabase.schedules).get().then(
            (value) {
              expect(value, isNotEmpty);
            },
          );

          //act
          await scheduleDao.deleteSchedule(scheduleModel);

          //assert
          appDatabase.select(appDatabase.schedules).get().then(
            (value) {
              expect(value, isEmpty);
            },
          );
        },
      );
    },
  );
  group(
    'getScheduleById',
    () {
      test(
        'should return a schedule from the database of given [id]',
        () async {
          //arange
          await appDatabase.into(appDatabase.places).insert(
                placeModel.toCompanion(false),
              );
          await appDatabase.into(appDatabase.schedules).insertReturning(
                scheduleModel.toCompanion(false),
              );

          //act
          final result = await scheduleDao.getScheduleById(scheduleModel.id);

          //
          expect(result, equals(scheduleWithPlaceModel));
        },
      );
    },
  );

  group('getSchedulesByDate', () {
    test('should return a list of schedules between [startDate] and [endDate]',
        () async {
      //arange
      final laterDate = scheduleTime.add(Duration(days: 4));
      final laterScheduleModel = scheduleModel.copyWith(
        id: uuid.v7(),
        scheduleTime: laterDate,
      );

      await appDatabase.into(appDatabase.places).insert(
            placeModel.toCompanion(false),
          );
      await appDatabase.into(appDatabase.schedules).insertReturning(
            scheduleModel.toCompanion(false),
          );
      await appDatabase.into(appDatabase.schedules).insertReturning(
            laterScheduleModel.toCompanion(false),
          );

      //act
      final result = await scheduleDao.getSchedulesByDate(startDate, endDate);

      //assert
      expect(result, equals([scheduleWithPlaceModel]));
    });

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

      await appDatabase.into(appDatabase.places).insert(
            placeModel.toCompanion(false),
          );
      await appDatabase.into(appDatabase.schedules).insertReturning(
            scheduleModel.toCompanion(false),
          );
      await appDatabase.into(appDatabase.schedules).insertReturning(
            laterScheduleModel.toCompanion(false),
          );

      //act
      final result = await scheduleDao.getSchedulesByDate(startDate, null);

      //assert
      expect(result,
          equals([scheduleWithPlaceModel, laterScheduleWithPlaceModel]));
    });
  });
}
