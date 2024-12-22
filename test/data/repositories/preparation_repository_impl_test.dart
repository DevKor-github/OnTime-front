import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:uuid/uuid.dart';

import '../../helpers/mock.mocks.dart';

import 'package:on_time_front/data/repositories/preparation_repository_impl.dart';

void main() {
  late PreparationRepositoryImpl preparationRepository;
  late MockPreparationRemoteDataSource mockPreparationRemoteDataSource;
  late MockPreparationLocalDataSource mockPreparationLocalDataSource;

  final uuid = Uuid();

  final scheduleEntityId = uuid.v7();
  final preparationStepEntityId = uuid.v7();
  final userEntityId = uuid.v7();

  final tPreparationStepList = [
    PreparationStepEntity(
      id: uuid.v7(),
      preparationName: 'Meeting A Friend',
      preparationTime: 30,
      nextPreparationId: null,
    ),
    PreparationStepEntity(
      id: uuid.v7(),
      preparationName: 'Museum Tour',
      preparationTime: 40,
      nextPreparationId: null,
    ),
  ];

  tPreparationStepList[0] = PreparationStepEntity(
    id: tPreparationStepList[0].id,
    preparationName: tPreparationStepList[0].preparationName,
    preparationTime: tPreparationStepList[0].preparationTime,
    nextPreparationId: tPreparationStepList[1].id,
  );

  final tLocalPreparationStepList = [
    PreparationStepEntity(
      id: uuid.v7(),
      preparationName: 'Meeting A Friend Local',
      preparationTime: 10,
      nextPreparationId: null, // 이후에 설정
    ),
    PreparationStepEntity(
      id: uuid.v7(),
      preparationName: 'Museum Tour Local',
      preparationTime: 30,
      nextPreparationId: null, // 이후에 설정
    ),
  ];

  tLocalPreparationStepList[0] = PreparationStepEntity(
    id: tLocalPreparationStepList[0].id,
    preparationName: tLocalPreparationStepList[0].preparationName,
    preparationTime: tLocalPreparationStepList[0].preparationTime,
    nextPreparationId: tLocalPreparationStepList[1].id,
  );

  final tPreparationStep = PreparationStepEntity(
    id: uuid.v7(),
    preparationName: 'Dress Up',
    preparationTime: 10,
    nextPreparationId: null,
  );

  final tLocalPreparationStep = PreparationStepEntity(
    id: uuid.v7(),
    preparationName: 'Dress Up Local',
    preparationTime: 15,
    nextPreparationId: null,
  );

  final tPreparationEntity =
      PreparationEntity(preparationStepList: [tPreparationStep]);

  final tLocalPreparationEntity =
      PreparationEntity(preparationStepList: [tLocalPreparationStep]);

  setUp(() {
    mockPreparationRemoteDataSource = MockPreparationRemoteDataSource();
    mockPreparationLocalDataSource = MockPreparationLocalDataSource();
    preparationRepository = PreparationRepositoryImpl(
      preparationRemoteDataSource: mockPreparationRemoteDataSource,
      preparationLocalDataSource: mockPreparationLocalDataSource,
    );
  });

  group('getPreparationByScheduleId', () {
    test(
        'should emit local data first and then update local data if remote differs',
        () async {
      // Arrange
      when(mockPreparationLocalDataSource
              .getPreparationByScheduleId(scheduleEntityId))
          .thenAnswer((_) async => tLocalPreparationEntity);
      when(mockPreparationRemoteDataSource
              .getPreparationByScheduleId(scheduleEntityId))
          .thenAnswer((_) async => tPreparationEntity);

      // Act
      final result =
          preparationRepository.getPreparationByScheduleId(scheduleEntityId);

      // Assert
      await expectLater(
          result, emitsInOrder([tLocalPreparationEntity, tPreparationEntity]));

      if (tLocalPreparationEntity != tPreparationEntity) {
        for (final step in tPreparationEntity.preparationStepList) {
          verify(mockPreparationLocalDataSource.updatePreparation(step))
              .called(1);
        }
      }
    });
  });

  group('getPreparationStepById', () {
    test(
        'should return PreparationStepEntity from local data source if available',
        () async {
      // Arrange
      when(mockPreparationLocalDataSource
              .getPreparationStepById(preparationStepEntityId))
          .thenAnswer((_) async => Future.delayed(Duration(seconds: 1), () {
                return tLocalPreparationStep;
              }));

      when(mockPreparationRemoteDataSource
              .getPreparationStepById(preparationStepEntityId))
          .thenAnswer((_) async => Future.delayed(Duration(seconds: 2), () {
                return tPreparationStep;
              }));

      when(mockPreparationLocalDataSource.updatePreparation(tPreparationStep))
          .thenAnswer((_) async {});

      // Act
      final result =
          preparationRepository.getPreparationStepById(preparationStepEntityId);

      // Assert
      await expectLater(
        result,
        emitsInOrder([
          tLocalPreparationStep,
          tPreparationStep,
        ]),
      );

      verify(mockPreparationLocalDataSource
              .getPreparationStepById(preparationStepEntityId))
          .called(1);
    });
  });

  group('createDefaultPreparation', () {
    test('should call createDefaultPreparation on remote data source',
        () async {
      // Arrange
      when(mockPreparationLocalDataSource.createDefaultPreparation(
              tPreparationEntity, userEntityId))
          .thenAnswer((_) async {});

      when(mockPreparationRemoteDataSource
              .createDefaultPreparation(tPreparationEntity))
          .thenAnswer((_) async {});

      // Act
      await preparationRepository.createDefaultPreparation(tPreparationEntity);

      // Assert
      verify(mockPreparationRemoteDataSource
              .createDefaultPreparation(tPreparationEntity))
          .called(1);
      verifyNoMoreInteractions(mockPreparationRemoteDataSource);
    });
  });

  group('updatePreparation', () {
    test('should call updatePreparation on remote data source', () async {
      // Arrange
      when(mockPreparationRemoteDataSource.updatePreparation(tPreparationStep))
          .thenAnswer((_) async {});

      // Act
      await preparationRepository.updatePreparation(tPreparationStep);

      // Assert
      verify(mockPreparationRemoteDataSource
              .updatePreparation(tPreparationStep))
          .called(1);
      verifyNoMoreInteractions(mockPreparationRemoteDataSource);
    });

    test('should throw an exception if remote data source fails', () async {
      // Arrange
      when(mockPreparationRemoteDataSource.updatePreparation(tPreparationStep))
          .thenThrow(Exception());

      // Act
      final call = preparationRepository.updatePreparation(tPreparationStep);

      // Assert
      expect(call, throwsException);
    });
  });

  group('deletePreparation', () {
    test('should update the local preparation list after deletion', () async {
      // Arrange
      when(mockPreparationLocalDataSource.deletePreparation(tPreparationEntity))
          .thenAnswer((_) async => tLocalPreparationEntity);

      // Act
      final result =
          preparationRepository.deletePreparation(tPreparationEntity);

      // Assert
      await expectLater(result, completes);
      verify(mockPreparationLocalDataSource
              .deletePreparation(tPreparationEntity))
          .called(1);
      verifyNoMoreInteractions(mockPreparationLocalDataSource);
    });

    test('should throw an exception if local data source fails', () async {
      // Arrange
      when(mockPreparationLocalDataSource.deletePreparation(tPreparationEntity))
          .thenThrow(Exception());

      // Act
      final call = preparationRepository.deletePreparation(tPreparationEntity);

      // Assert
      expect(call, throwsException);
    });
  });
}
