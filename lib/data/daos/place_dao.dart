import 'package:drift/drift.dart';
import 'package:on_time_front/config/database.dart';
import 'package:on_time_front/data/tables/places_table.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';

part 'place_dao.g.dart';

@DriftAccessor(tables: [Places])
class PlaceDao extends DatabaseAccessor<AppDatabase> with _$PlaceDaoMixin {
  final AppDatabase db;

  PlaceDao(this.db) : super(db);

  Future<void> createPlace(PlaceEntity placeEntity) async {
    await into(db.places).insert(
      placeEntity.toModel().toCompanion(false),
    );
  }

  Future<List> getAllPlaces() async {
    final places = await select(db.places).get();
    return places.map((place) => PlaceEntity.fromModel(place)).toList();
  }
}
