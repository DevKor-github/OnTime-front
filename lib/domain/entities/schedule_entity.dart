import 'package:equatable/equatable.dart';

import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/schedule_preparation_mode.dart';

class ScheduleEntity extends Equatable {
  final String id;
  final PlaceEntity place;
  final String scheduleName;
  final DateTime scheduleTime;
  final Duration moveTime;
  final bool isChanged;
  final bool isStarted;
  final Duration? scheduleSpareTime;
  final String scheduleNote;
  final int latenessTime;
  final ScheduleDoneStatus doneStatus;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final SchedulePreparationMode? preparationMode;
  final String? preparationTemplateId;
  final String? preparationTemplateName;
  final bool preparationTemplateDeleted;
  final bool preparationFrozen;
  final PreparationEntity? customPreparations;

  const ScheduleEntity({
    required this.id,
    required this.place,
    required this.scheduleName,
    required this.scheduleTime,
    required this.moveTime,
    required this.isChanged,
    required this.isStarted,
    required this.scheduleSpareTime,
    required this.scheduleNote,
    this.latenessTime = 0,
    this.doneStatus = ScheduleDoneStatus.notEnded,
    this.startedAt,
    this.finishedAt,
    this.preparationMode,
    this.preparationTemplateId,
    this.preparationTemplateName,
    this.preparationTemplateDeleted = false,
    this.preparationFrozen = false,
    this.customPreparations,
  });

  ScheduleEntity copyWith({
    ScheduleDoneStatus? doneStatus,
    DateTime? startedAt,
    DateTime? finishedAt,
    SchedulePreparationMode? preparationMode,
    String? preparationTemplateId,
    String? preparationTemplateName,
    bool? preparationTemplateDeleted,
    bool? preparationFrozen,
    PreparationEntity? customPreparations,
  }) {
    return ScheduleEntity(
      id: id,
      place: place,
      scheduleName: scheduleName,
      scheduleTime: scheduleTime,
      moveTime: moveTime,
      isChanged: isChanged,
      isStarted: isStarted,
      scheduleSpareTime: scheduleSpareTime,
      scheduleNote: scheduleNote,
      latenessTime: latenessTime,
      doneStatus: doneStatus ?? this.doneStatus,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      preparationMode: preparationMode ?? this.preparationMode,
      preparationTemplateId:
          preparationTemplateId ?? this.preparationTemplateId,
      preparationTemplateName:
          preparationTemplateName ?? this.preparationTemplateName,
      preparationTemplateDeleted:
          preparationTemplateDeleted ?? this.preparationTemplateDeleted,
      preparationFrozen: preparationFrozen ?? this.preparationFrozen,
      customPreparations: customPreparations ?? this.customPreparations,
    );
  }

  @override
  String toString() {
    return 'ScheduleEntity(id: $id, place: $place, scheduleName: $scheduleName, scheduleTime: $scheduleTime, moveTime: $moveTime, isChanged: $isChanged, isStarted: $isStarted, scheduleSpareTime: $scheduleSpareTime, scheduleNote: $scheduleNote, latenessTime: $latenessTime, preparationMode: $preparationMode, preparationFrozen: $preparationFrozen)';
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
    doneStatus,
    startedAt,
    finishedAt,
    preparationMode,
    preparationTemplateId,
    preparationTemplateName,
    preparationTemplateDeleted,
    preparationFrozen,
    customPreparations,
  ];
}

enum ScheduleDoneStatus {
  lateEnd, // LATE        // 지각종료
  normalEnd, // NORMAL      // 지각 안 한 종료
  abnormalEnd, // ABNORMAL    // 비정상종료
  notEnded, // NOT_ENDED
}
