import 'package:drift/drift.dart' as drift; // drift의 isNull() 사용
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart'; // matcher의 isNull 사용
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

  setUp(() async {
    appDatabase = AppDatabase.forTesting(NativeDatabase.memory());
    scheduleDao = PreparationScheduleDao(appDatabase);

    // `Schedules` 테이블에 필수 참조 데이터 삽입
    await appDatabase.into(appDatabase.schedules).insert(
          SchedulesCompanion(
            id: drift.Value(scheduleId),
            userId: drift.Value(uuid.v7()),
            placeId: drift.Value(uuid.v7()),
            scheduleName: drift.Value('Test Schedule'),
            scheduleTime: drift.Value(DateTime.now()),
            moveTime: drift.Value(Duration(minutes: 10)),
            isChanged: drift.Value(false),
            isStarted: drift.Value(false),
            scheduleSpareTime: drift.Value(Duration(minutes: 5)),
            scheduleNote: drift.Value('Test Note'),
            latenessTime: drift.Value(0),
          ),
        );
  });

  tearDown(() async {
    await appDatabase.close();
  });

  group('createPreparationSchedule', () {
    test('should insert preparation steps and link them as a linked list',
        () async {
      // Act
      await scheduleDao.createPreparationSchedule(
        preparationEntity,
        scheduleId,
      );

      // Assert
      final result =
          await appDatabase.select(appDatabase.preparationSchedules).get();
      expect(result.length, preparationEntity.preparationStepList.length);

      // Linked List 검증
      expect(result.first.nextPreparationId, result[1].id);
      expect(result[1].nextPreparationId, isNull);
    });
  });

  group('getPreparationSchedulesByScheduleId', () {
    test('should return ordered preparation steps for a given schedule',
        () async {
      // Arrange
      await scheduleDao.createPreparationSchedule(
        preparationEntity,
        scheduleId,
      );

      // Act
      final result =
          await scheduleDao.getPreparationSchedulesByScheduleId(scheduleId);

      // Assert
      expect(result.preparationStepList.length,
          preparationEntity.preparationStepList.length);

      // Linked List 검증
      expect(result.preparationStepList.first.nextPreparationId,
          result.preparationStepList[1].id);
      expect(result.preparationStepList[1].nextPreparationId, isNull);
    });
  });

  group('deletePreparationSchedule', () {
    test('should delete a preparation step and relink the list', () async {
      // Arrange
      await scheduleDao.createPreparationSchedule(
        preparationEntity,
        scheduleId,
      );

      // Act
      await scheduleDao.deletePreparationSchedule(preparationStep1.id);

      // Assert
      final result =
          await scheduleDao.getPreparationSchedulesByScheduleId(scheduleId);
      expect(result.preparationStepList.length, 1);

      // 삭제된 준비 단계 제외하고 올바르게 연결되었는지 확인
      expect(result.preparationStepList.first.id, preparationStep2.id);
      expect(result.preparationStepList.first.nextPreparationId, isNull);
    });
  });

  group('updatePreparationSchedule', () {
    test('should update a preparation step', () async {
      // Arrange
      await scheduleDao.createPreparationSchedule(
        preparationEntity,
        scheduleId,
      );

      final updatedStep = preparationStep1.copyWith(
        preparationName: 'Updated Step 1',
        preparationTime: 15,
      );

      // Act
      await scheduleDao.updatePreparationSchedule(updatedStep, scheduleId);

      // Assert
      final result =
          await scheduleDao.getPreparationSchedulesByScheduleId(scheduleId);
      expect(
          result.preparationStepList.first.preparationName, 'Updated Step 1');
      expect(result.preparationStepList.first.preparationTime, 15);
    });
  });
}
