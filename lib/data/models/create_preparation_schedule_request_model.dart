import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';

part 'create_preparation_schedule_request_model.g.dart';

@JsonSerializable()
class PreparationScheduleCreateRequestModel {
  @JsonKey(name: 'preparationId')
  final String id;
  final String preparationName;
  final int preparationTime;
  final String? nextPreparationId;

  PreparationScheduleCreateRequestModel({
    required this.id,
    required this.preparationName,
    required this.preparationTime,
    required this.nextPreparationId,
  });

  factory PreparationScheduleCreateRequestModel.fromJson(
          Map<String, dynamic> json) =>
      _$PreparationScheduleCreateRequestModelFromJson(json);

  Map<String, dynamic> toJson() =>
      _$PreparationScheduleCreateRequestModelToJson(this);

  static PreparationScheduleCreateRequestModel fromEntity(
      PreparationStepEntity entity) {
    return PreparationScheduleCreateRequestModel(
      id: entity.id,
      preparationName: entity.preparationName,
      preparationTime: entity.preparationTime,
      nextPreparationId: entity.nextPreparationId,
    );
  }

  PreparationStepEntity toEntity() {
    return PreparationStepEntity(
      id: id,
      preparationName: preparationName,
      preparationTime: preparationTime,
      nextPreparationId: nextPreparationId,
    );
  }
}

extension PreparationScheduleCreateRequestModelListExtension
    on List<PreparationScheduleCreateRequestModel> {
  List<PreparationStepEntity> toEntityList() {
    return map((model) => model.toEntity()).toList();
  }

  static List<PreparationScheduleCreateRequestModel> fromEntityList(
      List<PreparationStepEntity> entities) {
    return entities
        .map((entity) =>
            PreparationScheduleCreateRequestModel.fromEntity(entity))
        .toList();
  }
}

extension PreparationStepEntityListExtension on List<PreparationStepEntity> {
  void updateLinksAfterDeletion(String deletedId) {
    for (var i = 0; i < length; i++) {
      if (this[i].nextPreparationId == deletedId) {
        this[i].updateNextPreparationId(
          firstWhereOrNull((step) => step.id == deletedId)?.nextPreparationId,
        );
        break;
      }
    }
  }
}
