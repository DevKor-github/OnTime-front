import 'package:equatable/equatable.dart';

import '/core/database/database.dart';

class PlaceEntity extends Equatable {
  final String id;
  final String placeName;

  const PlaceEntity({required this.id, required this.placeName});

  static PlaceEntity fromModel(Place place) {
    return PlaceEntity(id: place.id, placeName: place.placeName);
  }

  Place toModel() {
    return Place(id: id, placeName: placeName);
  }

  @override
  List<Object?> get props => [id, placeName];
}
