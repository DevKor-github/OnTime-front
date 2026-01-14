import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:uuid/uuid.dart';

import 'package:on_time_front/core/error/failures.dart';
import 'package:on_time_front/core/error/result.dart';
import 'package:on_time_front/core/error/unit.dart';

import '../../helpers/mock.mocks.dart';

import 'package:on_time_front/data/repositories/preparation_repository_impl.dart';

void main() {
  late PreparationRepositoryImpl preparationRepository;
  late MockPreparationRemoteDataSource mockPreparationRemoteDataSource;
  late MockPreparationLocalDataSource mockPreparationLocalDataSource;
  late MockErrorLoggerService mockErrorLoggerService;

  final uuid = Uuid();

  final tPreparationStepList = [
    PreparationStepEntity(
      id: uuid.v7(),
      preparationName: 'Meeting A Friend',
      preparationTime: Duration(minutes: 30),
      nextPreparationId: null,
    ),
    PreparationStepEntity(
      id: uuid.v7(),
      preparationName: 'Museum Tour',
      preparationTime: Duration(minutes: 40),
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
      preparationTime: Duration(minutes: 10),
      nextPreparationId: null, // 이후에 설정
    ),
    PreparationStepEntity(
      id: uuid.v7(),
      preparationName: 'Museum Tour Local',
      preparationTime: Duration(minutes: 30),
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
    preparationTime: Duration(minutes: 10),
    nextPreparationId: null,
  );

  final tPreparationEntity =
      PreparationEntity(preparationStepList: [tPreparationStep]);

  setUp(() {
    mockPreparationRemoteDataSource = MockPreparationRemoteDataSource();
    mockPreparationLocalDataSource = MockPreparationLocalDataSource();
    mockErrorLoggerService = MockErrorLoggerService();
    preparationRepository = PreparationRepositoryImpl(
      preparationRemoteDataSource: mockPreparationRemoteDataSource,
      preparationLocalDataSource: mockPreparationLocalDataSource,
      errorLoggerService: mockErrorLoggerService,
    );
  });

  // group('getPreparationByScheduleId', () {
  //   test(
  //       'should emit local data first and then update local data if remote differs',
  //       () async {
  //     // Arrange
  //     when(mockPreparationLocalDataSource
  //             .getPreparationByScheduleId(scheduleEntityId))
  //         .thenAnswer((_) async => tLocalPreparationEntity);
  //     when(mockPreparationRemoteDataSource
  //             .getPreparationByScheduleId(scheduleEntityId))
  //         .thenAnswer((_) async => tPreparationEntity);

  //     // Act
  //     final result =
  //         preparationRepository.getPreparationByScheduleId(scheduleEntityId);

  //     // Assert
  //     await expectLater(
  //       result,
  //       emitsInOrder([
  //         tLocalPreparationEntity,
  //         tPreparationEntity,
  //       ]),
  //     );

  //     verify(mockPreparationLocalDataSource
  //             .getPreparationByScheduleId(scheduleEntityId))
  //         .called(1);
  //     verify(mockPreparationRemoteDataSource
  //             .getPreparationByScheduleId(scheduleEntityId))
  //         .called(1);
  //   });
  // });

  // group('getPreparationStepById', () {
  //   test(
  //       'should return PreparationStepEntity from local data source if available',
  //       () async {
  //     // Arrange
  //     when(mockPreparationLocalDataSource
  //             .getPreparationStepById(preparationStepEntityId))
  //         .thenAnswer((_) async => tLocalPreparationStep);
  //     when(mockPreparationRemoteDataSource
  //             .getPreparationStepById(preparationStepEntityId))
  //         .thenAnswer((_) async => tPreparationStep);

  //     // Act
  //     final result =
  //         preparationRepository.getPreparationStepById(preparationStepEntityId);

  //     // Assert
  //     await expectLater(
  //       result,
  //       emitsInOrder([
  //         tLocalPreparationStep, // Local 데이터 방출
  //         tPreparationStep, // Remote 데이터 방출
  //       ]),
  //     );

  //     verify(mockPreparationLocalDataSource
  //             .getPreparationStepById(preparationStepEntityId))
  //         .called(1);
  //     verify(mockPreparationRemoteDataSource
  //             .getPreparationStepById(preparationStepEntityId))
  //         .called(1);
  //   });
  // });

  // group('createDefaultPreparation', () {
  //   test('should call createDefaultPreparation on remote data source',
  //       () async {
  //     // Arrange

  //     when(mockPreparationRemoteDataSource
  //             .createDefaultPreparation(tCreateDefaultPreparationRequestModel))
  //         .thenAnswer((_) async {});

  //     // Act
  //     await preparationRepository.createDefaultPreparation(tCreateDefaultPreparationRequestModel);

  //     // Assert
  //     verify(mockPreparationRemoteDataSource
  //             .createDefaultPreparation(tCreateDefaultPreparationRequestModel))
  //         .called(1);
  //     verifyNoMoreInteractions(mockPreparationRemoteDataSource);
  //   });
  // });

  group('updatePreparation', () {
    test(
        'when successful [updateDefaultPreparation] should return Success(unit) and call remote data source',
        () async {
      // Arrange
      when(mockPreparationRemoteDataSource
              .updateDefaultPreparation(tPreparationEntity))
          .thenAnswer((_) async {});

      // Act
      final result = await preparationRepository
          .updateDefaultPreparation(tPreparationEntity);

      // Assert
      expect(result, isA<Result<Unit, Failure>>());
      expect(result.isSuccess, true);
      expect(result.successOrNull, unit);
      verify(mockPreparationRemoteDataSource
              .updateDefaultPreparation(tPreparationEntity))
          .called(1);
      verifyNoMoreInteractions(mockPreparationRemoteDataSource);
      verifyNever(mockErrorLoggerService.log(
        any,
        hint: anyNamed('hint'),
        context: anyNamed('context'),
      ));
    });

    test(
        'when remote data source throws [updateDefaultPreparation] should return Err(Failure) and log it',
        () async {
      // Arrange
      when(mockPreparationRemoteDataSource
              .updateDefaultPreparation(tPreparationEntity))
          .thenThrow(Exception());

      // Act
      final result = await preparationRepository
          .updateDefaultPreparation(tPreparationEntity);

      // Assert
      expect(result, isA<Result<Unit, Failure>>());
      expect(result.isFailure, true);
      expect(result.failureOrNull, isA<Failure>());
      verify(mockErrorLoggerService.log(
        any,
        hint: anyNamed('hint'),
        context: anyNamed('context'),
      )).called(1);
    });
  });
}
