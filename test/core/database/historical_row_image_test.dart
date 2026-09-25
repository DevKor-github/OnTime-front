import 'package:on_time_front/core/database/schema_contract.dart';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  for (final version in DatabaseSchemaContract.legacySupported) {
    test(
      'historical v$version preserves every durable row image across upgrade and two reopens',
      () async {
        final dir = await Directory.systemTemp.createTemp('ontime-d04-rows-');
        addTearDown(() => dir.delete(recursive: true));
        final file = File('${dir.path}/store.sqlite');
        final original = sqlite.sqlite3.open(file.path);
        original.execute(
          File(
            'test/fixtures/database/schema_v$version.sql',
          ).readAsStringSync(),
        );
        original.execute(
          File('test/fixtures/database/populated_local.sql').readAsStringSync(),
        );
        if (version >= 2) {
          original.execute(
            File(
              'test/fixtures/database/populated_recurring.sql',
            ).readAsStringSync(),
          );
        }
        final image = <String, List<Map<String, Object?>>>{};
        final columns = <String, List<String>>{};
        for (final table in original.select(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT GLOB 'sqlite_*' ORDER BY name",
        )) {
          final name = table['name'] as String;
          columns[name] = original
              .select('PRAGMA table_info("$name")')
              .map((r) => r['name'] as String)
              .toList();
          image[name] = original
              .select('SELECT * FROM "$name" ORDER BY rowid')
              .map((r) => Map<String, Object?>.from(r))
              .toList();
          expect(
            image[name],
            isNotEmpty,
            reason: 'Every historical table must have actual synthetic rows',
          );
        }
        expect(image.length, version == 1 ? 7 : 11);
        original.dispose();
        Map<String, List<Map<String, Object?>>>? currentImage;
        for (var opening = 0; opening < 2; opening++) {
          final db = AppDatabase.forTesting(NativeDatabase(file));
          await db.customSelect('SELECT 1').get();
          await db.close();
          final reopened = sqlite.sqlite3.open(
            file.path,
            mode: sqlite.OpenMode.readOnly,
          );
          try {
            expect(reopened.userVersion, DatabaseSchemaContract.current);
            for (final entry in columns.entries) {
              final fields = entry.value.map((c) => '"$c"').join(',');
              final actual = reopened
                  .select('SELECT $fields FROM "${entry.key}" ORDER BY rowid')
                  .map((r) => Map<String, Object?>.from(r))
                  .toList();
              expect(
                actual,
                image[entry.key],
                reason:
                    'v$version ${entry.key} opening $opening original values',
              );
            }
            final after = <String, List<Map<String, Object?>>>{};
            for (final table in reopened.select(
              "SELECT name FROM sqlite_master WHERE type='table' AND name NOT GLOB 'sqlite_*' ORDER BY name",
            )) {
              final name = table['name'] as String;
              after[name] = reopened
                  .select('SELECT * FROM "$name" ORDER BY rowid')
                  .map((r) => Map<String, Object?>.from(r))
                  .toList();
            }
            if (currentImage != null) {
              expect(
                after,
                currentImage,
                reason:
                    'Second reopen must not regenerate identities or alter revisions',
              );
            }
            currentImage = after;
            expect(reopened.select('PRAGMA foreign_key_check'), isEmpty);
            expect(
              reopened.select('PRAGMA integrity_check').single.values.single,
              'ok',
            );
          } finally {
            reopened.dispose();
          }
        }
      },
    );
  }
}
