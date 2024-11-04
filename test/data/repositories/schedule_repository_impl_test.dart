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
    place: tPlaceEntity,
    scheduleName: 'Meeting',
    scheduleTime: DateTime.now(),
    moveTime: DateTime(0, 0, 0, 0, 10),
    isChanged: false,
    isStarted: false,
    scheduleSpareTime: DateTime(0, 0, 0, 0, 5),
    scheduleNote: 'Discuss project updates',
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
          when(mockScheduleLocalDataSource.createSchedule(tScheduleEntity, 1))
              .thenAnswer((_) async {});
          when(mockScheduleRemoteDataSource.createSchedule(tScheduleEntity))
              .thenAnswer((_) async {});
          // Act
          await scheduleRepository.createSchedule(tScheduleEntity, 1);
          // Assert
          verify(
              mockScheduleLocalDataSource.createSchedule(tScheduleEntity, 1));
          verify(mockScheduleRemoteDataSource.createSchedule(tScheduleEntity));
        },
      );
    },
  );
}
