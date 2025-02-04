import 'package:json_annotation/json_annotation.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';

part 'update_schedule_request_model.g.dart';

@JsonSerializable()
class UpdateScheduleRequestModel {
  final String scheduleId;
  final String placeId;
  final String placeName;
  final String scheduleName;
  final DateTime scheduleTime;
  final int moveTime;
  final int scheduleSpareTime;
  final String scheduleNote;
  final int latenessTime;

  const UpdateScheduleRequestModel({
    required this.scheduleId,
    required this.placeId,
    required this.placeName,
    required this.scheduleName,
    required this.scheduleTime,
    required this.moveTime,
    required this.scheduleSpareTime,
    required this.scheduleNote,
    this.latenessTime = 0,
  });

  factory UpdateScheduleRequestModel.fromJson(Map<String, dynamic> json) =>
      _$UpdateScheduleRequestModelFromJson(json);

  Map<String, dynamic> toJson() => _$UpdateScheduleRequestModelToJson(this);

  static UpdateScheduleRequestModel fromEntity(ScheduleEntity entity) {
    return UpdateScheduleRequestModel(
      scheduleId: entity.id,
      placeId: entity.place.id,
      placeName: entity.place.placeName,
      scheduleName: entity.scheduleName,
      scheduleTime: entity.scheduleTime,
      moveTime: entity.moveTime.inMinutes,
      scheduleSpareTime: entity.scheduleSpareTime.inMinutes,
      scheduleNote: entity.scheduleNote,
      latenessTime: entity.latenessTime,
    );
  }
}
