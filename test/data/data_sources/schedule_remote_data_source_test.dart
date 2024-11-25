import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/data/data_sources/schedule_remote_data_source.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:uuid/uuid.dart';

void main() {
  final uuid = Uuid();

  final scheduleEntityId = uuid.v7();
  final preparationStepEntityId = uuid.v7();
  final userEntityId = uuid.v7();

  final tPlaceEntity = PlaceEntity(
    id: uuid.v7(),
    placeName: 'Office',
  );

  final tScheduleEntity = ScheduleEntity(
    id: scheduleEntityId,
    userId: userEntityId,
    place: tPlaceEntity,
    scheduleName: 'Meeting',
    scheduleTime: DateTime.now(),
    moveTime: DateTime(0, 0, 0, 0, 10),
    isChanged: false,
    isStarted: false,
    scheduleSpareTime: DateTime(0, 0, 0, 0, 5),
    scheduleNote: 'Discuss project updates',
  );

  group('createSchedule', () {
    test('should perform a POST request on the /schedules/add endpoint',
        () async {});
  });
}
