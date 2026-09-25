import 'package:on_time_front/core/startup/startup_dependency_scope.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:drift/drift.dart';
import 'schema_contract.dart';
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
    : super(openOnTimeDatabase(keyStore)) {
    StartupDependencyScope.own(this, close);
  }

  AppDatabase.forTesting(super.e);

  @disposeMethod
  Future<void> disposeFromScope() =>
      StartupDependencyScope.release(this, close);

  @override
  int get schemaVersion => DatabaseSchemaContract.current;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      final existing = await customSelect(
        DatabaseSchemaContract.objectsQuery,
      ).get();
      if (existing.isNotEmpty) throw const UnsupportedDatabaseSchema();
      await transaction(() async {
        await m.createAll();
        await installAggregateConcurrency(this);
        await _validateSchema(schemaVersion);
        await customStatement('PRAGMA user_version = $schemaVersion');
      });
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 1 || from > schemaVersion || to > schemaVersion) {
        throw const UnsupportedDatabaseSchema();
      }
      await _validateSchema(from);
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
        if (from < 4) {
          await m.addColumn(schedules, schedules.requiresStartConfirmation);
          await m.addColumn(users, users.restoreCleanupPending);
          await m.addColumn(users, users.rejectLegacyDelivery);
        }
        await _validateSchema(schemaVersion);
        // Drift repeats this write after beforeOpen. Committing it here means
        // an error in that later write cannot leave new DDL with an old version.
        await customStatement('PRAGMA user_version = $schemaVersion');
      });
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await _validateSchema(schemaVersion);
    },
  );

  Future<void> _validateSchema(int version) async {
    final rows = await customSelect(DatabaseSchemaContract.objectsQuery).get();
    DatabaseSchemaContract.validate(version, rows.map((r) => r.data).toList());
    for (final row in rows.where((r) => r.read<String>('type') == 'table')) {
      final name = row.read<String>('name');
      final quoted = '"${name.replaceAll('"', '""')}"';
      final columns = await customSelect('PRAGMA table_xinfo($quoted)').get();
      final foreign = await customSelect(
        'PRAGMA foreign_key_list($quoted)',
      ).get();
      final indexRows = await customSelect('PRAGMA index_list($quoted)').get();
      final indexes = <Map<String, Object?>>[];
      for (final index in indexRows) {
        final indexName =
            '"${index.read<String>('name').replaceAll('"', '""')}"';
        final indexColumns = await customSelect(
          'PRAGMA index_xinfo($indexName)',
        ).get();
        indexes.add({
          ...index.data,
          'columns': indexColumns.map((r) => r.data).toList(),
        });
      }
      DatabaseSchemaContract.validateTableMetadata(
        version,
        name,
        columns.map((r) => r.data).toList(),
        foreign.map((r) => r.data).toList(),
        indexes,
      );
    }
    if ((await customSelect('PRAGMA foreign_key_check').get()).isNotEmpty) {
      throw const UnsupportedDatabaseSchema();
    }
  }

  /// Ordinary mutations share the existing replacement gate but stay available
  /// while a non-destructive export picker owns that gate.
  Future<T> writeTransaction<T>(
    Future<T> Function() action, {
    LocalDataOperationGate? gate,
  }) {
    final owner = gate ?? LocalDataOperationGate.shared;
    final generation = owner.captureWrite();
    return transaction(() async {
      owner.checkWrite(generation);
      final result = await action();
      owner.checkWrite(generation);
      return result;
    });
  }

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
