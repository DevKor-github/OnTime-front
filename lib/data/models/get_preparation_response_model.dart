import 'package:json_annotation/json_annotation.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';

part 'get_preparation_response_model.g.dart';

@JsonSerializable()
class PreparationResponseModel {
  @JsonKey(name: 'preparationId')
  final String id;
  final String preparationName;
  final int preparationTime;
  final String? nextPreparationId;

  PreparationResponseModel({
    required this.id,
    required this.preparationName,
    required this.preparationTime,
    required this.nextPreparationId,
  });

  factory PreparationResponseModel.fromJson(Map<String, dynamic> json) =>
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

  static PreparationResponseModel fromEntity(PreparationStepEntity entity) {
    return PreparationResponseModel(
      id: entity.id,
      preparationName: entity.preparationName,
      preparationTime: entity.preparationTime,
      nextPreparationId: entity.nextPreparationId,
    );
  }
}

extension PreparationResponseModelListExtension
    on List<PreparationResponseModel> {
  PreparationEntity toPreparationEntity() {
    final steps = map((model) => model.toEntity()).toList();
    return PreparationEntity(preparationStepList: steps);
  }
}
