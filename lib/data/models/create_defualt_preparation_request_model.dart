import 'package:json_annotation/json_annotation.dart';
import 'package:on_time_front/data/models/create_preparation_step_request_model.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';

part 'create_defualt_preparation_request_model.g.dart';

@JsonSerializable()
class CreateDefaultPreparationRequestModel {
  final String spareTime;
  final String note;
  final List<CreatePreparationStepRequestModel> preparationList;

  CreateDefaultPreparationRequestModel({
    required this.spareTime,
    required this.note,
    required this.preparationList,
  });

  factory CreateDefaultPreparationRequestModel.fromJson(
          Map<String, dynamic> json) =>
      _$CreateDefaultPreparationRequestModelFromJson(json);

  Map<String, dynamic> toJson() =>
      _$CreateDefaultPreparationRequestModelToJson(this);

  static CreateDefaultPreparationRequestModel fromEntity(
      {required PreparationEntity preparationEntity,
      required Duration spareTime,
      required String note}) {
    return CreateDefaultPreparationRequestModel(
      spareTime: spareTime.inMinutes.toString(),
      note: note,
      preparationList: preparationEntity.preparationStepList
          .map((e) => CreatePreparationStepRequestModel.fromEntity(e))
          .toList(),
    );
  }
}
