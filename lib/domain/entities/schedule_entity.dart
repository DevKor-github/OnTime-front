import 'package:equatable/equatable.dart';
import 'package:on_time_front/data/tables/schedule_with_place_model.dart';

import '/core/database/database.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';

class ScheduleEntity extends Equatable {
  final String id;
  final PlaceEntity place;
  final String scheduleName;
  final DateTime scheduleTime;
  final Duration moveTime;
  final bool isChanged;
  final bool isStarted;
  final Duration scheduleSpareTime;
  final String? scheduleNote;
  final int latenessTime;

  const ScheduleEntity({
    required this.id,
    required this.place,
    required this.scheduleName,
    required this.scheduleTime,
    required this.moveTime,
    required this.isChanged,
    required this.isStarted,
    required this.scheduleSpareTime,
    this.scheduleNote,
    this.latenessTime = 0,
  });

  static ScheduleEntity fromScheduleWithPlaceModel(
      ScheduleWithPlace scheduleWithPlace) {
    final schedule = scheduleWithPlace.schedule;
    final place = scheduleWithPlace.place;
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
      latenessTime: schedule.latenessTime,
    );
  }

  Schedule toScheduleModel() {
    return Schedule(
      id: id,
      placeId: place.id,
      scheduleName: scheduleName,
      scheduleTime: scheduleTime,
      moveTime: moveTime,
      isChanged: isChanged,
      isStarted: isStarted,
      scheduleSpareTime: scheduleSpareTime,
      scheduleNote: scheduleNote,
      latenessTime: latenessTime,
    );
  }

  ScheduleWithPlace toScheduleWithPlaceModel() {
    return ScheduleWithPlace(
      schedule: toScheduleModel(),
      place: place.toModel(),
    );
  }

  @override
  String toString() {
    return 'ScheduleEntity(id: $id, place: $place, scheduleName: $scheduleName, scheduleTime: $scheduleTime, moveTime: $moveTime, isChanged: $isChanged, isStarted: $isStarted, scheduleSpareTime: $scheduleSpareTime, scheduleNote: $scheduleNote, latenessTime: $latenessTime)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ScheduleEntity && other.id == id;
  }

  @override
  int get hashCode {
    return id.hashCode;
  }

  @override
  List<Object?> get props => [
        id,
        place,
        scheduleName,
        scheduleTime,
        moveTime,
        isChanged,
        isStarted,
        scheduleSpareTime,
        scheduleNote,
        latenessTime,
      ];
}
