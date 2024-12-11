import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/daos/preparation_schedule_dao.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase appDatabase;
  late PreparationScheduleDao scheduleDao;

  final uuid = Uuid();
  final scheduleId = uuid.v7();

  final preparationStep1 = PreparationStepEntity(
    id: uuid.v7(),
    preparationName: 'Step 1: Wake up',
    preparationTime: 10,
    nextPreparationId: null,
  );

  final preparationStep2 = PreparationStepEntity(
    id: uuid.v7(),
    preparationName: 'Step 2: Brush teeth',
    preparationTime: 5,
    nextPreparationId: null,
  );

  final preparationEntity = PreparationEntity(
    preparationStepList: [preparationStep1, preparationStep2],
  );

  setUp(() {
    appDatabase = AppDatabase.forTesting(NativeDatabase.memory());
    scheduleDao = PreparationScheduleDao(appDatabase);
  });

  tearDown(() async {
    await appDatabase.close();
  });

  group('createPreparationSchedule', () {
    test('should insert preparation steps and link them as a linked list',
        () async {
      // Act
      await scheduleDao.createPreparationSchedule(
          preparationEntity, scheduleId);

      // Assert
      final result =
          await appDatabase.select(appDatabase.preparationSchedules).get();
      expect(result.length, preparationEntity.preparationStepList.length);
      expect(result.first.nextPreparationId, result[1].id);
    });
  });

  group('getPreparationSchedulesByScheduleId', () {
    test('should return ordered preparation steps for a given schedule',
        () async {
      // Arrange
      await scheduleDao.createPreparationSchedule(
          preparationEntity, scheduleId);

      // Act
      final result =
          await scheduleDao.getPreparationSchedulesByScheduleId(scheduleId);

      // Assert
      expect(result.preparationStepList.length,
          preparationEntity.preparationStepList.length);
      expect(result.preparationStepList.first.nextPreparationId,
          result.preparationStepList[1].id);
    });
  });

  group('deletePreparationSchedule', () {
    test('should delete a preparation step and relink the list', () async {
      // Arrange
      await scheduleDao.createPreparationSchedule(
          preparationEntity, scheduleId);

      // Act
      await scheduleDao.deletePreparationSchedule(preparationStep1.id);

      // Assert
      final result =
          await scheduleDao.getPreparationSchedulesByScheduleId(scheduleId);
      expect(result.preparationStepList.length, 1);
      expect(result.preparationStepList.first.id, preparationStep2.id);
    });
  });
}
