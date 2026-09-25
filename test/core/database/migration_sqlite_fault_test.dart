import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/schema_contract.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

class _FaultDatabase extends AppDatabase {
  _FaultDatabase(super.executor, this.kind, this.raw, this.reader)
    : super.forTesting();
  final String kind;
  final sqlite.Database Function() raw;
  final sqlite.Database reader;
  bool injected = false;
  @override
  Future<void> customStatement(String statement, [List<dynamic>? args]) async {
    if (!injected &&
        kind == 'constraint' &&
        statement.startsWith('UPDATE users SET store_incarnation')) {
      injected = true;
      await super.customStatement(
        "CREATE TRIGGER d04_fault BEFORE UPDATE ON users BEGIN SELECT RAISE(ABORT, 'synthetic migration constraint'); END",
      );
    } else if (!injected &&
        kind == 'readonly' &&
        statement.startsWith('ALTER TABLE')) {
      injected = true;
      raw().execute('PRAGMA query_only=ON');
    } else if (!injected &&
        kind == 'full' &&
        statement.startsWith('ALTER TABLE')) {
      injected = true;
      final pages = raw().select('PRAGMA page_count').single.values.single;
      raw().execute('PRAGMA max_page_count=$pages');
      // Actual SQLite allocation failure in the same migration transaction.
      // This test-only write forces disk-page demand without filling the host.
      await super.customStatement('UPDATE users SET note=zeroblob(1048576)');
    }
    await super.customStatement(statement, args);
    if (!injected &&
        kind == 'locked' &&
        statement.startsWith('PRAGMA user_version =')) {
      injected = true;
      reader.execute('BEGIN');
      reader.select('SELECT note FROM users'); // Holds an actual shared lock.
    }
  }
}

void main() {
  for (final entry in {
    'constraint': 19,
    'readonly': 8,
    'full': 13,
    'locked': 5,
  }.entries) {
    test(
      'real SQLite ${entry.key} failure preserves historical schema and rows',
      () async {
        final dir = await Directory.systemTemp.createTemp('ontime-d04-fault-');
        addTearDown(() => dir.delete(recursive: true));
        final file = File('${dir.path}/store.sqlite');
        final initial = sqlite.sqlite3.open(file.path);
        initial.execute(
          File('test/fixtures/database/schema_v2.sql').readAsStringSync(),
        );
        initial.execute(
          "INSERT INTO users(id,spare_time,note) VALUES('local-profile',17,'preserve synthetic value')",
        );
        initial.dispose();
        late sqlite.Database connection;
        final reader = sqlite.sqlite3.open(file.path);
        final db = _FaultDatabase(
          NativeDatabase(file, setup: (r) => connection = r),
          entry.key,
          () => connection,
          reader,
        );
        try {
          await expectLater(
            db.customSelect('SELECT 1').get(),
            throwsA(
              isA<sqlite.SqliteException>().having(
                (e) => e.resultCode,
                'actual SQLite error code',
                entry.value,
              ),
            ),
          );
          expect(db.injected, true);
        } finally {
          reader.dispose();
          await db.close();
        }
        final reopened = sqlite.sqlite3.open(
          file.path,
          mode: sqlite.OpenMode.readOnly,
        );
        try {
          expect(reopened.userVersion, 2);
          expect(
            reopened.select('SELECT note FROM users').single['note'],
            'preserve synthetic value',
          );
          expect(
            reopened.select('PRAGMA table_info(users)').map((r) => r['name']),
            isNot(contains('store_incarnation')),
          );
          expect(
            reopened.select(
              "SELECT name FROM sqlite_master WHERE name='d04_fault'",
            ),
            isEmpty,
          );
          expect(
            reopened.select('PRAGMA integrity_check').single.values.single,
            'ok',
          );
        } finally {
          reopened.dispose();
        }
        final retry = AppDatabase.forTesting(NativeDatabase(file));
        try {
          expect(
            (await retry.customSelect('PRAGMA user_version').getSingle())
                .data
                .values
                .single,
            DatabaseSchemaContract.current,
          );
          expect(
            (await retry.customSelect('SELECT note FROM users').getSingle())
                .read<String>('note'),
            'preserve synthetic value',
          );
        } finally {
          await retry.close();
        }
      },
    );
  }
}
