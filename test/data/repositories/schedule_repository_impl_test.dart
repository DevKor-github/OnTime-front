import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:on_time_front/data/repositories/schedule_repository_impl.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';

import '../../helpers/mock.mocks.dart';

void main() {
  late MockScheduleLocalDataSource mockScheduleLocalDataSource;
  late MockScheduleRemoteDataSource mockScheduleRemoteDataSource;
  late ScheduleRepository scheduleRepository;

  final tPlaceEntity = PlaceEntity(
    id: 1,
    placeName: 'Office',
  );

  final tScheduleEntity = ScheduleEntity(
    id: 1,
    userId: 1,
    place: tPlaceEntity,
    scheduleName: 'Meeting',
    scheduleTime: DateTime.now(),
    moveTime: DateTime(0, 0, 0, 0, 10),
    isChanged: false,
    isStarted: false,
    scheduleSpareTime: DateTime(0, 0, 0, 0, 5),
    scheduleNote: 'Discuss project updates',
  );

  final tLocalScheduleEntity = ScheduleEntity(
    id: 1,
    userId: 1,
    place: tPlaceEntity,
    scheduleName: 'Meeting local',
    scheduleTime: DateTime.now(),
    moveTime: DateTime(0, 0, 0, 0, 15),
    isChanged: false,
    isStarted: false,
    scheduleSpareTime: DateTime(0, 0, 0, 0, 10),
    scheduleNote: 'Discuss project updates local',
  );

  setUpAll(() {
    mockScheduleLocalDataSource = MockScheduleLocalDataSource();
    mockScheduleRemoteDataSource = MockScheduleRemoteDataSource();
    scheduleRepository = ScheduleRepositoryImpl(
      scheduleLocalDataSource: mockScheduleLocalDataSource,
      scheduleRemoteDataSource: mockScheduleRemoteDataSource,
    );
  });
  group(
    'createSchedule',
    () {
      test(
        'when successful [createSchedule] should create a schedule with the given schedule entity',
        () async {
          // Arrange
          when(mockScheduleLocalDataSource.createSchedule(tScheduleEntity))
              .thenAnswer((_) async {});
          when(mockScheduleRemoteDataSource.createSchedule(tScheduleEntity))
              .thenAnswer((_) async {});
          // Act
          await scheduleRepository.createSchedule(tScheduleEntity);
          // Assert
          verify(mockScheduleLocalDataSource.createSchedule(tScheduleEntity));
          verify(mockScheduleRemoteDataSource.createSchedule(tScheduleEntity));
        },
      );
      test(
          'when ScheduleRemoteDataSource throws an exception [createSchedule] should throw an exception',
          () async {
        // Arrange
        when(mockScheduleLocalDataSource.createSchedule(tScheduleEntity))
            .thenAnswer((_) async {});
        when(mockScheduleRemoteDataSource.createSchedule(tScheduleEntity))
            .thenThrow(Exception());
        // Act
        final call = scheduleRepository.createSchedule(tScheduleEntity);
        // Assert
        expect(call, throwsException);
      });
    },
  );

  group('deleteSchedule', () {
    test(
      'when successful [deleteSchedule] should delete a schedule with the given schedule entity',
      () async {
        // Arrange
        when(mockScheduleLocalDataSource.deleteSchedule(tScheduleEntity))
            .thenAnswer((_) async {});
        when(mockScheduleRemoteDataSource.deleteSchedule(tScheduleEntity))
            .thenAnswer((_) async {});
        // Act
        await scheduleRepository.deleteSchedule(tScheduleEntity);
        // Assert
        verify(mockScheduleLocalDataSource.deleteSchedule(tScheduleEntity));
        verify(mockScheduleRemoteDataSource.deleteSchedule(tScheduleEntity));
      },
    );
    test(
      'when ScheduleRemoteDataSource throws an exception [deleteSchedule] should throw an exception',
      () async {
        // Arrange
        when(mockScheduleLocalDataSource.deleteSchedule(tScheduleEntity))
            .thenAnswer((_) async {});
        when(mockScheduleRemoteDataSource.deleteSchedule(tScheduleEntity))
            .thenThrow(Exception());
        // Act
        final call = scheduleRepository.deleteSchedule(tScheduleEntity);
        // Assert
        expect(call, throwsException);
      },
    );
  });

  group('getScheduleById', () {
    test(
      'when successful [getScheduleById] should yield a stream of schedule entity in order of local and remote if local data response is faster',
      () async {
        // Arrange
        when(mockScheduleLocalDataSource.getScheduleById(1))
            .thenAnswer((_) async => Future.delayed(Duration(seconds: 1), () {
                  return tLocalScheduleEntity;
                }));
        when(mockScheduleRemoteDataSource.getScheduleById(1))
            .thenAnswer((_) async => Future.delayed(Duration(seconds: 2), () {
                  return tScheduleEntity;
                }));
        when(mockScheduleLocalDataSource.updateSchedule(tScheduleEntity))
            .thenAnswer((_) async {});
        // Act
        final scheduleStream = scheduleRepository.getScheduleById(1);
        // Assert

        await expectLater(scheduleStream,
            emitsInOrder([tLocalScheduleEntity, tScheduleEntity]));

        verify(mockScheduleLocalDataSource.updateSchedule(tScheduleEntity))
            .called(1);
      },
    );

    test(
      'when successful [getScheduleById] should yield a stream only contains remote data if remote data response is faster',
      () async {
        when(mockScheduleLocalDataSource.getScheduleById(1))
            .thenAnswer((_) async => Future.delayed(Duration(seconds: 2), () {
                  return tLocalScheduleEntity;
                }));
        when(mockScheduleRemoteDataSource.getScheduleById(1))
            .thenAnswer((_) async => Future.delayed(Duration(seconds: 1), () {
                  return tScheduleEntity;
                }));
        when(mockScheduleLocalDataSource.updateSchedule(tScheduleEntity))
            .thenAnswer((_) async {});
        // Act
        final scheduleStream = scheduleRepository.getScheduleById(1);
        // Assert
        await expectLater(scheduleStream, emitsInOrder([tScheduleEntity]));
        verifyNever(
            mockScheduleLocalDataSource.updateSchedule(tScheduleEntity));
      },
    );
    test(
      'when ScheduleRemoteDataSource throws an exception [getScheduleById] should throw an exception',
      () async {
        // Arrange
        when(mockScheduleLocalDataSource.getScheduleById(1))
            .thenAnswer((_) async => tLocalScheduleEntity);
        when(mockScheduleRemoteDataSource.getScheduleById(1))
            .thenThrow(Exception());
        // Act
        final call = scheduleRepository.getScheduleById(1);
        // Assert
        expect(call, emitsError(isA<Exception>()));
      },
    );
  });

  group(
    'updateSchedule',
    () {
      test(
        'when successful [updateSchedule] should update a schedule with the given schedule entity',
        () async {
          // Arrange
          when(mockScheduleLocalDataSource.updateSchedule(tScheduleEntity))
              .thenAnswer((_) async {});
          when(mockScheduleRemoteDataSource.updateSchedule(tScheduleEntity))
              .thenAnswer((_) async {});
          // Act
          await scheduleRepository.updateSchedule(tScheduleEntity);
          // Assert
          verify(mockScheduleLocalDataSource.updateSchedule(tScheduleEntity));
          verify(mockScheduleRemoteDataSource.updateSchedule(tScheduleEntity));
        },
      );
      test(
        'when ScheduleRemoteDataSource throws an exception [updateSchedule] should throw an exception',
        () async {
          // Arrange
          when(mockScheduleLocalDataSource.updateSchedule(tScheduleEntity))
              .thenAnswer((_) async {});
          when(mockScheduleRemoteDataSource.updateSchedule(tScheduleEntity))
              .thenThrow(Exception());
          // Act
          final call = scheduleRepository.updateSchedule(tScheduleEntity);
          // Assert
          expect(call, throwsException);
        },
      );
    },
  );
}
