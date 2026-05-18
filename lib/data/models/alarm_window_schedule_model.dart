import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_preparation_mode.dart';
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
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final SchedulePreparationMode? preparationMode;
  final String? preparationTemplateId;
  final String? preparationTemplateName;
  final bool preparationTemplateDeleted;
  final bool preparationFrozen;

  const AlarmWindowScheduleModel({
    required this.scheduleId,
    required this.scheduleName,
    required this.place,
    required this.scheduleTime,
    required this.moveTime,
    required this.scheduleSpareTime,
    required this.doneStatus,
    required this.preparations,
    this.startedAt,
    this.finishedAt,
    this.preparationMode,
    this.preparationTemplateId,
    this.preparationTemplateName,
    this.preparationTemplateDeleted = false,
    this.preparationFrozen = false,
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
          .map(
            (item) => AlarmWindowPreparationStepModel.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
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

  ScheduleWithPreparationEntity toEntity() {
    final hasOrderedShape = preparations.every(
      (preparation) => preparation.orderIndex != null,
    );
    final sortedPreparations = [...preparations];
    if (hasOrderedShape) {
      sortedPreparations.sort((a, b) => a.orderIndex!.compareTo(b.orderIndex!));
    }
    return ScheduleWithPreparationEntity(
      id: scheduleId,
      place: place,
      scheduleName: scheduleName,
      scheduleTime: scheduleTime,
      moveTime: Duration(minutes: moveTime),
      isChanged: false,
      isStarted: preparationFrozen || startedAt != null,
      scheduleSpareTime: Duration(minutes: scheduleSpareTime),
      scheduleNote: '',
      doneStatus: _mapDoneStatus(doneStatus),
      startedAt: startedAt,
      finishedAt: finishedAt,
      preparationMode: preparationMode,
      preparationTemplateId: preparationTemplateId,
      preparationTemplateName: preparationTemplateName,
      preparationTemplateDeleted: preparationTemplateDeleted,
      preparationFrozen: preparationFrozen,
      preparation: PreparationWithTimeEntity.fromPreparation(
        PreparationEntity(
          preparationStepList: [
            for (var index = 0; index < sortedPreparations.length; index++)
              hasOrderedShape
                  ? sortedPreparations[index].toEntity(
                      nextPreparationId: index + 1 < sortedPreparations.length
                          ? sortedPreparations[index + 1].id
                          : null,
                    )
                  : sortedPreparations[index].toEntity(),
          ],
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
  final int? orderIndex;

  const AlarmWindowPreparationStepModel({
    required this.id,
    required this.preparationName,
    required this.preparationTime,
    this.nextPreparationId,
    this.orderIndex,
  });

  factory AlarmWindowPreparationStepModel.fromJson(Map<String, dynamic> json) {
    return AlarmWindowPreparationStepModel(
      id: json['preparationId'] as String,
      preparationName: json['preparationName'] as String? ?? '',
      preparationTime: (json['preparationTime'] as num?)?.toInt() ?? 0,
      nextPreparationId: json['nextPreparationId'] as String?,
      orderIndex: (json['orderIndex'] as num?)?.toInt(),
    );
  }

  PreparationStepEntity toEntity({String? nextPreparationId}) {
    return PreparationStepEntity(
      id: id,
      preparationName: preparationName,
      preparationTime: Duration(minutes: preparationTime),
      nextPreparationId: nextPreparationId ?? this.nextPreparationId,
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
