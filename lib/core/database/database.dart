import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:on_time_front/data/daos/schedule_dao.dart';
import '../../data/tables/places_table.dart';
import '../../data/tables/schedules_table.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Places, Schedules], daos: [ScheduleDao])
class AppDatabase extends _$AppDatabase {
  // After generating code, this class needs to define a schemaVersion getter
  // and a constructor telling drift where the database should be stored.
  // These are described in the getting started guide: https://drift.simonbinder.eu/getting-started/#open
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    // driftDatabase from package:drift_flutter stores the database in
    // getApplicationDocumentsDirectory().
    return driftDatabase(name: 'my_database');
  }
}
