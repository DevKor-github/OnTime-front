import 'package:json_annotation/json_annotation.dart';
import 'package:on_time_front/core/validation/backend_constraints.dart';
import 'package:on_time_front/data/models/ordered_preparation_step_model.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_preparation_mode.dart';

part 'update_schedule_request_model.g.dart';

@JsonSerializable(includeIfNull: false, explicitToJson: true)
class UpdateScheduleRequestModel {
  final String scheduleId;
  final String placeId;
  final String placeName;
  final String scheduleName;
  final DateTime scheduleTime;
  final int moveTime;
  final int? scheduleSpareTime;
  final String scheduleNote;
  final SchedulePreparationMode? preparationMode;
  final String? preparationTemplateId;
  final List<OrderedPreparationStepModel>? customPreparations;

  const UpdateScheduleRequestModel({
    required this.scheduleId,
    required this.placeId,
    required this.placeName,
    required this.scheduleName,
    required this.scheduleTime,
    required this.moveTime,
    this.scheduleSpareTime,
    required this.scheduleNote,
    this.preparationMode,
    this.preparationTemplateId,
    this.customPreparations,
  });

  factory UpdateScheduleRequestModel.fromJson(Map<String, dynamic> json) =>
      _$UpdateScheduleRequestModelFromJson(json);

  Map<String, dynamic> toJson() => _$UpdateScheduleRequestModelToJson(this);

  static UpdateScheduleRequestModel fromEntity(
    ScheduleEntity entity, {
    bool includePreparationSource = false,
  }) {
    final preparationMode = includePreparationSource
        ? entity.preparationMode
        : null;
    final preparationTemplateId = _templateIdForMode(entity, preparationMode);
    final customPreparations = _customPreparationsForMode(
      entity,
      preparationMode,
    );

    return UpdateScheduleRequestModel(
      scheduleId: entity.id,
      placeId: entity.place.id,
      placeName: entity.place.placeName,
      scheduleName: BackendConstraints.trimToMaxLength(
        entity.scheduleName,
        BackendConstraints.maxScheduleNameLength,
      ),
      scheduleTime: entity.scheduleTime,
      moveTime: entity.moveTime.inMinutes,
      scheduleSpareTime: entity.scheduleSpareTime?.inMinutes,
      scheduleNote: BackendConstraints.trimToMaxLength(
        entity.scheduleNote,
        BackendConstraints.maxLongTextLength,
      ),
      preparationMode: preparationMode,
      preparationTemplateId: preparationTemplateId,
      customPreparations: customPreparations,
    );
  }
}

String? _templateIdForMode(
  ScheduleEntity entity,
  SchedulePreparationMode? preparationMode,
) {
  if (preparationMode != SchedulePreparationMode.template) {
    return null;
  }
  final templateId = entity.preparationTemplateId;
  if (templateId == null || templateId.isEmpty) {
    throw ArgumentError('TEMPLATE schedules require preparationTemplateId');
  }
  if (entity.customPreparations != null) {
    throw ArgumentError('TEMPLATE schedules cannot include customPreparations');
  }
  return templateId;
}

List<OrderedPreparationStepModel>? _customPreparationsForMode(
  ScheduleEntity entity,
  SchedulePreparationMode? preparationMode,
) {
  if (preparationMode != SchedulePreparationMode.custom) {
    return null;
  }
  final preparation = entity.customPreparations;
  if (preparation == null) {
    throw ArgumentError('CUSTOM schedules require customPreparations');
  }
  if (entity.preparationTemplateId != null) {
    throw ArgumentError(
      'CUSTOM schedules cannot include preparationTemplateId',
    );
  }
  return OrderedPreparationStepModel.fromPreparationEntity(preparation);
}
