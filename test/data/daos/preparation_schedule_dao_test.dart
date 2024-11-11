import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/daos/preparation_schedule_dao.dart';
import 'package:uuid/uuid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PreparationScheduleDao preparationScheduleDao;
  late AppDatabase appDatabase;

  final uuid = Uuid();

  final scheduleId = uuid.v7();

  final tPlace = Place(id: uuid.v7(), placeName: 'Test Place');

  final tSchedule = Schedule(
      id: scheduleId,
      userId: uuid.v7(),
      placeId: tPlace.id,
      scheduleName: 'Test Schedule',
      scheduleTime: DateTime.now(),
      moveTime: DateTime.now(),
      isChanged: false,
      isStarted: false,
      scheduleSpareTime: DateTime.now(),
      scheduleNote: 'Test Note');

  final tPreparationSchedules = [
    PreparationSchedule(
      id: uuid.v7(),
      scheduleId: scheduleId,
      preparationName: 'Test Preparation',
      preparationTime: 10,
      order: 1,
    ),
    PreparationSchedule(
      id: uuid.v7(),
      scheduleId: scheduleId,
      preparationName: 'Test Preparation 2',
      preparationTime: 10,
      order: 2,
    ),
  ];

  setUp(() async {
    appDatabase = AppDatabase.forTesting(NativeDatabase.memory());
    preparationScheduleDao = PreparationScheduleDao(appDatabase);
    await appDatabase.into(appDatabase.places).insert(tPlace);
    await appDatabase.into(appDatabase.schedules).insert(tSchedule);
  });

  group('createPreparationSchedules', () {
    test('should insert a preparation schedules into the database', () async {
      // Act
      final result = await preparationScheduleDao.createPreparationSchedules(
        tPreparationSchedules,
      );

      // Assert
      expect(result, equals(tPreparationSchedules));
    });
  });

  group('getPreparationSchedulesByScheduleId', () {
    test('should return a list of preparation schedules by scheduleId',
        () async {
      // Arrange
      for (var step in tPreparationSchedules) {
        await appDatabase
            .into(appDatabase.preparationSchedules)
            .insertReturning(
              step.toCompanion(false),
            );
      }

      // Act
      final result = await preparationScheduleDao
          .getPreparationSchedulesByScheduleId(scheduleId);

      // Assert
      expect(result, equals(tPreparationSchedules));
    });
  });

  group('deletePreparationSchedulseByScheduleId', () {
    test('should delete a list of preparation schedules by scheduleId',
        () async {
      // Arrange
      for (var step in tPreparationSchedules) {
        await appDatabase
            .into(appDatabase.preparationSchedules)
            .insertReturning(
              step.toCompanion(false),
            );
      }

      // Act
      await preparationScheduleDao
          .deletePreparationSchedulesByScheduleId(scheduleId);

      // Assert
      final result = await (appDatabase.select(appDatabase.preparationSchedules)
            ..where((tbl) => tbl.scheduleId.equals(scheduleId)))
          .get();
      expect(result, equals([]));
    });
  });
}
