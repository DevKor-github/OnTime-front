import 'package:json_annotation/json_annotation.dart';
import 'package:on_time_front/data/models/get_place_response_model.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';

part 'get_schedule_response_model.g.dart';

@JsonSerializable()
class GetScheduleResponseModel {
  final String scheduleId;
  final GetPlaceResponseModel place;
  final String scheduleName;
  final DateTime scheduleTime;
  final Duration moveTime;
  final Duration scheduleSpareTime;
  final String? scheduleNote;
  final int? latenessTime;

  const GetScheduleResponseModel({
    required this.scheduleId,
    required this.place,
    required this.scheduleName,
    required this.scheduleTime,
    required this.moveTime,
    required this.scheduleSpareTime,
    required this.scheduleNote,
    this.latenessTime = 0,
  });

  ScheduleEntity toEntity() {
    return ScheduleEntity(
      id: scheduleId,
      userId: '',
      place: place.toEntity(),
      scheduleName: scheduleName,
      scheduleTime: scheduleTime,
      moveTime: moveTime,
      isChanged: false,
      isStarted: false,
      scheduleSpareTime: scheduleSpareTime,
      scheduleNote: scheduleNote,
      latenessTime: latenessTime ?? -1,
    );
  }

  factory GetScheduleResponseModel.fromJson(Map<String, dynamic> json) =>
      _$GetScheduleResponseModelFromJson(json);

  Map<String, dynamic> toJson() => _$GetScheduleResponseModelToJson(this);

  static GetScheduleResponseModel fromEntity(ScheduleEntity entity) {
    return GetScheduleResponseModel(
      scheduleId: entity.id,
      place: GetPlaceResponseModel.fromEntity(entity.place),
      scheduleName: entity.scheduleName,
      scheduleTime: entity.scheduleTime,
      moveTime: entity.moveTime,
      scheduleSpareTime: entity.scheduleSpareTime,
      scheduleNote: entity.scheduleNote,
      latenessTime: entity.latenessTime,
    );
  }
}
