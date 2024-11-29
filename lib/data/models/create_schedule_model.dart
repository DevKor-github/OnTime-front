import 'package:json_annotation/json_annotation.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';

part 'create_schedule_model.g.dart';

@JsonSerializable()
class CreateScheduleModel {
  final String scheduleId;
  final String userId;
  final String placeId;
  final String placeName;
  final String scheduleName;
  final DateTime scheduleTime;
  final Duration moveTime;
  final Duration scheduleSpareTime;
  final String scheduleNote;
  final int latenessTime;

  const CreateScheduleModel({
    required this.scheduleId,
    required this.userId,
    required this.placeId,
    required this.placeName,
    required this.scheduleName,
    required this.scheduleTime,
    required this.moveTime,
    required this.scheduleSpareTime,
    required this.scheduleNote,
    this.latenessTime = 0,
  });

  factory CreateScheduleModel.fromJson(Map<String, dynamic> json) =>
      _$CreateScheduleModelFromJson(json);

  Map<String, dynamic> toJson() => _$CreateScheduleModelToJson(this);

  static CreateScheduleModel fromEntity(ScheduleEntity entity) {
    return CreateScheduleModel(
      scheduleId: entity.id,
      userId: entity.userId,
      placeId: entity.place.id,
      placeName: entity.place.placeName,
      scheduleName: entity.scheduleName,
      scheduleTime: entity.scheduleTime,
      moveTime: entity.moveTime,
      scheduleSpareTime: entity.scheduleSpareTime,
      scheduleNote: entity.scheduleNote,
      latenessTime: entity.latenessTime,
    );
  }
}
