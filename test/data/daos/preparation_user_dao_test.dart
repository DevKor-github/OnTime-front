import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/daos/preparation_user_dao.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase appDatabase;
  late PreparationUserDao userDao;

  final uuid = Uuid();
  final userId = uuid.v7();

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
    userDao = PreparationUserDao(appDatabase);
  });

  tearDown(() async {
    await appDatabase.close();
  });

  group('createPreparationUser', () {
    test('should insert preparation steps and link them as a linked list',
        () async {
      // Act
      await userDao.createPreparationUser(preparationEntity, userId);

      // Assert
      final result =
          await appDatabase.select(appDatabase.preparationUsers).get();
      expect(result.length, preparationEntity.preparationStepList.length);

      // Linked List 검증
      expect(result.first.nextPreparationId, result[1].id);
      expect(result[1].nextPreparationId, isNull);
    });
  });

  group('getPreparationUsersByUserId', () {
    test('should return ordered preparation steps for a given user', () async {
      // Arrange
      await userDao.createPreparationUser(preparationEntity, userId);

      // Act
      final result = await userDao.getPreparationUsersByUserId(userId);

      // Assert
      expect(result.preparationStepList.length,
          preparationEntity.preparationStepList.length);

      // Linked List 검증
      expect(result.preparationStepList.first.nextPreparationId,
          result.preparationStepList[1].id);
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
        preparationTime: 15,
      );

      // Act
      await userDao.updatePreparationUser(updatedStep, userId);

      // Assert
      final result = await userDao.getPreparationUsersByUserId(userId);
      expect(
          result.preparationStepList.first.preparationName, 'Updated Step 1');
      expect(result.preparationStepList.first.preparationTime, 15);
    });
  });
}
