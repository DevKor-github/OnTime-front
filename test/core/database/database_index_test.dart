import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'creates lookup indexes for schedule and preparation DAO predicates',
    () async {
      for (final entry in _expectedLookupIndexesByTable.entries) {
        final indexNames = await _indexNames(database, entry.key);

        expect(
          indexNames,
          containsAll(entry.value),
          reason: '${entry.key} should declare indexes for DAO lookup paths',
        );
      }
    },
  );

  test('adds lookup indexes when upgrading a schema 3 database', () async {
    expect(database.schemaVersion, 4);

    await _dropExpectedLookupIndexes(database);

    for (final entry in _expectedLookupIndexesByTable.entries) {
      expect(
        await _indexNames(database, entry.key),
        isNot(containsAll(entry.value)),
      );
    }

    await database.migration.onUpgrade(database.createMigrator(), 3, 4);

    for (final entry in _expectedLookupIndexesByTable.entries) {
      final indexNames = await _indexNames(database, entry.key);

      expect(
        indexNames,
        containsAll(entry.value),
        reason: '${entry.key} indexes should be added by the 3 -> 4 migration',
      );
    }
  });
}

const _expectedLookupIndexesByTable = {
  'preparation_schedules': {
    'preparation_schedules_schedule_id_idx',
    'preparation_schedules_next_preparation_id_idx',
  },
  'preparation_users': {
    'preparation_users_user_id_idx',
    'preparation_users_next_preparation_id_idx',
  },
  'schedules': {'schedules_schedule_time_idx', 'schedules_place_id_idx'},
};

Future<Set<String>> _indexNames(AppDatabase database, String tableName) async {
  final rows = await database
      .customSelect(
        '''
      SELECT name
      FROM sqlite_master
      WHERE type = 'index' AND tbl_name = ?
    ''',
        variables: [drift.Variable.withString(tableName)],
      )
      .get();

  return {for (final row in rows) row.read<String>('name')};
}

Future<void> _dropExpectedLookupIndexes(AppDatabase database) async {
  for (final indexNames in _expectedLookupIndexesByTable.values) {
    for (final indexName in indexNames) {
      await database.customStatement('DROP INDEX IF EXISTS $indexName');
    }
  }
}
