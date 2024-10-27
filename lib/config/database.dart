import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'package:on_time_front/data/daos/schedule_dao.dart';

import '../data/tables/places_table.dart';
import '../data/tables/schedules_table.dart';
import '../data/tables/user_table.dart';
import '../data/tables/preparation_schedule_table.dart';
import '../data/tables/preparation_user_table.dart';

part 'database.g.dart';

@DriftDatabase(
    tables: [Places, Schedules, Users, PreparationSchedules, PreparationUsers],
    daos: [ScheduleDao])
class AppDatabase extends _$AppDatabase {
  // After generating code, this class needs to define a schemaVersion getter
  // and a constructor telling drift where the database should be stored.
  // These are described in the getting started guide: https://drift.simonbinder.eu/getting-started/#open
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from == 1) {
            await m.createTable(preparationUsers);
            await m.createTable(preparationSchedules);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _openConnection() {
    // driftDatabase from package:drift_flutter stores the database in
    // getApplicationDocumentsDirectory().
    return driftDatabase(name: 'my_database');
  }
}
