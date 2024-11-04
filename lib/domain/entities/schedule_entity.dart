import '/core/database/database.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';

class ScheduleEntity {
  final int id;
  final PlaceEntity place;
  final String scheduleName;
  final DateTime scheduleTime;
  final DateTime moveTime;
  final bool isChanged;
  final bool isStarted;
  final DateTime scheduleSpareTime;
  final String scheduleNote;

  ScheduleEntity({
    required this.id,
    required this.place,
    required this.scheduleName,
    required this.scheduleTime,
    required this.moveTime,
    required this.isChanged,
    required this.isStarted,
    required this.scheduleSpareTime,
    required this.scheduleNote,
  });

  static ScheduleEntity fromModel(Schedule schedule, Place place) {
    return ScheduleEntity(
      id: schedule.id,
      place: PlaceEntity.fromModel(place),
      scheduleName: schedule.scheduleName,
      scheduleTime: schedule.scheduleTime,
      moveTime: schedule.moveTime,
      isChanged: schedule.isChanged,
      isStarted: schedule.isStarted,
      scheduleSpareTime: schedule.scheduleSpareTime,
      scheduleNote: schedule.scheduleNote,
    );
  }

  Schedule toModel(int userId) {
    return Schedule(
      id: id,
      userId: userId,
      placeId: place.id,
      scheduleName: scheduleName,
      scheduleTime: scheduleTime,
      moveTime: moveTime,
      isChanged: isChanged,
      isStarted: isStarted,
      scheduleSpareTime: scheduleSpareTime,
      scheduleNote: scheduleNote,
    );
  }

  @override
  String toString() {
    return 'ScheduleEntity(id: $id, place: $place, scheduleName: $scheduleName, scheduleTime: $scheduleTime, moveTime: $moveTime, isChanged: $isChanged, isStarted: $isStarted, scheduleSpareTime: $scheduleSpareTime, scheduleNote: $scheduleNote)';
  }
}
