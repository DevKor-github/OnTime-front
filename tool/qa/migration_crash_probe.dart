// Synthetic host process-death probe. Never selects an installed app database.
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/encrypted_database_guard.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

const syntheticKey =
    '0707070707070707070707070707070707070707070707070707070707070707';

class _CheckpointDatabase extends AppDatabase {
  _CheckpointDatabase(super.executor, this.stop, this.point)
    : super.forTesting();
  final Future<void> Function() stop;
  final String point;
  bool first = false;
  @override
  Future<void> customStatement(String statement, [List<dynamic>? args]) async {
    if (point == 'before-version' &&
        statement.startsWith('PRAGMA user_version =')) {
      await stop();
    }
    await super.customStatement(statement, args);
    if (point == 'after-version' &&
        statement.startsWith('PRAGMA user_version =')) {
      await stop();
    }
    if (!first &&
        (statement.startsWith('CREATE TABLE') ||
            statement.startsWith('ALTER TABLE'))) {
      first = true;
      if (point == 'after-first-ddl') await stop();
    }
  }

  @override
  MigrationStrategy get migration {
    final base = super.migration;
    return MigrationStrategy(
      onCreate: base.onCreate,
      onUpgrade: base.onUpgrade,
      beforeOpen: (details) async {
        if (details.hadUpgrade && point == 'after-commit') await stop();
        await base.beforeOpen?.call(details);
      },
    );
  }
}

void main() {
  test(
    'actual process death leaves complete encrypted historical or current store',
    () async {
      final directory = Platform.environment['D04_PROBE_DIR'];
      final library = Platform.environment['ONTIME_TEST_SQLCIPHER_LIBRARY'];
      final point = Platform.environment['D04_PROBE_POINT'];
      if (directory == null || library == null || point == null) {
        throw StateError('Explicit synthetic probe environment required');
      }
      open.overrideForAll(() => DynamicLibrary.open(library));
      final file = File('$directory/store.sqlite');
      if (Platform.environment['D04_PROBE_MODE'] == 'cut') {
        final original = sqlite.sqlite3.open(file.path);
        guardEncryptedDatabase(
          original,
          syntheticKey,
          role: DatabaseOpenRole.ownedCreation,
          allowCreation: true,
        );
        original.execute(
          File('test/fixtures/database/schema_v1.sql').readAsStringSync(),
        );
        original.execute(
          File('test/fixtures/database/populated_local.sql').readAsStringSync(),
        );
        final image = <String, List<Map<String, Object?>>>{};
        for (final row in original.select(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT GLOB 'sqlite_*'",
        )) {
          final name = row['name'] as String;
          image[name] = original
              .select('SELECT * FROM "$name" ORDER BY rowid')
              .map((r) => Map<String, Object?>.from(r))
              .toList();
        }
        File(
          '$directory/original-image.json',
        ).writeAsStringSync(jsonEncode(image), flush: true);
        original.dispose();
        final db = _CheckpointDatabase(
          NativeDatabase(
            file,
            setup: (raw) => guardEncryptedDatabase(
              raw,
              syntheticKey,
              role: DatabaseOpenRole.legacyStartup,
            ),
          ),
          () async {
            File('$directory/cut-ready').writeAsStringSync(point, flush: true);
            await Completer<void>().future;
          },
          point,
        );
        await db.customSelect('SELECT 1').get();
        throw StateError('Checkpoint was not reached');
      }
      final raw = sqlite.sqlite3.open(
        file.path,
        mode: sqlite.OpenMode.readOnly,
      );
      try {
        guardEncryptedDatabase(
          raw,
          syntheticKey,
          role: DatabaseOpenRole.legacyStartup,
        );
        expect(raw.userVersion, point == 'after-commit' ? 4 : 1);
        final image =
            jsonDecode(
                  File('$directory/original-image.json').readAsStringSync(),
                )
                as Map<String, dynamic>;
        for (final entry in image.entries) {
          final rows = (entry.value as List).cast<Map<String, dynamic>>();
          final projection = rows.first.keys.map((k) => '"$k"').join(',');
          expect(
            raw
                .select('SELECT $projection FROM "${entry.key}" ORDER BY rowid')
                .map((r) => Map<String, Object?>.from(r))
                .toList(),
            rows,
          );
        }
        File('$directory/verified').writeAsStringSync(
          jsonEncode({
            'sqliteVersion': raw
                .select('SELECT sqlite_version()')
                .single
                .values
                .single,
            'cipherVersion': raw
                .select('PRAGMA cipher_version')
                .single
                .values
                .single,
            'recoverTestPid': pid,
            'schemaVersion': raw.userVersion,
            'tablesWithOriginalRows': image.length,
            'actualCipher': true,
            'mobileBundleVerified': false,
            'powerLossVerified': false,
          }),
          flush: true,
        );
      } finally {
        raw.dispose();
      }
    },
  );
}
