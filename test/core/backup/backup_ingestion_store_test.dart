import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:on_time_front/core/backup/backup_ingestion_store.dart';
import 'package:on_time_front/core/backup/backup_json_reader.dart';
import 'package:on_time_front/core/backup/backup_limits.dart';
import 'package:on_time_front/core/backup/restore_staging.dart';
import 'package:on_time_front/core/database/encrypted_database_guard.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final library = Platform.environment['ONTIME_TEST_SQLCIPHER_LIBRARY'];
  if (library != null) open.overrideForAll(() => DynamicLibrary.open(library));

  test(
    'disk-shaped sink preserves forward order and skips unknown subtree reads',
    () async {
      final budget = BackupBudget();
      final store = BackupIngestionStore.memoryForTesting(budget);
      addTearDown(store.release);
      final root = await BackupJsonReader(store, budget).read(
        Stream.value(
          utf8.encode(
            '{"schedules":[{"id":"later-reference"}],"unknown":{"huge":"ignored"},"version":1}',
          ),
        ),
      );
      store.finish();
      expect(store.fields(root, {'version'}), {'version': 1});
      expect(store.children(root).map((r) => r['key']), [
        'schedules',
        'unknown',
        'version',
      ]);
    },
  );

  test(
    'unique index rejects escaped duplicate before last-value replacement',
    () async {
      final budget = BackupBudget();
      final store = BackupIngestionStore.memoryForTesting(budget);
      addTearDown(store.release);
      await expectLater(
        BackupJsonReader(
          store,
          budget,
        ).read(Stream.value(utf8.encode(r'{"a":1,"\u0061":2}'))),
        throwsA(isA<BackupProcessingFailure>()),
      );
    },
  );

  test(
    'exclusive creation collision preserves unowned original bytes',
    () async {
      final root = await Directory.systemTemp.createTemp('d05-collision-');
      addTearDown(() => root.delete(recursive: true));
      final original = File('${root.path}/collision.ingestion.sqlite');
      await original.writeAsString('not-our-file');
      await expectLater(
        BackupIngestionStore.create(
          BackupBudget(),
          root: root,
          attemptId: 'collision',
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(await original.readAsString(), 'not-our-file');
    },
  );

  test(
    'plaintext engine cannot create a production provisional store',
    () async {
      final root = await Directory.systemTemp.createTemp('d05-plain-');
      addTearDown(() => root.delete(recursive: true));
      await expectLater(
        BackupIngestionStore.create(BackupBudget(), root: root),
        throwsA(isA<EncryptedDatabaseUnavailable>()),
      );
      expect(await root.list().toList(), isEmpty);
    },
    skip: library != null
        ? 'Run without cipher override for plaintext guard'
        : false,
  );

  for (final count in [255, 256, 257]) {
    test(
      'actual encrypted index batch $count commits partial tail and rolls back failure tail',
      () async {
        final root = await Directory.systemTemp.createTemp('d05-index-batch-');
        addTearDown(() => root.delete(recursive: true));
        for (final fail in [false, true]) {
          final store = await BackupIngestionStore.create(
            BackupBudget(),
            root: root,
          );
          addTearDown(store.release);
          store.writeNode(null, null, 'object', null);
          store.finish();
          Future<void> write() => store.validateRecords(() async {
            for (var i = 0; i < count; i++) {
              store.addRecord('fixture', 'id-$i', i + 1);
            }
            if (fail) throw StateError('injected final index-batch failure');
          });
          if (fail) {
            await expectLater(write(), throwsStateError);
          } else {
            await write();
          }
          expect(
            store.recordCount('fixture'),
            fail ? count ~/ 256 * 256 : count,
          );
          await store.release();
          expect(await root.list().toList(), isEmpty);
        }
      },
      skip: library == null ? 'Actual SQLCipher required' : false,
    );
  }
  test(
    'actual SQLCipher provisional bytes, keyless guard and shared live cleanup',
    () async {
      final root = await Directory.systemTemp.createTemp('d05-cipher-');
      addTearDown(() => root.delete(recursive: true));
      final budget = BackupBudget();
      final store = await BackupIngestionStore.create(budget, root: root);
      addTearDown(store.release);
      final id = await BackupJsonReader(
        store,
        budget,
      ).read(Stream.value(utf8.encode('{"note":"PRIVATE-D05-INGESTION"}')));
      store.finish();
      final files = (await root.list().toList()).whereType<File>();
      final file = files.singleWhere((f) => f.path.endsWith('.sqlite'));
      expect(
        utf8.decode(await file.readAsBytes(), allowMalformed: true),
        isNot(contains('PRIVATE-D05-INGESTION')),
      );
      final wrong = sql.sqlite3.open(file.path);
      try {
        expect(
          () => wrong.select('SELECT * FROM nodes'),
          throwsA(isA<sql.SqliteException>()),
        );
      } finally {
        wrong.dispose();
      }
      await RestoreStaging.cleanupAbandoned(root: root);
      expect(await file.exists(), isTrue);
      expect(store.fields(id, {'note'}), {'note': 'PRIVATE-D05-INGESTION'});
      await store.release();
      expect(await root.list().toList(), isEmpty);
    },
    skip: library == null
        ? 'Requires actual host SQLCipher, not plaintext test adapter'
        : false,
  );
}
