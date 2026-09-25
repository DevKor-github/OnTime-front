import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

// The real SQLite connection becomes read-only only after the migration callback
// has committed. Drift's own later version write must fail with SQLITE_READONLY.
class _ReadOnlyAfterMigration extends AppDatabase {
  _ReadOnlyAfterMigration(super.executor) : super.forTesting();

  @override
  MigrationStrategy get migration {
    final base = super.migration;
    return MigrationStrategy(
      onCreate: base.onCreate,
      onUpgrade: base.onUpgrade,
      beforeOpen: (details) async {
        await base.beforeOpen?.call(details);
        if (details.hadUpgrade) {
          await customStatement('PRAGMA query_only = ON');
        }
      },
    );
  }
}

void main() {
  test(
    'external version-write failure leaves a complete current schema/version',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'ontime-d04-version-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/store.sqlite');
      final initial = sqlite.sqlite3.open(file.path);
      initial.execute(
        File('test/fixtures/database/schema_v2.sql').readAsStringSync(),
      );
      initial.execute(
        "INSERT INTO users(id,spare_time,note) VALUES('local-profile',17,'D04 synthetic unchanged')",
      );
      initial.dispose();

      final db = _ReadOnlyAfterMigration(NativeDatabase(file));
      await expectLater(
        db.customSelect('SELECT 1').get(),
        throwsA(
          isA<sqlite.SqliteException>().having(
            (e) => e.resultCode,
            'SQLITE_READONLY',
            8,
          ),
        ),
      );
      await db.close();
      final reopened = sqlite.sqlite3.open(
        file.path,
        mode: sqlite.OpenMode.readOnly,
      );
      try {
        final columns = reopened
            .select('PRAGMA table_info(users)')
            .map((r) => r['name'])
            .toList();
        expect(columns, contains('restore_cleanup_pending'));
        expect(
          reopened.select('SELECT note FROM users').single['note'],
          'D04 synthetic unchanged',
        );
        expect(
          reopened.userVersion,
          4,
          reason:
              'DDL and version must commit together even when Drift later repeats the version write',
        );
      } finally {
        reopened.dispose();
      }
    },
  );
}
