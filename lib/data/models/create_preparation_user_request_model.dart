import 'package:json_annotation/json_annotation.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';

part 'create_preparation_user_request_model.g.dart';

@JsonSerializable()
class PreparationUserRequestModel {
  @JsonKey(name: 'preparationId')
  final String id;
  final String preparationName;
  final int preparationTime;
  final String? nextPreparationId;

  PreparationUserRequestModel({
    required this.id,
    required this.preparationName,
    required this.preparationTime,
    required this.nextPreparationId,
  });

  factory PreparationUserRequestModel.fromJson(Map<String, dynamic> json) =>
      _$PreparationUserRequestModelFromJson(json);

  Map<String, dynamic> toJson() => _$PreparationUserRequestModelToJson(this);

  static PreparationUserRequestModel fromEntity(PreparationStepEntity entity) {
    return PreparationUserRequestModel(
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

extension PreparationUserRequestModelListExtension
    on List<PreparationUserRequestModel> {
  List<PreparationStepEntity> toEntityList() {
    return map((model) => model.toEntity()).toList();
  }

  static List<PreparationUserRequestModel> fromEntityList(
      List<PreparationStepEntity> entities) {
    return entities
        .map((entity) => PreparationUserRequestModel.fromEntity(entity))
        .toList();
  }
}
