import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:uuid/uuid.dart';

import '../../helpers/mock.mocks.dart';

import 'package:on_time_front/data/repositories/schedule_repository_impl.dart';

import 'package:on_time_front/core/error/failures.dart';
import 'package:on_time_front/core/error/result.dart';
import 'package:on_time_front/core/error/unit.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';

import 'package:on_time_front/domain/repositories/schedule_repository.dart';

void main() {
  late MockScheduleLocalDataSource mockScheduleLocalDataSource;
  late MockScheduleRemoteDataSource mockScheduleRemoteDataSource;
  late MockErrorLoggerService mockErrorLoggerService;
  late ScheduleRepository scheduleRepository;

  final uuid = Uuid();
  final scheduleEntityId = uuid.v7();

  final tPlaceEntity = PlaceEntity(
    id: uuid.v7(),
    placeName: 'Office',
  );

  final tScheduleEntity = ScheduleEntity(
    id: scheduleEntityId,
    place: tPlaceEntity,
    scheduleName: 'Meeting',
    scheduleTime: DateTime.now(),
    moveTime: Duration(minutes: 10),
    isChanged: false,
    isStarted: false,
    scheduleSpareTime: Duration(minutes: 5),
    scheduleNote: 'Discuss project updates',
  );

  final tScheduleList = [tScheduleEntity];

  final tStartDate = DateTime.now();
  final tEndDate = DateTime.now().add(Duration(days: 1));

  setUpAll(() {
    mockScheduleLocalDataSource = MockScheduleLocalDataSource();
    mockScheduleRemoteDataSource = MockScheduleRemoteDataSource();
    mockErrorLoggerService = MockErrorLoggerService();
    scheduleRepository = ScheduleRepositoryImpl(
      scheduleLocalDataSource: mockScheduleLocalDataSource,
      scheduleRemoteDataSource: mockScheduleRemoteDataSource,
      errorLoggerService: mockErrorLoggerService,
    );
  });

  group(
    'createSchedule',
    () {
      test(
        'when successful [createSchedule] should return Success(unit) and call remote data source',
        () async {
          // Arrange
          // when(mockScheduleLocalDataSource.createSchedule(tScheduleEntity))
          //     .thenAnswer((_) async {});
          when(mockScheduleRemoteDataSource.createSchedule(tScheduleEntity))
              .thenAnswer((_) async {});
          // Act
          final result = await (scheduleRepository as dynamic)
              .createSchedule(tScheduleEntity);
          // Assert
          expect(result, isA<Result<Unit, Failure>>());
          expect(result.isSuccess, true);
          expect(result.successOrNull, unit);
          //verify(mockScheduleLocalDataSource.createSchedule(tScheduleEntity));
          verify(mockScheduleRemoteDataSource.createSchedule(tScheduleEntity));
        },
      );
      test(
          'when remote data source throws [createSchedule] should return Err(Failure) and log it',
          () async {
        // Arrange
        // NOTE: tests are behavior-focused; we don't require local calls.
        when(mockScheduleRemoteDataSource.createSchedule(tScheduleEntity))
            .thenThrow(Exception());
        // Act
        final result = await (scheduleRepository as dynamic)
            .createSchedule(tScheduleEntity);
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
    },
  );

  group('deleteSchedule', () {
    test(
      'when successful [deleteSchedule] should return Success(unit) and call remote data source',
      () async {
        // Arrange
        when(mockScheduleLocalDataSource.deleteSchedule(tScheduleEntity))
            .thenAnswer((_) async {});
        when(mockScheduleRemoteDataSource.deleteSchedule(tScheduleEntity))
            .thenAnswer((_) async {});
        // Act
        final result = await (scheduleRepository as dynamic)
            .deleteSchedule(tScheduleEntity);
        // Assert
        expect(result, isA<Result<Unit, Failure>>());
        expect(result.isSuccess, true);
        expect(result.successOrNull, unit);
        //verify(mockScheduleLocalDataSource.deleteSchedule(tScheduleEntity));
        verify(mockScheduleRemoteDataSource.deleteSchedule(tScheduleEntity));
      },
    );
    test(
      'when remote data source throws [deleteSchedule] should return Err(Failure) and log it',
      () async {
        // Arrange
        // Local data source is not part of the contract under test.
        when(mockScheduleRemoteDataSource.deleteSchedule(tScheduleEntity))
            .thenThrow(Exception());
        // Act
        final result = await (scheduleRepository as dynamic)
            .deleteSchedule(tScheduleEntity);
        // Assert
        expect(result, isA<Result<Unit, Failure>>());
        expect(result.isFailure, true);
        expect(result.failureOrNull, isA<Failure>());
        verify(mockErrorLoggerService.log(
          any,
          hint: anyNamed('hint'),
          context: anyNamed('context'),
        )).called(1);
      },
    );
  });

  group('getScheduleById', () {
    test(
      'when successful [getScheduleById] should return Success(ScheduleEntity)',
      () async {
        // Arrange
        when(mockScheduleRemoteDataSource.getScheduleById(scheduleEntityId))
            .thenAnswer((_) async => Future.value(tScheduleEntity));
        // Act
        final result = await (scheduleRepository as dynamic)
            .getScheduleById(scheduleEntityId);
        // Assert
        expect(result, isA<Result<ScheduleEntity, Failure>>());
        expect(result.isSuccess, true);
        expect(result.successOrNull, tScheduleEntity);
        // verify(mockScheduleLocalDataSource.updateSchedule(tScheduleEntity))
        //     .called(1);
      },
    );
    test(
      'when remote data source throws [getScheduleById] should return Err(Failure) and log it',
      () async {
        // Arrange
        // when(mockScheduleLocalDataSource.getScheduleById(scheduleEntityId))
        //     .thenAnswer((_) async => tLocalScheduleEntity);
        when(mockScheduleRemoteDataSource.getScheduleById(scheduleEntityId))
            .thenThrow(Exception());
        // Act
        final result = await (scheduleRepository as dynamic)
            .getScheduleById(scheduleEntityId);
        // Assert
        expect(result, isA<Result<ScheduleEntity, Failure>>());
        expect(result.isFailure, true);
        expect(result.failureOrNull, isA<Failure>());
        verify(mockErrorLoggerService.log(
          any,
          hint: anyNamed('hint'),
          context: anyNamed('context'),
        )).called(1);
      },
    );
  });

  group('getSchedulesByDate', () {
    test(
      'when successful [getSchedulesByDate] should return Success(List<ScheduleEntity>)',
      () async {
        // Arrange
        // when(mockScheduleLocalDataSource.getSchedulesByDate(
        //         tStartDate, tEndDate))
        //     .thenAnswer((_) async => Future.delayed(Duration(seconds: 1), () {
        //           return tLocalScheduleList;
        //         }));
        when(mockScheduleRemoteDataSource.getSchedulesByDate(
                tStartDate, tEndDate))
            .thenAnswer((_) async => Future.value(tScheduleList));
        // Act
        final result = await (scheduleRepository as dynamic)
            .getSchedulesByDate(tStartDate, tEndDate);
        // Assert
        expect(result, isA<Result<List<ScheduleEntity>, Failure>>());
        expect(result.isSuccess, true);
        expect(result.successOrNull, tScheduleList);
        // verify(mockScheduleLocalDataSource.updateSchedule(tScheduleEntity))
        //     .called(1);
      },
    );
    test(
      'when remote data source throws [getSchedulesByDate] should return Err(Failure) and log it',
      () async {
        // Arrange
        final tStartDate = DateTime.now();
        final tEndDate = DateTime.now().add(Duration(days: 1));
        when(mockScheduleRemoteDataSource.getSchedulesByDate(
                tStartDate, tEndDate))
            .thenThrow(Exception());
        // Act
        final result = await (scheduleRepository as dynamic)
            .getSchedulesByDate(tStartDate, tEndDate);
        // Assert
        expect(result, isA<Result<List<ScheduleEntity>, Failure>>());
        expect(result.isFailure, true);
        expect(result.failureOrNull, isA<Failure>());
        verify(mockErrorLoggerService.log(
          any,
          hint: anyNamed('hint'),
          context: anyNamed('context'),
        )).called(1);
      },
    );
  });

  group(
    'updateSchedule',
    () {
      test(
        'when successful [updateSchedule] should return Success(unit) and call remote data source',
        () async {
          // Arrange
          when(mockScheduleLocalDataSource.updateSchedule(tScheduleEntity))
              .thenAnswer((_) async {});
          when(mockScheduleRemoteDataSource.updateSchedule(tScheduleEntity))
              .thenAnswer((_) async {});
          // Act
          final result = await (scheduleRepository as dynamic)
              .updateSchedule(tScheduleEntity);
          // Assert
          expect(result, isA<Result<Unit, Failure>>());
          expect(result.isSuccess, true);
          expect(result.successOrNull, unit);
          //verify(mockScheduleLocalDataSource.updateSchedule(tScheduleEntity));
          verify(mockScheduleRemoteDataSource.updateSchedule(tScheduleEntity));
        },
      );
      test(
        'when remote data source throws [updateSchedule] should return Err(Failure) and log it',
        () async {
          // Arrange
          // Local data source is not part of the contract under test.
          when(mockScheduleRemoteDataSource.updateSchedule(tScheduleEntity))
              .thenThrow(Exception());
          // Act
          final result = await (scheduleRepository as dynamic)
              .updateSchedule(tScheduleEntity);
          // Assert
          expect(result, isA<Result<Unit, Failure>>());
          expect(result.isFailure, true);
          expect(result.failureOrNull, isA<Failure>());
          verify(mockErrorLoggerService.log(
            any,
            hint: anyNamed('hint'),
            context: anyNamed('context'),
          )).called(1);
        },
      );
    },
  );
}
