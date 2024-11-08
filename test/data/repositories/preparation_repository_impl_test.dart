import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:uuid/uuid.dart';

import '../../helpers/mock.mocks.dart';

import 'package:on_time_front/data/repositories/preparation_repository_impl.dart';

void main() {
  late PreparationRepositoryImpl preparationRepository;
  late MockPreparationRemoteDataSource mockRemoteDataSource;
  late MockPreparationLocalDataSource mockLocalDataSource;

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

  final tPreparationEntity =
      PreparationEntity(preparationStepList: tPreparationStepList);

  final tPreparationStep = PreparationStepEntity(
    id: uuid.v7(),
    preparationName: 'Dress Up',
    preparationTime: 10,
    order: 1,
  );

  setUp(() {
    mockRemoteDataSource = MockPreparationRemoteDataSource();
    mockLocalDataSource = MockPreparationLocalDataSource();
    preparationRepository = PreparationRepositoryImpl(
      remoteDataSource: mockRemoteDataSource,
      localDataSource: mockLocalDataSource,
    );
  });

  group('getPreparationByScheduleId', () {
    test('should return PreparationEntity from local data source', () {
      when(mockLocalDataSource.getPreparationByScheduleId(scheduleEntityId))
          .thenAnswer((_) => Stream.value(tPreparationEntity));

      final result =
          preparationRepository.getPreparationByScheduleId(scheduleEntityId);

      expect(
        result,
        emits(tPreparationEntity),
        reason: 'localDataSource should return the expected PreparationEntity.',
      );
      verify(mockLocalDataSource.getPreparationByScheduleId(scheduleEntityId))
          .called(1);
      verifyNoMoreInteractions(mockLocalDataSource);
      verifyZeroInteractions(mockRemoteDataSource);
    });
  });

  group('createDefaultPreparation', () {
    test('should call createDefaultPreparation on remote data source',
        () async {
      when(mockRemoteDataSource.createDefaultPreparation(
              tPreparationEntity, userEntityId))
          .thenAnswer((_) async {});

      await preparationRepository.createDefaultPreparation(
          tPreparationEntity, userEntityId);

      verify(mockRemoteDataSource.createDefaultPreparation(
              tPreparationEntity, userEntityId))
          .called(1);
      verifyNoMoreInteractions(mockRemoteDataSource);
    });
  });

  group('getPreparationStepById', () {
    test('should return PreparationStepEntity from local data source', () {
      when(mockLocalDataSource.getPreparationStepById(preparationStepEntityId))
          .thenAnswer((_) => Stream.value(tPreparationStep));

      final result =
          preparationRepository.getPreparationStepById(preparationStepEntityId);

      expect(
        result,
        emits(tPreparationStep),
        reason:
            'localDataSource should return the expected PreparationStepEntity.',
      );
      verify(mockLocalDataSource
              .getPreparationStepById(preparationStepEntityId))
          .called(1);
      verifyNoMoreInteractions(mockLocalDataSource);
    });
  });

  group('updatePreparation', () {
    test('should call updatePreparation on remote data source', () async {
      when(mockRemoteDataSource.updatePreparation(tPreparationStep))
          .thenAnswer((_) async {});

      await preparationRepository.updatePreparation(tPreparationStep);

      verify(mockRemoteDataSource.updatePreparation(tPreparationStep))
          .called(1);
      verifyNoMoreInteractions(mockRemoteDataSource);
    });
  });

  group('deletePreparation', () {
    test('should call deletePreparation on remote data source', () async {
      when(mockRemoteDataSource.deletePreparation(tPreparationEntity))
          .thenAnswer((_) async {});

      await preparationRepository.deletePreparation(tPreparationEntity);

      verify(mockRemoteDataSource.deletePreparation(tPreparationEntity))
          .called(1);
      verifyNoMoreInteractions(mockRemoteDataSource);
    });
  });
}
