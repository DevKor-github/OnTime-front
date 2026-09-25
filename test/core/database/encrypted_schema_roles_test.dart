import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/encrypted_database_guard.dart';
import 'package:on_time_front/core/database/schema_contract.dart';
import 'package:on_time_front/core/database/recovery/encrypted_pair_database.dart';
import 'package:on_time_front/core/database/recovery/pair_files.dart';
import 'package:on_time_front/core/database/recovery/pair_key_store.dart';
import 'package:on_time_front/core/database/recovery/store_pair.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

const key = '0909090909090909090909090909090909090909090909090909090909090909';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final library = Platform.environment['ONTIME_TEST_SQLCIPHER_LIBRARY'];
  if (library != null) open.overrideForAll(() => DynamicLibrary.open(library));
  group(
    'actual encrypted schema role boundaries',
    () {
      for (final version in DatabaseSchemaContract.legacySupported) {
        test(
          'v$version readonly legacy probe preserves file family/key; only authorized startup upgrades',
          () async {
            final dir = await Directory.systemTemp.createTemp('d04-roles-');
            addTearDown(() => dir.delete(recursive: true));
            final keys = PairKeyStore();
            const legacy = StorePair.legacy();
            final pair = StorePair.candidate(
              '10000000-0000-4000-8000-000000000001',
            );
            final encoded = base64UrlEncode(List.filled(32, 9));
            FlutterSecureStorage.setMockInitialValues({
              keys.slot(legacy): encoded,
              keys.slot(pair): encoded,
            });
            final files = PairFiles(dir, keys, protect: (_) async {});
            await files.prepareDirectories();
            final file = files.database(legacy);
            final raw = sqlite.sqlite3.open(file.path);
            guardEncryptedDatabase(
              raw,
              key,
              role: DatabaseOpenRole.ownedCreation,
              allowCreation: true,
            );
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
            raw.dispose();
            await file.copy(files.database(pair).path);
            final before = await _files(dir);
            expect(await originalPairReadable(files, legacy), true);
            expect(
              await originalPairReadable(files, pair),
              false,
              reason:
                  'Historical pair lineage is invalid; current synthetic profile also lacks reject-legacy flag',
            );
            expect(await _files(dir), before);
            expect(await keys.raw(legacy), encoded);
            expect(await keys.raw(pair), encoded);
            if (version != DatabaseSchemaContract.current) {
              await expectLater(
                openEncryptedPair(files, pair),
                throwsA(isA<UnsupportedDatabaseSchema>()),
              );
              await expectLater(
                openEncryptedPair(files, pair, startupMigration: true),
                throwsA(isA<UnsupportedDatabaseSchema>()),
              );
              expect(await _files(dir), before);
            }
            final db = AppDatabase.forTesting(
              NativeDatabase(
                file,
                setup: (r) => guardEncryptedDatabase(
                  r,
                  key,
                  role: DatabaseOpenRole.legacyStartup,
                ),
              ),
            );
            expect(
              (await db.customSelect('PRAGMA user_version').getSingle())
                  .data
                  .values
                  .single,
              DatabaseSchemaContract.current,
            );
            await db.close();
            final reopened = sqlite.sqlite3.open(
              file.path,
              mode: sqlite.OpenMode.readOnly,
            );
            guardEncryptedDatabase(
              reopened,
              key,
              role: DatabaseOpenRole.legacyStartup,
            );
            expect(
              reopened.select('SELECT note FROM users').single['note'],
              '합성 프로필  공백',
            );
            reopened.dispose();
            expect(await keys.raw(legacy), encoded);
          },
        );
      }
      for (final mutation in [
        'future',
        'nonempty-zero',
        'unknown-table',
        'missing-trigger',
        'changed-literal',
        'invalid-fk',
        'invalid-flags',
      ]) {
        test(
          '$mutation actual file is refused and byte-preserved by readonly original probe',
          () async {
            final dir = await Directory.systemTemp.createTemp('d04-preserve-');
            addTearDown(() => dir.delete(recursive: true));
            final keys = PairKeyStore();
            const pair = StorePair.legacy();
            final encoded = base64UrlEncode(List.filled(32, 9));
            FlutterSecureStorage.setMockInitialValues({
              keys.slot(pair): encoded,
            });
            final files = PairFiles(dir, keys, protect: (_) async {});
            final file = files.database(pair);
            final raw = sqlite.sqlite3.open(file.path);
            guardEncryptedDatabase(
              raw,
              key,
              role: DatabaseOpenRole.ownedCreation,
              allowCreation: true,
            );
            raw.execute(
              File('test/fixtures/database/schema_v4.sql').readAsStringSync(),
            );
            raw.execute(
              File(
                'test/fixtures/database/populated_local.sql',
              ).readAsStringSync(),
            );
            switch (mutation) {
              case 'future':
                raw.userVersion = DatabaseSchemaContract.current + 1;
              case 'nonempty-zero':
                raw.userVersion = 0;
              case 'unknown-table':
                raw.execute('CREATE TABLE sqlitex_probe(value TEXT)');
              case 'missing-trigger':
                raw.execute('DROP TRIGGER users_identity');
              case 'changed-literal':
                final sql =
                    raw
                            .select(
                              "SELECT sql FROM sqlite_master WHERE name='users_identity'",
                            )
                            .single['sql']
                        as String;
                raw.execute('DROP TRIGGER users_identity');
                raw.execute(sql.replaceAll('IS NULL', 'IS "NULL"'));
              case 'invalid-fk':
                raw.execute("UPDATE schedules SET place_id='missing'");
              case 'invalid-flags':
                raw.execute('PRAGMA ignore_check_constraints=ON');
                raw.execute('UPDATE users SET reject_legacy_delivery=2');
            }
            raw.dispose();
            final before = await _files(dir);
            expect(await originalPairReadable(files, pair), false);
            expect(await _files(dir), before);
            expect(await keys.raw(pair), encoded);
            final db = AppDatabase.forTesting(
              NativeDatabase(
                file,
                setup: (r) => guardEncryptedDatabase(
                  r,
                  key,
                  role: DatabaseOpenRole.legacyStartup,
                ),
              ),
            );
            await expectLater(
              db.customSelect('SELECT 1').get(),
              throwsA(isA<UnsupportedDatabaseSchema>()),
            );
            await db.close();
            expect(await _files(dir), before);
            expect(await keys.raw(pair), encoded);
          },
        );
      }
      test('empty schema requires explicit creation authority and role', () {
        for (final role in DatabaseOpenRole.values) {
          for (final allowed in [false, true]) {
            final raw = sqlite.sqlite3.openInMemory();
            try {
              void action() => guardEncryptedDatabase(
                raw,
                key,
                role: role,
                allowCreation: allowed,
              );
              if (allowed &&
                  [
                    DatabaseOpenRole.ownedCreation,
                    DatabaseOpenRole.legacyStartup,
                  ].contains(role)) {
                action();
              } else {
                expect(action, throwsA(isA<UnsupportedDatabaseSchema>()));
              }
              expect(raw.userVersion, 0);
              expect(raw.select(DatabaseSchemaContract.objectsQuery), isEmpty);
            } finally {
              raw.dispose();
            }
          }
        }
      });
    },
    skip: library == null
        ? 'Requires actual host SQLCipher; not mobile evidence'
        : false,
  );
}

Future<Map<String, List<int>>> _files(Directory directory) async {
  final out = <String, List<int>>{};
  await for (final entity in directory.list(recursive: true)) {
    if (entity is File) {
      out[entity.path.substring(directory.path.length)] = await entity
          .readAsBytes();
    }
  }
  return out;
}
