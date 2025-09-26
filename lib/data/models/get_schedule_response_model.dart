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
  final int moveTime;
  final int scheduleSpareTime;
  final String scheduleNote;
  final int? latenessTime;
  final String? doneStatus;

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
  });

  ScheduleEntity toEntity() {
    return ScheduleEntity(
      id: scheduleId,
      place: place.toEntity(),
      scheduleName: scheduleName,
      scheduleTime: scheduleTime,
      moveTime: Duration(minutes: moveTime),
      isChanged: false,
      isStarted: false,
      scheduleSpareTime: Duration(minutes: scheduleSpareTime),
      scheduleNote: scheduleNote,
      latenessTime: latenessTime ?? -1,
      doneStatus: _mapDoneStatus(doneStatus),
    );
  }

  factory GetScheduleResponseModel.fromJson(Map<String, dynamic> json) =>
      _$GetScheduleResponseModelFromJson(json);

  Map<String, dynamic> toJson() => _$GetScheduleResponseModelToJson(this);
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
