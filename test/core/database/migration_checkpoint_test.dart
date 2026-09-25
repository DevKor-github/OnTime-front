import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/schema_contract.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

class _MigrationCheckpoint extends AppDatabase {
  _MigrationCheckpoint(super.executor, {this.cut, this.after = false})
    : super.forTesting();
  final int? cut;
  final bool after;
  final writes = <String>[];
  bool hit = false;
  @override
  Future<void> customStatement(String statement, [List<dynamic>? args]) async {
    final observed =
        statement.startsWith('CREATE ') ||
        statement.startsWith('ALTER ') ||
        statement.startsWith('UPDATE ') ||
        statement.startsWith('PRAGMA user_version =');
    final index = observed ? writes.length : -1;
    if (observed) writes.add(statement);
    Future<void> fault() async {
      hit = true;
      // Real SQLite error on the transaction connection, not a Dart throw.
      await super.customStatement('SELECT d04_nonexistent_migration_column');
    }

    if (observed && index == cut && !after) await fault();
    await super.customStatement(statement, args);
    if (observed && index == cut && after) await fault();
  }
}

void main() {
  for (final version in DatabaseSchemaContract.legacySupported.where(
    (v) => v < DatabaseSchemaContract.current,
  )) {
    test(
      'v$version every migration write before/after SQLite fault rolls back all historical data',
      () async {
        final dir = await Directory.systemTemp.createTemp(
          'ontime-d04-all-writes-',
        );
        addTearDown(() => dir.delete(recursive: true));
        final file = File('${dir.path}/store.sqlite');
        Map<String, List<Map<String, Object?>>> seed() {
          final raw = sqlite.sqlite3.open(file.path);
          try {
            raw.execute(
              File(
                'test/fixtures/database/schema_v$version.sql',
              ).readAsStringSync(),
            );
            raw.execute(
              File(
                'test/fixtures/database/populated_local.sql',
              ).readAsStringSync(),
            );
            if (version >= 2) {
              raw.execute(
                File(
                  'test/fixtures/database/populated_recurring.sql',
                ).readAsStringSync(),
              );
            }
            return {
              for (final row in raw.select(
                "SELECT name FROM sqlite_master WHERE type='table' AND name NOT GLOB 'sqlite_*'",
              ))
                row['name'] as String: raw
                    .select('SELECT * FROM "${row['name']}" ORDER BY rowid')
                    .map((r) => Map<String, Object?>.from(r))
                    .toList(),
            };
          } finally {
            raw.dispose();
          }
        }

        seed();
        final trace = _MigrationCheckpoint(NativeDatabase(file));
        await trace.customSelect('SELECT 1').get();
        final count = trace.writes.length;
        expect(count, greaterThan(0));
        await trace.close();
        await file.delete();
        for (var point = 0; point < count; point++) {
          for (final after in [false, true]) {
            final image = seed();
            final db = _MigrationCheckpoint(
              NativeDatabase(file),
              cut: point,
              after: after,
            );
            await expectLater(
              db.customSelect('SELECT 1').get(),
              throwsA(
                isA<sqlite.SqliteException>().having(
                  (e) => e.resultCode,
                  'SQLITE_ERROR',
                  1,
                ),
              ),
              reason: 'v$version point$point after$after',
            );
            expect(db.hit, true);
            await db.close();
            final raw = sqlite.sqlite3.open(
              file.path,
              mode: sqlite.OpenMode.readOnly,
            );
            try {
              expect(raw.userVersion, version);
              DatabaseSchemaContract.validate(
                version,
                raw.select(DatabaseSchemaContract.objectsQuery),
              );
              for (final entry in image.entries) {
                expect(
                  raw
                      .select('SELECT * FROM "${entry.key}" ORDER BY rowid')
                      .map((r) => Map<String, Object?>.from(r))
                      .toList(),
                  entry.value,
                  reason: 'v$version point$point after$after ${entry.key}',
                );
              }
              expect(raw.select('PRAGMA foreign_key_check'), isEmpty);
            } finally {
              raw.dispose();
            }
            await file.delete();
          }
        }
        // Counts are derived from the real migration, so newly added writes cannot
        // silently miss the before/after fault matrix.
        // ignore: avoid_print
        print(
          'v$version: $count actual migration writes, ${count * 2} SQLite fault/reopen cases',
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }
}
