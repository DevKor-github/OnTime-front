import 'package:on_time_front/core/database/database.dart';

class PlaceEntity {
  final int id;
  final String placeName;

  PlaceEntity({
    required this.id,
    required this.placeName,
  });

  static fromModel(Place place) {
    return PlaceEntity(
      id: place.id,
      placeName: place.placeName,
    );
  }
}
