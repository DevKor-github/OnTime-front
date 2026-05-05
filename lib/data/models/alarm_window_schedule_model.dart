import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';

class AlarmWindowScheduleModel {
  final String scheduleId;
  final String scheduleName;
  final PlaceEntity place;
  final DateTime scheduleTime;
  final int moveTime;
  final int scheduleSpareTime;
  final String doneStatus;
  final List<AlarmWindowPreparationStepModel> preparations;

  const AlarmWindowScheduleModel({
    required this.scheduleId,
    required this.scheduleName,
    required this.place,
    required this.scheduleTime,
    required this.moveTime,
    required this.scheduleSpareTime,
    required this.doneStatus,
    required this.preparations,
  });

  factory AlarmWindowScheduleModel.fromJson(Map<String, dynamic> json) {
    final placeJson = json['place'] as Map<String, dynamic>? ?? const {};
    final preparationJson =
        (json['preparations'] as List<dynamic>? ?? const <dynamic>[]);
    return AlarmWindowScheduleModel(
      scheduleId: json['scheduleId'] as String,
      scheduleName: json['scheduleName'] as String? ?? '',
      place: PlaceEntity(
        id: placeJson['placeId'] as String? ?? '',
        placeName: placeJson['placeName'] as String? ?? '',
      ),
      scheduleTime: DateTime.parse(json['scheduleTime'] as String),
      moveTime: (json['moveTime'] as num?)?.toInt() ?? 0,
      scheduleSpareTime: (json['scheduleSpareTime'] as num?)?.toInt() ?? 0,
      doneStatus: json['doneStatus'] as String? ?? 'NOT_ENDED',
      preparations: preparationJson
          .map((item) => AlarmWindowPreparationStepModel.fromJson(
              item as Map<String, dynamic>))
          .toList(),
    );
  }

  ScheduleWithPreparationEntity toEntity() {
    return ScheduleWithPreparationEntity(
      id: scheduleId,
      place: place,
      scheduleName: scheduleName,
      scheduleTime: scheduleTime,
      moveTime: Duration(minutes: moveTime),
      isChanged: false,
      isStarted: false,
      scheduleSpareTime: Duration(minutes: scheduleSpareTime),
      scheduleNote: '',
      doneStatus: _mapDoneStatus(doneStatus),
      preparation: PreparationWithTimeEntity.fromPreparation(
        PreparationEntity(
          preparationStepList:
              preparations.map((step) => step.toEntity()).toList(),
        ),
      ),
    );
  }
}

class AlarmWindowPreparationStepModel {
  final String id;
  final String preparationName;
  final int preparationTime;
  final String? nextPreparationId;

  const AlarmWindowPreparationStepModel({
    required this.id,
    required this.preparationName,
    required this.preparationTime,
    this.nextPreparationId,
  });

  factory AlarmWindowPreparationStepModel.fromJson(Map<String, dynamic> json) {
    return AlarmWindowPreparationStepModel(
      id: json['preparationId'] as String,
      preparationName: json['preparationName'] as String? ?? '',
      preparationTime: (json['preparationTime'] as num?)?.toInt() ?? 0,
      nextPreparationId: json['nextPreparationId'] as String?,
    );
  }

  PreparationStepEntity toEntity() {
    return PreparationStepEntity(
      id: id,
      preparationName: preparationName,
      preparationTime: Duration(minutes: preparationTime),
      nextPreparationId: nextPreparationId,
    );
  }
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
