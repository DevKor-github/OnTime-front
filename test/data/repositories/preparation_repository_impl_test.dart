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
      order: 1,
    ),
    PreparationStepEntity(
      id: uuid.v7(),
      preparationName: 'Museum Tour',
      preparationTime: 40,
      order: 2,
    ),
  ];

  final tLocalPreparationStepList = [
    PreparationStepEntity(
      id: uuid.v7(),
      preparationName: 'Meeting A Friend Local',
      preparationTime: 10,
      order: 1,
    ),
    PreparationStepEntity(
      id: uuid.v7(),
      preparationName: 'Museum Tour Local',
      preparationTime: 30,
      order: 2,
    ),
  ];

  final tPreparationStep = PreparationStepEntity(
    id: uuid.v7(),
    preparationName: 'Dress Up',
    preparationTime: 10,
    order: 1,
  );

  final tLocalPreparationStep = PreparationStepEntity(
    id: uuid.v7(),
    preparationName: 'Dress Up Local',
    preparationTime: 15,
    order: 1,
  );

  // final tPreparationEntity =
  //     PreparationEntity(preparationStepList: tPreparationStepList);

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
    test('should return PreparationEntity from local data source if available',
        () async {
      // Arrange
      when(mockPreparationLocalDataSource
              .getPreparationByScheduleId(scheduleEntityId))
          .thenAnswer((_) async => Future.delayed(Duration(seconds: 1), () {
                return tLocalPreparationEntity;
              }));
      when(mockPreparationRemoteDataSource
              .getPreparationByScheduleId(scheduleEntityId))
          .thenAnswer((_) async => Future.delayed(Duration(seconds: 2), () {
                return tPreparationEntity;
              }));
      when(mockPreparationLocalDataSource);

      // Act
      final result =
          preparationRepository.getPreparationByScheduleId(scheduleEntityId);

      // Assert
      await expectLater(result, emitsInOrder([tLocalPreparationEntity]));
      verify(mockPreparationLocalDataSource
              .getPreparationByScheduleId(scheduleEntityId))
          .called(1);
      verifyNoMoreInteractions(mockPreparationLocalDataSource);
    });

    test(
      'should emit PreparationEntity from local and then update local with each PreparationStepEntity from remote if they differ',
      () async {
        // Arrange
        when(mockPreparationLocalDataSource
                .getPreparationByScheduleId(scheduleEntityId))
            .thenAnswer((_) async => tLocalPreparationEntity);
        when(mockPreparationRemoteDataSource
                .getPreparationByScheduleId(scheduleEntityId))
            .thenAnswer((_) async => tPreparationEntity);

        for (final step in tPreparationEntity.preparationStepList) {
          when(mockPreparationLocalDataSource.updatePreparation(step))
              .thenAnswer((_) async {});
        }

        // Act
        final result =
            preparationRepository.getPreparationByScheduleId(scheduleEntityId);

        // Assert
        await expectLater(result,
            emitsInOrder([tLocalPreparationEntity, tPreparationEntity]));

        for (final step in tPreparationEntity.preparationStepList) {
          verify(mockPreparationLocalDataSource.updatePreparation(step))
              .called(1);
        }
      },
    );
  });

  group('getPreparationStepById', () {
    test(
        'should return PreparationStepEntity from local data source if available',
        () async {
      // Arrange
      when(mockPreparationLocalDataSource
              .getPreparationByScheduleId(preparationStepEntityId))
          .thenAnswer((_) async => tLocalPreparationEntity);
      when(mockPreparationRemoteDataSource
              .getPreparationByScheduleId(preparationStepEntityId))
          .thenAnswer((_) async => tPreparationEntity);

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
              .getPreparationByScheduleId(preparationStepEntityId))
          .called(1);
      verify(mockPreparationRemoteDataSource
              .getPreparationByScheduleId(preparationStepEntityId))
          .called(1);
    });

    test(
      'should emit PreparationStepEntity from local first, then update local data with each PreparationStepEntity from remote if they differ',
      () async {
        // Arrange
        when(mockPreparationLocalDataSource
                .getPreparationByScheduleId(scheduleEntityId))
            .thenAnswer((_) async => PreparationEntity(
                preparationStepList: tLocalPreparationStepList));
        when(mockPreparationRemoteDataSource
                .getPreparationByScheduleId(scheduleEntityId))
            .thenAnswer((_) async =>
                PreparationEntity(preparationStepList: tPreparationStepList));

        for (final step in tPreparationStepList) {
          when(mockPreparationLocalDataSource.updatePreparation(step))
              .thenAnswer((_) async {});
        }

        // Act
        final result =
            preparationRepository.getPreparationStepById(scheduleEntityId);

        // Assert
        await expectLater(
          result,
          emitsInOrder([
            ...tLocalPreparationStepList,
            ...tPreparationStepList,
          ]),
        );

        for (final step in tPreparationStepList) {
          verify(mockPreparationLocalDataSource.updatePreparation(step))
              .called(1);
        }
      },
    );

    test(
      'should handle errors thrown by local or remote data sources and rethrow them',
      () async {
        // Arrange
        when(mockPreparationLocalDataSource
                .getPreparationByScheduleId(preparationStepEntityId))
            .thenThrow(Exception('Local data source error'));
        when(mockPreparationRemoteDataSource
                .getPreparationByScheduleId(preparationStepEntityId))
            .thenAnswer((_) async => tPreparationEntity);

        // Act & Assert
        await expectLater(
          preparationRepository.getPreparationStepById(preparationStepEntityId),
          emitsError(isA<Exception>()),
        );

        // Verify
        verify(mockPreparationLocalDataSource
                .getPreparationByScheduleId(preparationStepEntityId))
            .called(1);
        verifyNever(
            mockPreparationRemoteDataSource.getPreparationByScheduleId(any));
      },
    );
  });

  group('createDefaultPreparation', () {
    test('should call createDefaultPreparation on remote data source',
        () async {
      // Arrange
      when(mockPreparationLocalDataSource.createDefaultPreparation(
              tPreparationEntity, userEntityId))
          .thenAnswer((_) async {});

      when(mockPreparationRemoteDataSource.createDefaultPreparation(
              tPreparationEntity, userEntityId))
          .thenAnswer((_) async {});

      // Act
      await preparationRepository.createDefaultPreparation(
          tPreparationEntity, userEntityId);

      // Assert
      verify(mockPreparationRemoteDataSource.createDefaultPreparation(
              tPreparationEntity, userEntityId))
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
    test('should call deletePreparation on remote data source', () async {
      // Arrange
      when(mockPreparationRemoteDataSource
              .deletePreparation(tPreparationEntity))
          .thenAnswer((_) async {});

      // Act
      await preparationRepository.deletePreparation(tPreparationEntity);

      // Assert
      verify(mockPreparationRemoteDataSource
              .deletePreparation(tPreparationEntity))
          .called(1);
      verifyNoMoreInteractions(mockPreparationRemoteDataSource);
    });

    test('should throw an exception if remote data source fails', () async {
      // Arrange
      when(mockPreparationRemoteDataSource
              .deletePreparation(tPreparationEntity))
          .thenThrow(Exception());

      // Act
      final call = preparationRepository.deletePreparation(tPreparationEntity);

      // Assert
      expect(call, throwsException);
    });
  });
}
