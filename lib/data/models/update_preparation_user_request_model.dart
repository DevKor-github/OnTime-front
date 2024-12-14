import 'package:json_annotation/json_annotation.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';

part 'update_preparation_user_request_model.g.dart';

@JsonSerializable()
class PreparationUserModifyRequestModel {
  @JsonKey(name: 'preparationId')
  final String id;
  final String preparationName;
  final int preparationTime;
  final String? nextPreparationId;

  PreparationUserModifyRequestModel({
    required this.id,
    required this.preparationName,
    required this.preparationTime,
    required this.nextPreparationId,
  });

  factory PreparationUserModifyRequestModel.fromJson(
          Map<String, dynamic> json) =>
      _$PreparationUserModifyRequestModelFromJson(json);

  Map<String, dynamic> toJson() =>
      _$PreparationUserModifyRequestModelToJson(this);

  static PreparationUserModifyRequestModel fromEntity(
      PreparationStepEntity entity) {
    return PreparationUserModifyRequestModel(
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

extension PreparationUserModifyRequestModelListExtension
    on List<PreparationUserModifyRequestModel> {
  List<PreparationStepEntity> toEntityList() {
    return map((model) => model.toEntity()).toList();
  }

  static List<PreparationUserModifyRequestModel> fromEntityList(
      List<PreparationStepEntity> entities) {
    return entities
        .map((entity) => PreparationUserModifyRequestModel.fromEntity(entity))
        .toList();
  }
}
