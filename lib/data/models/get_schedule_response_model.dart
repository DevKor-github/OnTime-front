import 'package:json_annotation/json_annotation.dart';
import 'package:on_time_front/data/models/get_place_response_model.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_preparation_mode.dart';

part 'get_schedule_response_model.g.dart';

@JsonSerializable(createFactory: false)
class GetScheduleResponseModel {
  final String scheduleId;
  final GetPlaceResponseModel place;
  final String scheduleName;
  final DateTime scheduleTime;
  final int moveTime;
  final int scheduleSpareTime;
  final String scheduleNote;
  final int? latenessTime;
  final String? doneStatus;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final SchedulePreparationMode? preparationMode;
  final String? preparationTemplateId;
  final String? preparationTemplateName;
  final bool preparationTemplateDeleted;
  final bool preparationFrozen;

  const GetScheduleResponseModel({
    required this.scheduleId,
    required this.place,
    required this.scheduleName,
    required this.scheduleTime,
    required this.moveTime,
    required this.scheduleSpareTime,
    required this.scheduleNote,
    this.latenessTime = 0,
    this.doneStatus = 'NOT_ENDED',
    this.startedAt,
    this.finishedAt,
    this.preparationMode,
    this.preparationTemplateId,
    this.preparationTemplateName,
    this.preparationTemplateDeleted = false,
    this.preparationFrozen = false,
  });

  ScheduleEntity toEntity() {
    return ScheduleEntity(
      id: scheduleId,
      place: place.toEntity(),
      scheduleName: scheduleName,
      scheduleTime: scheduleTime,
      moveTime: Duration(minutes: moveTime),
      isChanged: false,
      isStarted: preparationFrozen || startedAt != null,
      scheduleSpareTime: Duration(minutes: scheduleSpareTime),
      scheduleNote: scheduleNote,
      latenessTime: latenessTime ?? -1,
      doneStatus: _mapDoneStatus(doneStatus),
      startedAt: startedAt,
      finishedAt: finishedAt,
      preparationMode: preparationMode,
      preparationTemplateId: preparationTemplateId,
      preparationTemplateName: preparationTemplateName,
      preparationTemplateDeleted: preparationTemplateDeleted,
      preparationFrozen: preparationFrozen,
    );
  }

  factory GetScheduleResponseModel.fromJson(Map<String, dynamic> json) {
    return GetScheduleResponseModel(
      scheduleId: json['scheduleId'] as String,
      place: _placeFromJson(json),
      scheduleName: json['scheduleName'] as String? ?? '',
      scheduleTime: DateTime.parse(json['scheduleTime'] as String),
      moveTime: (json['moveTime'] as num?)?.toInt() ?? 0,
      scheduleSpareTime: (json['scheduleSpareTime'] as num?)?.toInt() ?? 0,
      scheduleNote: json['scheduleNote'] as String? ?? '',
      latenessTime: (json['latenessTime'] as num?)?.toInt() ?? 0,
      doneStatus: json['doneStatus'] as String? ?? 'NOT_ENDED',
      startedAt: _optionalDateTime(json['startedAt']),
      finishedAt: _optionalDateTime(json['finishedAt']),
      preparationMode: _preparationModeFromJson(json['preparationMode']),
      preparationTemplateId: json['preparationTemplateId'] as String?,
      preparationTemplateName: json['preparationTemplateName'] as String?,
      preparationTemplateDeleted:
          json['preparationTemplateDeleted'] as bool? ?? false,
      preparationFrozen:
          json['preparationFrozen'] as bool? ?? json['startedAt'] != null,
    );
  }

  Map<String, dynamic> toJson() => _$GetScheduleResponseModelToJson(this);
}

GetPlaceResponseModel _placeFromJson(Map<String, dynamic> json) {
  final placeJson = json['place'];
  if (placeJson is Map<String, dynamic>) {
    return GetPlaceResponseModel.fromJson(placeJson);
  }
  return GetPlaceResponseModel.fromEntity(
    PlaceEntity(
      id: json['placeId'] as String? ?? '',
      placeName: json['placeName'] as String? ?? '',
    ),
  );
}

DateTime? _optionalDateTime(Object? value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value);
  }
  return null;
}

SchedulePreparationMode? _preparationModeFromJson(Object? value) {
  switch (value) {
    case 'DEFAULT':
      return SchedulePreparationMode.defaultPreparation;
    case 'TEMPLATE':
      return SchedulePreparationMode.template;
    case 'CUSTOM':
      return SchedulePreparationMode.custom;
  }
  return null;
}

ScheduleDoneStatus _mapDoneStatus(String? serverValue) {
  switch (serverValue) {
    case 'LATE':
      return ScheduleDoneStatus.lateEnd;
    case 'NORMAL':
      return ScheduleDoneStatus.normalEnd;
    case 'ABNORMAL':
      return ScheduleDoneStatus.abnormalEnd;
    case 'NOT_ENDED':
    default:
      return ScheduleDoneStatus.notEnded;
  }
}
