import 'package:json_annotation/json_annotation.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';

part 'get_preparation_user_response_model.g.dart';

@JsonSerializable()
class PreparationUserResponseModel {
  @JsonKey(name: 'preparationId')
  final String id;
  final String preparationName;
  final int preparationTime;
  final String? nextPreparationId;

  PreparationUserResponseModel({
    required this.id,
    required this.preparationName,
    required this.preparationTime,
    required this.nextPreparationId,
  });

  factory PreparationUserResponseModel.fromJson(Map<String, dynamic> json) =>
      _$PreparationUserResponseModelFromJson(json);

  Map<String, dynamic> toJson() => _$PreparationUserResponseModelToJson(this);

  PreparationStepEntity toEntity() {
    return PreparationStepEntity(
      id: id,
      preparationName: preparationName,
      preparationTime: Duration(minutes: preparationTime),
      nextPreparationId: nextPreparationId,
    );
  }

  static PreparationUserResponseModel fromEntity(PreparationStepEntity entity) {
    return PreparationUserResponseModel(
      id: entity.id,
      preparationName: entity.preparationName,
      preparationTime: entity.preparationTime.inMinutes,
      nextPreparationId: entity.nextPreparationId,
    );
  }
}

@JsonSerializable()
class PreparationUserResponse {
  final String status;
  final String code;
  final String message;
  final List<PreparationUserResponseModel> data;

  PreparationUserResponse({
    required this.status,
    required this.code,
    required this.message,
    required this.data,
  });

  factory PreparationUserResponse.fromJson(Map<String, dynamic> json) =>
      _$PreparationUserResponseFromJson(json);

  Map<String, dynamic> toJson() => _$PreparationUserResponseToJson(this);

  PreparationEntity toEntity() {
    return PreparationEntity(
      preparationStepList: data.map((model) => model.toEntity()).toList(),
    );
  }
}
