import 'package:json_annotation/json_annotation.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';

part 'update_preparation_schedule_request_model.g.dart';

@JsonSerializable()
class PreparationScheduleModifyRequestModel {
  @JsonKey(name: 'preparationId')
  final String id;
  final String preparationName;
  final int preparationTime;
  final String? nextPreparationId;

  PreparationScheduleModifyRequestModel({
    required this.id,
    required this.preparationName,
    required this.preparationTime,
    required this.nextPreparationId,
  });

  factory PreparationScheduleModifyRequestModel.fromJson(
          Map<String, dynamic> json) =>
      _$PreparationScheduleModifyRequestModelFromJson(json);

  Map<String, dynamic> toJson() =>
      _$PreparationScheduleModifyRequestModelToJson(this);

  static PreparationScheduleModifyRequestModel fromEntity(
      PreparationStepEntity entity) {
    return PreparationScheduleModifyRequestModel(
      id: entity.id,
      preparationName: entity.preparationName,
      preparationTime: entity.preparationTime.inMinutes,
      nextPreparationId: entity.nextPreparationId,
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

extension PreparationScheduleModifyRequestModelListExtension
    on List<PreparationScheduleModifyRequestModel> {
  List<PreparationStepEntity> toEntityList() {
    return map((model) => model.toEntity()).toList();
  }

  static List<PreparationScheduleModifyRequestModel> fromEntityList(
      List<PreparationStepEntity> entities) {
    return entities
        .map((entity) =>
            PreparationScheduleModifyRequestModel.fromEntity(entity))
        .toList();
  }
}
