import '/core/database/database.dart';

class PlaceEntity {
  final String id;
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

  Place toModel() {
    return Place(
      id: id,
      placeName: placeName,
    );
  }
}
