import 'package:json_annotation/json_annotation.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';

part 'get_preparation_step_response_model.g.dart';

@JsonSerializable()
class GetPreparationStepResponseModel {
  @JsonKey(name: 'preparationId')
  final String id;
  final String preparationName;
  final int preparationTime;
  final String? nextPreparationId;

  GetPreparationStepResponseModel({
    required this.id,
    required this.preparationName,
    required this.preparationTime,
    required this.nextPreparationId,
  });

  factory GetPreparationStepResponseModel.fromJson(Map<String, dynamic> json) =>
      _$GetPreparationStepResponseModelFromJson(json);

  Map<String, dynamic> toJson() =>
      _$GetPreparationStepResponseModelToJson(this);

  PreparationStepEntity toEntity() {
    return PreparationStepEntity(
      id: id,
      preparationName: preparationName,
      preparationTime: Duration(minutes: preparationTime),
      nextPreparationId: nextPreparationId,
    );
  }

  static GetPreparationStepResponseModel fromEntity(
      PreparationStepEntity entity) {
    return GetPreparationStepResponseModel(
      id: entity.id,
      preparationName: entity.preparationName,
      preparationTime: entity.preparationTime.inMinutes,
      nextPreparationId: entity.nextPreparationId,
    );
  }
}

extension PreparationResponseModelListExtension
    on List<GetPreparationStepResponseModel> {
  PreparationEntity toPreparationEntity() {
    final steps = map((model) => model.toEntity()).toList();
    return PreparationEntity(preparationStepList: steps);
  }
}
