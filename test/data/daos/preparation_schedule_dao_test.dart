import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/daos/preparation_schedule_dao.dart';
import 'package:on_time_front/data/daos/preparation_user_dao.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase appDatabase;
  late PreparationUserDao userDao;
  late PreparationScheduleDao schedulePreparationDao;

  final uuid = Uuid();
  final userId = uuid.v7();
  final placeId = uuid.v7();
  final scheduleId = uuid.v7();

  final preparationStep1 = PreparationStepEntity(
    id: uuid.v7(),
    preparationName: 'Step 1: Wake up',
    preparationTime: Duration(minutes: 10),
    nextPreparationId: null,
  );

  final preparationStep2 = PreparationStepEntity(
    id: uuid.v7(),
    preparationName: 'Step 2: Brush teeth',
    preparationTime: Duration(minutes: 5),
    nextPreparationId: null,
  );

  final preparationEntity = PreparationEntity(
    preparationStepList: [preparationStep1, preparationStep2],
  );

  setUp(() async {
    appDatabase = AppDatabase.forTesting(NativeDatabase.memory());
    await appDatabase.customStatement('PRAGMA foreign_keys = ON');
    userDao = PreparationUserDao(appDatabase);
    schedulePreparationDao = PreparationScheduleDao(appDatabase);

    // `Users` 테이블에 데이터 삽입
    await appDatabase
        .into(appDatabase.users)
        .insert(
          UsersCompanion(
            id: drift.Value(userId),
            email: drift.Value('testuser@example.com'),
            name: drift.Value('Test User'),
            spareTime: drift.Value(Duration(minutes: 30).inSeconds),
            note: drift.Value('Test Note'),
            score: drift.Value(100),
          ),
        );

    await appDatabase
        .into(appDatabase.places)
        .insert(
          PlacesCompanion(
            id: drift.Value(placeId),
            placeName: const drift.Value('Office'),
          ),
        );

    await appDatabase
        .into(appDatabase.schedules)
        .insert(
          SchedulesCompanion(
            id: drift.Value(scheduleId),
            placeId: drift.Value(placeId),
            scheduleName: const drift.Value('Morning meeting'),
            scheduleTime: drift.Value(DateTime(2026, 5, 15, 9)),
            moveTime: const drift.Value(Duration(minutes: 20)),
            isChanged: const drift.Value(false),
            isStarted: const drift.Value(false),
            scheduleSpareTime: const drift.Value(Duration(minutes: 10)),
            scheduleNote: const drift.Value('Bring notes'),
            latenessTime: const drift.Value(0),
          ),
        );
  });

  tearDown(() async {
    await appDatabase.close();
  });

  group('createPreparationUser', () {
    test(
      'should insert preparation steps and link them as a linked list',
      () async {
        // Act
        await userDao.createPreparationUser(preparationEntity, userId);

        // Assert
        final result = await appDatabase
            .select(appDatabase.preparationUsers)
            .get();
        expect(result.length, preparationEntity.preparationStepList.length);

        // Linked List 검증
        expect(result.first.nextPreparationId, result[1].id);
        expect(result[1].nextPreparationId, isNull);
      },
    );
  });

  group('getPreparationUsersByUserId', () {
    test('should return ordered preparation steps for a given user', () async {
      // Arrange
      await userDao.createPreparationUser(preparationEntity, userId);

      // Act
      final result = await userDao.getPreparationUsersByUserId(userId);

      // Assert
      expect(
        result.preparationStepList.length,
        preparationEntity.preparationStepList.length,
      );

      // Linked List 검증
      expect(
        result.preparationStepList.first.nextPreparationId,
        result.preparationStepList[1].id,
      );
      expect(result.preparationStepList[1].nextPreparationId, isNull);
    });
  });

  group('deletePreparationUser', () {
    test('should delete a preparation step and relink the list', () async {
      // Arrange
      await userDao.createPreparationUser(preparationEntity, userId);

      // Act
      await userDao.deletePreparationUser(preparationStep1.id);

      // Assert
      final result = await userDao.getPreparationUsersByUserId(userId);
      expect(result.preparationStepList.length, 1);

      // 삭제된 첫 번째 준비 단계를 제외하고 올바르게 연결되었는지 확인
      expect(result.preparationStepList.first.id, preparationStep2.id);
      expect(result.preparationStepList.first.nextPreparationId, isNull);
    });
  });

  group('updatePreparationUser', () {
    test('should update a preparation step', () async {
      // Arrange
      await userDao.createPreparationUser(preparationEntity, userId);

      final updatedStep = preparationStep1.copyWith(
        preparationName: 'Updated Step 1',
        preparationTime: Duration(minutes: 15),
      );

      // Act
      await userDao.updatePreparationUser(updatedStep, userId);

      // Assert
      final result = await userDao.getPreparationUsersByUserId(userId);
      expect(
        result.preparationStepList.first.preparationName,
        'Updated Step 1',
      );
      expect(
        result.preparationStepList.first.preparationTime,
        Duration(minutes: 15),
      );
    });
  });

  group('schedule preparations', () {
    test(
      'createPreparationSchedule stores steps as an ordered linked list',
      () async {
        await schedulePreparationDao.createPreparationSchedule(
          preparationEntity,
          scheduleId,
        );

        final result = await schedulePreparationDao
            .getPreparationSchedulesByScheduleId(scheduleId);

        expect(result.preparationStepList, hasLength(2));
        expect(result.preparationStepList[0].id, preparationStep1.id);
        expect(
          result.preparationStepList[0].nextPreparationId,
          preparationStep2.id,
        );
        expect(result.preparationStepList[1].id, preparationStep2.id);
        expect(result.preparationStepList[1].nextPreparationId, isNull);
      },
    );

    test(
      'getPreparationSchedulesByScheduleId returns empty for no steps',
      () async {
        final result = await schedulePreparationDao
            .getPreparationSchedulesByScheduleId(scheduleId);

        expect(result.preparationStepList, isEmpty);
      },
    );

    test(
      'getPreparationSchedulesByScheduleId orders three linked steps when rows are out of order',
      () async {
        const lastStep = PreparationStepEntity(
          id: 'step-3',
          preparationName: 'Step 3: Leave',
          preparationTime: Duration(minutes: 15),
          nextPreparationId: null,
        );
        final middleStep = preparationStep2.copyWith(
          nextPreparationId: lastStep.id,
        );
        final firstStep = preparationStep1.copyWith(
          nextPreparationId: middleStep.id,
        );

        await appDatabase
            .into(appDatabase.preparationSchedules)
            .insert(
              lastStep.toPreparationScheduleRow(scheduleId).toCompanion(false),
            );
        await appDatabase
            .into(appDatabase.preparationSchedules)
            .insert(
              middleStep
                  .toPreparationScheduleRow(scheduleId)
                  .toCompanion(false),
            );
        await appDatabase
            .into(appDatabase.preparationSchedules)
            .insert(
              firstStep.toPreparationScheduleRow(scheduleId).toCompanion(false),
            );

        final result = await schedulePreparationDao
            .getPreparationSchedulesByScheduleId(scheduleId);

        expect(result.preparationStepList.map((step) => step.id), [
          preparationStep1.id,
          preparationStep2.id,
          lastStep.id,
        ]);
      },
    );

    test(
      'getPreparationSchedulesByScheduleId keeps remaining steps when a link is broken',
      () async {
        final firstStep = preparationStep1.copyWith(
          nextPreparationId: 'missing-step',
        );

        await appDatabase.customStatement('PRAGMA foreign_keys = OFF');
        await appDatabase
            .into(appDatabase.preparationSchedules)
            .insert(
              firstStep.toPreparationScheduleRow(scheduleId).toCompanion(false),
            );
        await appDatabase
            .into(appDatabase.preparationSchedules)
            .insert(
              preparationStep2
                  .toPreparationScheduleRow(scheduleId)
                  .toCompanion(false),
            );
        await appDatabase.customStatement('PRAGMA foreign_keys = ON');

        final result = await schedulePreparationDao
            .getPreparationSchedulesByScheduleId(scheduleId);

        expect(result.preparationStepList.map((step) => step.id), [
          preparationStep1.id,
          preparationStep2.id,
        ]);
      },
    );

    test(
      'getPreparationSchedulesByScheduleId returns each step once when links form a cycle',
      () async {
        final firstStep = preparationStep1.copyWith(
          nextPreparationId: preparationStep2.id,
        );
        final secondStep = preparationStep2.copyWith(
          nextPreparationId: preparationStep1.id,
        );

        await appDatabase.customStatement('PRAGMA foreign_keys = OFF');
        await appDatabase
            .into(appDatabase.preparationSchedules)
            .insert(
              firstStep.toPreparationScheduleRow(scheduleId).toCompanion(false),
            );
        await appDatabase
            .into(appDatabase.preparationSchedules)
            .insert(
              secondStep
                  .toPreparationScheduleRow(scheduleId)
                  .toCompanion(false),
            );
        await appDatabase.customStatement('PRAGMA foreign_keys = ON');

        final result = await schedulePreparationDao
            .getPreparationSchedulesByScheduleId(scheduleId);

        expect(result.preparationStepList.map((step) => step.id), [
          preparationStep1.id,
          preparationStep2.id,
        ]);
      },
    );

    test('getPreparationStepById returns the stored step contract', () async {
      await schedulePreparationDao.createPreparationSchedule(
        preparationEntity,
        scheduleId,
      );

      final result = await schedulePreparationDao.getPreparationStepById(
        preparationStep1.id,
      );

      expect(result.id, preparationStep1.id);
      expect(result.preparationName, preparationStep1.preparationName);
      expect(result.preparationTime, preparationStep1.preparationTime);
      expect(result.nextPreparationId, preparationStep2.id);
    });

    test('getPreparationStepById throws for a missing step', () async {
      await expectLater(
        schedulePreparationDao.getPreparationStepById('missing-step'),
        throwsException,
      );
    });

    test(
      'updatePreparationSchedule changes name time and next pointer',
      () async {
        await schedulePreparationDao.createPreparationSchedule(
          preparationEntity,
          scheduleId,
        );

        await schedulePreparationDao.updatePreparationSchedule(
          preparationStep1.copyWith(
            preparationName: 'Updated wake up',
            preparationTime: const Duration(minutes: 12),
            nextPreparationId: null,
          ),
          scheduleId,
        );

        final result = await schedulePreparationDao.getPreparationStepById(
          preparationStep1.id,
        );

        expect(result.preparationName, 'Updated wake up');
        expect(result.preparationTime, const Duration(minutes: 12));
        expect(result.nextPreparationId, isNull);
      },
    );

    test(
      'deletePreparationSchedule removes middle step and relinks neighbors',
      () async {
        final middleStep = PreparationStepEntity(
          id: uuid.v7(),
          preparationName: 'Step 1.5: Coffee',
          preparationTime: const Duration(minutes: 7),
          nextPreparationId: null,
        );
        final threeSteps = PreparationEntity(
          preparationStepList: [preparationStep1, middleStep, preparationStep2],
        );
        await schedulePreparationDao.createPreparationSchedule(
          threeSteps,
          scheduleId,
        );

        final result = await schedulePreparationDao.deletePreparationSchedule(
          middleStep.id,
        );

        expect(result.preparationStepList.map((step) => step.id), [
          preparationStep1.id,
          preparationStep2.id,
        ]);
        expect(
          result.preparationStepList.first.nextPreparationId,
          preparationStep2.id,
        );
        expect(result.preparationStepList.last.nextPreparationId, isNull);
      },
    );
  });
}
