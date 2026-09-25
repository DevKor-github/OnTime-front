import 'package:drift/drift.dart';
import 'package:on_time_front/core/database/schedule_aggregate_schema.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/database/installation_key_store.dart';
import 'package:on_time_front/core/database/open_database.dart';
import 'package:on_time_front/data/daos/place_dao.dart';
import 'package:on_time_front/data/daos/preparation_schedule_dao.dart';
import 'package:on_time_front/data/daos/preparation_template_dao.dart';
import 'package:on_time_front/data/daos/preparation_user_dao.dart';

import 'package:on_time_front/data/daos/schedule_dao.dart';
import 'package:on_time_front/data/daos/user_dao.dart';
import 'package:on_time_front/data/tables/places_table.dart';
import 'package:on_time_front/data/tables/preparation_schedule_table.dart';
import 'package:on_time_front/data/tables/preparation_template_step_table.dart';
import 'package:on_time_front/data/tables/preparation_template_table.dart';
import 'package:on_time_front/data/tables/preparation_user_table.dart';
import 'package:on_time_front/data/tables/schedules_table.dart';
import 'package:on_time_front/data/tables/user_table.dart';
import 'package:on_time_front/core/utils/json_converters/duration_json_converters.dart';
import 'package:uuid/uuid.dart';
import 'package:on_time_front/data/tables/recurring_schedule_tables.dart';
part 'database.g.dart';

@Singleton()
@DriftDatabase(
  tables: [
    Places,
    Schedules,
    Users,
    PreparationSchedules,
    PreparationUsers,
    PreparationTemplates,
    PreparationTemplateSteps,
    PreparationDefinitions,
    PreparationDefinitionSteps,
    RecurringScheduleSegments,
    RecurringScheduleExclusions,
  ],
  daos: [
    ScheduleDao,
    PlaceDao,
    UserDao,
    PreparationScheduleDao,
    PreparationUserDao,
    PreparationTemplateDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(InstallationKeyStore keyStore)
    : super(openOnTimeDatabase(keyStore));

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await installAggregateConcurrency(this);
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 1 || from > schemaVersion || to > schemaVersion) {
        throw StateError(
          'Only the encrypted local-only schema can be upgraded.',
        );
      }
      await transaction(() async {
        if (from < 2) {
          await m.createTable(preparationDefinitions);
          await m.createTable(preparationDefinitionSteps);
          await m.createTable(recurringScheduleSegments);
          await m.createTable(recurringScheduleExclusions);
          await m.addColumn(schedules, schedules.recurringSegmentId);
          await m.addColumn(schedules, schedules.recurringSlotKey);
          await m.addColumn(schedules, schedules.recurringOrdinal);
          await m.addColumn(schedules, schedules.recurringOverrides);
          await m.addColumn(schedules, schedules.preparationDefinitionId);
        }
        if (from < 3) {
          await m.addColumn(users, users.storeIncarnation);
          for (final column in [
            schedules.aggregateIncarnation,
            schedules.aggregateVersion,
            schedules.lastMutationId,
            schedules.lastMutationDigest,
            schedules.lastMutationVersion,
          ]) {
            await m.addColumn(schedules, column);
          }
          // Schema 1 creates the latest recurring tables above.
          if (from >= 2) {
            for (final column in [
              recurringScheduleSegments.rootSegmentId,
              recurringScheduleSegments.aggregateIncarnation,
              recurringScheduleSegments.aggregateVersion,
              recurringScheduleSegments.lastMutationId,
              recurringScheduleSegments.lastMutationDigest,
              recurringScheduleSegments.lastMutationVersion,
            ]) {
              await m.addColumn(recurringScheduleSegments, column);
            }
          }
          await installAggregateConcurrency(this);
        }
      });
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> deleteAllDurableData() async {
    await transaction(() async {
      await delete(recurringScheduleExclusions).go();
      await delete(recurringScheduleSegments).go();
      await delete(preparationDefinitionSteps).go();
      // Schedule references are nullable metadata, cleared with schedules below.
      await delete(preparationDefinitions).go();
      await delete(preparationTemplateSteps).go();
      await delete(preparationTemplates).go();
      await delete(preparationSchedules).go();
      await delete(preparationUsers).go();
      await delete(schedules).go();
      await delete(places).go();
      await delete(users).go();
    });
  }
}
