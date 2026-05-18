import 'package:json_annotation/json_annotation.dart';
import 'package:on_time_front/core/validation/backend_constraints.dart';
import 'package:on_time_front/data/models/ordered_preparation_step_model.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_preparation_mode.dart';

part 'create_schedule_request_model.g.dart';

@JsonSerializable(includeIfNull: false, explicitToJson: true)
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
  final String? preparationTemplateId;
  final List<OrderedPreparationStepModel>? customPreparations;

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
    this.preparationTemplateId,
    this.customPreparations,
  });

  factory CreateScheduleRequestModel.fromJson(Map<String, dynamic> json) =>
      _$CreateScheduleRequestModelFromJson(json);

  Map<String, dynamic> toJson() => _$CreateScheduleRequestModelToJson(this);

  static CreateScheduleRequestModel fromEntity(ScheduleEntity entity) {
    final mode = _resolveCreateMode(entity);
    final preparationTemplateId = mode == SchedulePreparationMode.template
        ? _requireTemplateId(entity)
        : null;
    final customPreparations = mode == SchedulePreparationMode.custom
        ? OrderedPreparationStepModel.fromPreparationEntity(
            _requireCustomPreparations(entity),
          )
        : null;

    return CreateScheduleRequestModel(
      scheduleId: entity.id,
      placeId: entity.place.id,
      placeName: entity.place.placeName,
      scheduleName: BackendConstraints.trimToMaxLength(
        entity.scheduleName,
        BackendConstraints.maxScheduleNameLength,
      ),
      scheduleTime: entity.scheduleTime,
      moveTime: entity.moveTime.inMinutes,
      isChange: entity.isChanged,
      isStarted: entity.isStarted,
      scheduleSpareTime: entity.scheduleSpareTime?.inMinutes,
      scheduleNote: BackendConstraints.trimToMaxLength(
        entity.scheduleNote,
        BackendConstraints.maxLongTextLength,
      ),
      preparationTemplateId: preparationTemplateId,
      customPreparations: customPreparations,
    );
  }
}

SchedulePreparationMode _resolveCreateMode(ScheduleEntity entity) {
  if (entity.preparationMode != null) {
    return entity.preparationMode!;
  }
  if (entity.preparationTemplateId != null) {
    return SchedulePreparationMode.template;
  }
  if (entity.customPreparations != null) {
    return SchedulePreparationMode.custom;
  }
  return SchedulePreparationMode.defaultPreparation;
}

String _requireTemplateId(ScheduleEntity entity) {
  final templateId = entity.preparationTemplateId;
  if (templateId == null || templateId.isEmpty) {
    throw ArgumentError('TEMPLATE schedules require preparationTemplateId');
  }
  if (entity.customPreparations != null) {
    throw ArgumentError('TEMPLATE schedules cannot include customPreparations');
  }
  return templateId;
}

PreparationEntity _requireCustomPreparations(ScheduleEntity entity) {
  final preparation = entity.customPreparations;
  if (preparation == null) {
    throw ArgumentError('CUSTOM schedules require customPreparations');
  }
  if (entity.preparationTemplateId != null) {
    throw ArgumentError(
      'CUSTOM schedules cannot include preparationTemplateId',
    );
  }
  return preparation;
}
