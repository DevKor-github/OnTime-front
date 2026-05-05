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
    if (isEmpty) {
      return PreparationEntity(preparationStepList: []);
    }

    final modelsById = {
      for (final model in this) model.id: model,
    };
    final referencedIds = {
      for (final model in this)
        if (model.nextPreparationId != null) model.nextPreparationId!,
    };
    final firstModel = firstWhere(
      (model) => !referencedIds.contains(model.id),
      orElse: () => first,
    );

    final orderedModels = <GetPreparationStepResponseModel>[];
    final visitedIds = <String>{};
    GetPreparationStepResponseModel? currentModel = firstModel;
    while (currentModel != null && visitedIds.add(currentModel.id)) {
      orderedModels.add(currentModel);
      final nextId = currentModel.nextPreparationId;
      currentModel = nextId == null ? null : modelsById[nextId];
    }

    for (final model in this) {
      if (visitedIds.add(model.id)) {
        orderedModels.add(model);
      }
    }

    final steps = orderedModels.map((model) => model.toEntity()).toList();
    return PreparationEntity(preparationStepList: steps);
  }
}
