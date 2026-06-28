import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/tables/schedule_with_place_model.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';

extension PlacePersistenceMapper on PlaceEntity {
  Place toPlaceRow() {
    return Place(id: id, placeName: placeName);
  }
}

extension PlaceRowPersistenceMapper on Place {
  PlaceEntity toPlaceEntity() {
    return PlaceEntity(id: id, placeName: placeName);
  }
}

extension PreparationStepPersistenceMapper on PreparationStepEntity {
  PreparationUser toPreparationUserRow(String userId) {
    return PreparationUser(
      id: id,
      userId: userId,
      preparationName: preparationName,
      preparationTime: preparationTime.inMinutes,
      nextPreparationId: nextPreparationId,
    );
  }

  PreparationSchedule toPreparationScheduleRow(String scheduleId) {
    return PreparationSchedule(
      id: id,
      scheduleId: scheduleId,
      preparationName: preparationName,
      preparationTime: preparationTime.inMinutes,
      nextPreparationId: nextPreparationId,
    );
  }
}

extension SchedulePersistenceMapper on ScheduleEntity {
  Schedule toScheduleRow() {
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

  ScheduleWithPlace toScheduleWithPlaceRow() {
    return ScheduleWithPlace(
      schedule: toScheduleRow(),
      place: place.toPlaceRow(),
    );
  }
}

extension ScheduleWithPlacePersistenceMapper on ScheduleWithPlace {
  ScheduleEntity toScheduleEntity() {
    return ScheduleEntity(
      id: schedule.id,
      place: place.toPlaceEntity(),
      scheduleName: schedule.scheduleName,
      scheduleTime: schedule.scheduleTime,
      moveTime: schedule.moveTime,
      isChanged: schedule.isChanged,
      isStarted: schedule.isStarted,
      scheduleSpareTime: schedule.scheduleSpareTime,
      scheduleNote: schedule.scheduleNote ?? '',
      latenessTime: schedule.latenessTime,
      doneStatus: ScheduleDoneStatus.notEnded,
      preparationFrozen: schedule.isStarted,
    );
  }
}

extension UserPersistenceMapper on UserEntity {
  User toUserRow() {
    return map(
      (userEntity) => User(
        id: userEntity.id,
        email: userEntity.email,
        name: userEntity.name,
        spareTime: userEntity.spareTime.inMinutes,
        note: userEntity.note,
        score: userEntity.score,
      ),
      empty: (_) => throw Exception('Cannot convert empty UserEntity to User'),
    );
  }
}

extension UserRowPersistenceMapper on User {
  UserEntity toUserEntity() {
    return UserEntity(
      id: id,
      email: email,
      name: name,
      spareTime: Duration(minutes: spareTime),
      note: note,
      score: score,
    );
  }
}
