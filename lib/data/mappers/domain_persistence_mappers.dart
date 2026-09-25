import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/tables/schedule_with_place_model.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_preparation_mode.dart';
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
      timeZoneId: timeZoneId,
      occurrenceOffsetSeconds: occurrenceOffsetSeconds,
      scheduleTime: scheduleTime,
      moveTime: moveTime,
      isChanged: isChanged,
      isStarted: isStarted,
      scheduleSpareTime: scheduleSpareTime,
      scheduleNote: scheduleNote,
      latenessTime: latenessTime,
      doneStatus: doneStatus.name,
      startedAt: startedAt,
      finishedAt: finishedAt,
      preparationMode: preparationMode?.name,
      preparationTemplateId: preparationTemplateId,
      preparationTemplateName: preparationTemplateName,
      preparationTemplateDeleted: preparationTemplateDeleted,
      preparationFrozen: preparationFrozen,
      requiresStartConfirmation: requiresStartConfirmation,
      scoreContributionRecorded: scoreContributionRecorded,
      recurringSegmentId: recurringSegmentId,
      recurringSlotKey: recurringSlotKey,
      recurringOrdinal: recurringOrdinal,
      recurringOverrides: recurringOverrides,
      preparationDefinitionId: preparationDefinitionId,
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
      timeZoneId: schedule.timeZoneId,
      occurrenceOffsetSeconds: schedule.occurrenceOffsetSeconds,
      scheduleTime: schedule.scheduleTime,
      moveTime: schedule.moveTime,
      isChanged: schedule.isChanged,
      isStarted: schedule.isStarted,
      scheduleSpareTime: schedule.scheduleSpareTime,
      scheduleNote: schedule.scheduleNote ?? '',
      latenessTime: schedule.latenessTime,
      doneStatus: ScheduleDoneStatus.values.byName(schedule.doneStatus),
      startedAt: schedule.startedAt,
      finishedAt: schedule.finishedAt,
      preparationMode: schedule.preparationMode == null
          ? null
          : SchedulePreparationMode.values.byName(schedule.preparationMode!),
      preparationTemplateId: schedule.preparationTemplateId,
      preparationTemplateName: schedule.preparationTemplateName,
      preparationTemplateDeleted: schedule.preparationTemplateDeleted,
      preparationFrozen: schedule.preparationFrozen,
      requiresStartConfirmation: schedule.requiresStartConfirmation,
      retainedRecurringReference: retainedRecurringReference,
      scoreContributionRecorded: schedule.scoreContributionRecorded,
      recurringSegmentId: schedule.recurringSegmentId,
      recurringSlotKey: schedule.recurringSlotKey,
      recurringOrdinal: schedule.recurringOrdinal,
      recurringOverrides: schedule.recurringOverrides,
      preparationDefinitionId: schedule.preparationDefinitionId,
    );
  }
}

extension UserPersistenceMapper on UserEntity {
  User toUserRow() {
    return map(
      (userEntity) => User(
        id: userEntity.id,
        spareTime: userEntity.spareTime.inMinutes,
        note: userEntity.note,
        eligibleOutcomeCount: userEntity.eligibleOutcomeCount,
        onTimeOutcomeCount: userEntity.onTimeOutcomeCount,
        isOnboardingCompleted: userEntity.isOnboardingCompleted,
        alarmsEnabled: true,
        alarmOffsetMinutes: 0,
        detailedNotificationContent: false,
        restoreCleanupPending: false,
        rejectLegacyDelivery: false,
        dataRevision: 0,
        lastDurableDataAt: null,
      ),
      empty: (_) => throw Exception('Cannot convert empty UserEntity to User'),
    );
  }
}

extension UserRowPersistenceMapper on User {
  UserEntity toUserEntity() {
    return UserEntity(
      id: id,
      spareTime: Duration(minutes: spareTime),
      note: note,
      eligibleOutcomeCount: eligibleOutcomeCount,
      onTimeOutcomeCount: onTimeOutcomeCount,
      isOnboardingCompleted: isOnboardingCompleted,
    );
  }
}
