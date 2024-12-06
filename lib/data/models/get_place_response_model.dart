import 'package:json_annotation/json_annotation.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';

part 'get_place_response_model.g.dart';

@JsonSerializable()
class GetPlaceResponseModel {
  final String placeId;
  final String placeName;

  const GetPlaceResponseModel({
    required this.placeId,
    required this.placeName,
  });

  factory GetPlaceResponseModel.fromJson(Map<String, dynamic> json) =>
      _$GetPlaceResponseModelFromJson(json);

  Map<String, dynamic> toJson() => _$GetPlaceResponseModelToJson(this);

  static GetPlaceResponseModel fromEntity(PlaceEntity entity) {
    return GetPlaceResponseModel(
      placeId: entity.id,
      placeName: entity.placeName,
    );
  }

  PlaceEntity toEntity() {
    return PlaceEntity(
      id: placeId,
      placeName: placeName,
    );
  }
}
