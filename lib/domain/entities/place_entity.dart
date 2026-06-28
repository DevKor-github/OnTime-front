import 'package:equatable/equatable.dart';

class PlaceEntity extends Equatable {
  final String id;
  final String placeName;

  const PlaceEntity({required this.id, required this.placeName});

  @override
  List<Object?> get props => [id, placeName];
}
