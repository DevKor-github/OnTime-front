import 'package:json_annotation/json_annotation.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';

part 'create_preparation_step_request_model.g.dart';

@JsonSerializable()
class CreatePreparationStepRequestModel {
  @JsonKey(name: 'preparationId')
  final String id;
  final String preparationName;
  final int preparationTime;
  final String? nextPreparationId;

  CreatePreparationStepRequestModel({
    required this.id,
    required this.preparationName,
    required this.preparationTime,
    required this.nextPreparationId,
  });

  factory CreatePreparationStepRequestModel.fromJson(
          Map<String, dynamic> json) =>
      _$CreatePreparationStepRequestModelFromJson(json);

  Map<String, dynamic> toJson() =>
      _$CreatePreparationStepRequestModelToJson(this);

  static CreatePreparationStepRequestModel fromEntity(
      PreparationStepEntity entity) {
    return CreatePreparationStepRequestModel(
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
