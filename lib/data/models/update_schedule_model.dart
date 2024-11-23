import 'package:json_annotation/json_annotation.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';

part 'update_schedule_model.g.dart';

@JsonSerializable()
class UpdateScheduleModel {
  final String id;
  final String userId;
  final String placeId;
  final String placeName;
  final String scheduleName;
  final DateTime scheduleTime;
  final DateTime moveTime;
  final DateTime scheduleSpareTime;
  final String scheduleNote;
  final int latenessTime;

  const UpdateScheduleModel({
    required this.id,
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

  factory UpdateScheduleModel.fromJson(Map<String, dynamic> json) =>
      _$UpdateScheduleModelFromJson(json);

  Map<String, dynamic> toJson() => _$UpdateScheduleModelToJson(this);

  static UpdateScheduleModel fromEntity(ScheduleEntity entity) {
    return UpdateScheduleModel(
      id: entity.id,
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
