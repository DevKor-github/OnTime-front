import 'package:drift/drift.dart';
import '/core/database/database.dart';
import 'package:on_time_front/data/tables/places_table.dart';

part 'place_dao.g.dart';

@DriftAccessor(tables: [Places])
class PlaceDao extends DatabaseAccessor<AppDatabase> with _$PlaceDaoMixin {
  final AppDatabase db;

  PlaceDao(this.db) : super(db);

  Future<Place> createPlace(Place placeModel) async {
    return await into(db.places).insertReturning(
      placeModel.toCompanion(false),
    );
  }

  Future<List<Place>> getAllPlaces() async {
    final places = await select(db.places).get();
    return places.toList();
  }
}
