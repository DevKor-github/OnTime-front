import 'package:json_annotation/json_annotation.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';

part 'create_schedule_request_model.g.dart';

@JsonSerializable()
class CreateScheduleRequestModel {
  final String scheduleId;
  final String placeId;
  final String placeName;
  final String scheduleName;
  final DateTime scheduleTime;
  final int moveTime;
  final bool isChange;
  final bool isStarted;
  final int? scheduleSpareTime;
  final String scheduleNote;

  const CreateScheduleRequestModel({
    required this.scheduleId,
    required this.placeId,
    required this.placeName,
    required this.scheduleName,
    required this.scheduleTime,
    required this.moveTime,
    required this.isChange,
    required this.isStarted,
    required this.scheduleSpareTime,
    required this.scheduleNote,
  });

  factory CreateScheduleRequestModel.fromJson(Map<String, dynamic> json) =>
      _$CreateScheduleRequestModelFromJson(json);

  Map<String, dynamic> toJson() => _$CreateScheduleRequestModelToJson(this);

  static CreateScheduleRequestModel fromEntity(ScheduleEntity entity) {
    return CreateScheduleRequestModel(
      scheduleId: entity.id,
      placeId: entity.place.id,
      placeName: entity.place.placeName,
      scheduleName: entity.scheduleName,
      scheduleTime: entity.scheduleTime,
      moveTime: entity.moveTime.inMinutes,
      isChange: entity.isChanged,
      isStarted: entity.isStarted,
      scheduleSpareTime: entity.scheduleSpareTime?.inMinutes,
      scheduleNote: entity.scheduleNote,
    );
  }
}
