import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/utils/json_converters/duration_json_converters.dart';
import 'package:on_time_front/data/daos/place_dao.dart';
import 'package:on_time_front/data/daos/preparation_schedule_dao.dart';
import 'package:on_time_front/data/daos/preparation_user_dao.dart';

import 'package:on_time_front/data/daos/schedule_dao.dart';
import 'package:on_time_front/data/daos/user_dao.dart';
import 'package:on_time_front/data/tables/places_table.dart';
import 'package:on_time_front/data/tables/preparation_schedule_table.dart';
import 'package:on_time_front/data/tables/preparation_user_table.dart';
import 'package:on_time_front/data/tables/schedules_table.dart';
import 'package:on_time_front/data/tables/user_table.dart';
import 'package:uuid/uuid.dart';

part 'database.g.dart';

@Singleton()
@DriftDatabase(tables: [
  Places,
  Schedules,
  Users,
  PreparationSchedules,
  PreparationUsers,
], daos: [
  ScheduleDao,
  PlaceDao,
  UserDao,
  PreparationScheduleDao,
  PreparationUserDao
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from == 1) {
            await m.createTable(preparationSchedules);
            await m.createTable(preparationUsers);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'my_database');
  }
}
