import 'package:json_annotation/json_annotation.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';

part 'get_preparation_response_model.g.dart';

@JsonSerializable()
class PreparationStepResponseModel {
  @JsonKey(name: 'preparationId')
  final String id;
  final String preparationName;
  final Duration preparationTime;
  final String? nextPreparationId;

  PreparationStepResponseModel({
    required this.id,
    required this.preparationName,
    required this.preparationTime,
    required this.nextPreparationId,
  });

  factory PreparationStepResponseModel.fromJson(Map<String, dynamic> json) =>
      _$PreparationResponseModelFromJson(json);

  Map<String, dynamic> toJson() => _$PreparationResponseModelToJson(this);

  PreparationStepEntity toEntity() {
    return PreparationStepEntity(
      id: id,
      preparationName: preparationName,
      preparationTime: preparationTime,
      nextPreparationId: nextPreparationId,
    );
  }

  static PreparationStepResponseModel fromEntity(PreparationStepEntity entity) {
    return PreparationStepResponseModel(
      id: entity.id,
      preparationName: entity.preparationName,
      preparationTime: entity.preparationTime,
      nextPreparationId: entity.nextPreparationId,
    );
  }
}

extension PreparationResponseModelListExtension
    on List<PreparationStepResponseModel> {
  PreparationEntity toPreparationEntity() {
    final steps = map((model) => model.toEntity()).toList();
    return PreparationEntity(preparationStepList: steps);
  }
}
