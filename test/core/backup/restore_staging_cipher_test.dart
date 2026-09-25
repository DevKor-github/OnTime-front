import 'package:on_time_front/core/backup/backup_ingestion_store.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';
import 'package:drift/native.dart';
import 'package:on_time_front/core/database/encrypted_database_guard.dart';
import 'package:on_time_front/core/backup/backup_service.dart';
import 'package:on_time_front/core/backup/backup_crypto.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/database/restore_runtime_identity.dart';
import 'package:on_time_front/core/services/app_metadata_service.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/noop_alarm_cleanup.dart';
import '../../helpers/sodium_test_loader.dart';
import 'dart:ffi';
import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:on_time_front/core/backup/restore_staging.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:drift/drift.dart' show Value;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final library = Platform.environment['ONTIME_TEST_SQLCIPHER_LIBRARY'];
  if (library != null) {
    open.overrideForAll(() => DynamicLibrary.open(library));
  }
  test(
    'staging exclusive collision preserves an unowned original file',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'd05-stage-collision-',
      );
      addTearDown(() => root.delete(recursive: true));
      final existing = File('${root.path}/collision.sqlite');
      await existing.writeAsString('unowned original');
      await expectLater(
        RestoreStaging.create(root: root, attemptId: 'collision'),
        throwsA(isA<FileSystemException>()),
      );
      expect(await existing.readAsString(), 'unowned original');
    },
  );

  test(
    'production staging refuses a plaintext SQLite engine',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'ontime-staging-plain-',
      );
      addTearDown(() => root.delete(recursive: true));
      await expectLater(
        RestoreStaging.create(root: root),
        throwsA(isA<EncryptedDatabaseUnavailable>()),
      );
      expect(await root.list().toList(), isEmpty);
    },
    skip: library != null
        ? 'Plaintext guard runs without SQLCipher override'
        : false,
  );
  test(
    'actual SQLCipher staging hides bytes and rejects missing/wrong keys',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'ontime-staging-cipher-',
      );
      addTearDown(() => root.delete(recursive: true));
      final stage = await RestoreStaging.create(root: root);
      final version = await stage.database
          .customSelect('PRAGMA cipher_version')
          .getSingle();
      expect(version.data.values.single, isNotEmpty);
      await stage.database
          .into(stage.database.users)
          .insert(
            UsersCompanion.insert(
              id: const Value('local-profile'),
              spareTime: 7,
              note: 'PRIVATE-STAGING-MARKER',
            ),
          );
      final file = (await root.list().toList()).whereType<File>().firstWhere(
        (f) => f.path.endsWith('.sqlite'),
      );
      final bytes = await file.readAsBytes();
      expect(
        utf8.decode(bytes, allowMalformed: true),
        isNot(contains('PRIVATE-STAGING-MARKER')),
      );
      expect(
        utf8.decode(bytes.take(16).toList(), allowMalformed: true),
        isNot(startsWith('SQLite format 3')),
      );
      for (final key in [null, 'incorrect-key']) {
        final raw = sqlite.sqlite3.open(file.path);
        try {
          if (key != null) raw.execute("PRAGMA key = '$key'");
          expect(
            () => raw.select('SELECT note FROM users'),
            throwsA(isA<sqlite.SqliteException>()),
          );
        } finally {
          raw.dispose();
        }
      }
      expect(
        (await stage.database.select(stage.database.users).getSingle()).note,
        'PRIVATE-STAGING-MARKER',
      );
      await stage.release();
      await stage.release();
      expect(await root.list().toList(), isEmpty);
    },
    skip: library == null
        ? 'Supply an actual SQLCipher shared library for encrypted host evidence'
        : false,
  );

  test(
    'encrypted unlink fault is typed; retry and keyless orphan cleanup preserve active candidates and external files',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'ontime-staging-fault-',
      );
      addTearDown(() => root.delete(recursive: true));
      final stagingRoot = Directory('${root.path}/owned');
      var fail = true;
      final stage = await RestoreStaging.create(
        root: stagingRoot,
        removeFile: (file) async {
          if (fail) {
            throw FileSystemException('injected unlink fault', file.path);
          }
          await file.delete();
        },
      );
      final stageFile = (await stagingRoot.list().toList())
          .whereType<File>()
          .firstWhere((f) => f.path.endsWith('.sqlite'));
      final orphan = await stageFile.copy(
        '${stagingRoot.path}/abandoned.sqlite',
      );
      final external = File('${root.path}/external.backup');
      await external.writeAsString('external-sentinel');
      await Link('${stagingRoot.path}/foreign-link').create(external.path);
      await RestoreStaging.cleanupAbandoned(root: stagingRoot);
      expect(await orphan.exists(), isFalse);
      expect(await external.readAsString(), 'external-sentinel');
      expect(await stageFile.exists(), isTrue);
      await expectLater(
        stage.release(),
        throwsA(
          isA<RestoreStagingCleanupFailure>().having(
            (e) => e.cleanupError,
            'unlink cause',
            isA<FileSystemException>(),
          ),
        ),
      );
      expect(await stageFile.exists(), isTrue);
      fail = false;
      await stage.release();
      expect(await stagingRoot.list().toList(), isEmpty);
      expect(await external.exists(), isTrue);
    },
    skip: library == null
        ? 'Requires actual SQLCipher for encrypted orphan evidence'
        : false,
  );

  for (final failureStage in ['cancel', 'validation', 'commit']) {
    test(
      'actual encrypted candidate $failureStage unlink fault preserves files and correct receipt ownership',
      () async {
        SharedPreferences.setMockInitialValues({
          'early_start_session_same': 'old',
        });
        final root = await Directory.systemTemp.createTemp(
          'a09-cipher-cleanup-',
        );
        addTearDown(() => root.delete(recursive: true));
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await db.userDao.putUser(
          const UserEntity(
            id: 'local-profile',
            spareTime: Duration.zero,
            note: 'original',
          ),
        );
        final before = await db.select(db.users).getSingle();
        final gate = LocalDataOperationGate();
        addTearDown(gate.dispose);
        var fail = false;
        var restoreAttempt = false;
        final processingOwner = BackupProcessingOwner();
        late RestoreStaging stage;
        Future<RestoreStaging> factory() async {
          stage = await RestoreStaging.create(
            root: Directory('${root.path}/owned'),
            removeFile: (file) async {
              if (fail) {
                throw FileSystemException('injected unlink failure', file.path);
              }
              await file.delete();
            },
          );
          if (restoreAttempt && failureStage == 'validation') {
            await stage.database.customStatement(
              "CREATE TRIGGER corrupt_readback AFTER INSERT ON users BEGIN UPDATE users SET note='changed'; END",
            );
          }
          return stage;
        }

        final backup = BackupService(
          db,
          _Metadata(),
          NoopAlarmCleanup(),
          crypto: BackupCrypto(sodiumLoader: loadSodiumForTest),
          operationGate: gate,
          processingOwner: processingOwner,
          ingestionFactory: (b) => BackupIngestionStore.create(
            b,
            root: Directory('${root.path}/ingestion'),
          ),
          stagingFactory: factory,
          runtimeIdentity: RestoreRuntimeIdentity(),
          cleanupPlatform: () async {},
        );
        final bytes = await backup.createEncryptedBackup(
          'portable backup password',
        );
        fail = true;
        restoreAttempt = true;
        BackupRestoreCandidate? candidate;
        if (failureStage == 'validation') {
          await expectLater(
            backup.previewEncryptedBackup(bytes, 'portable backup password'),
            throwsA(
              isA<BackupProcessingCleanupFailure>().having(
                (e) => e.originalError,
                'original validation failure',
                isFormatException,
              ),
            ),
          );
        } else {
          candidate = await backup.previewEncryptedBackup(
            bytes,
            'portable backup password',
          );
          if (failureStage == 'cancel') {
            await expectLater(
              candidate.dispose(),
              throwsA(isA<RestoreStagingCleanupFailure>()),
            );
          } else {
            await backup.applyRestore(candidate);
            expect(
              (await db.select(db.users).getSingle()).restoreCleanupPending,
              isTrue,
            );
          }
        }
        expect(
          (await Directory(
            '${root.path}/owned',
          ).list().toList()).whereType<File>(),
          isNotEmpty,
        );
        if (failureStage != 'commit') {
          expect(await db.select(db.users).getSingle(), before);
          expect(
            (await SharedPreferences.getInstance()).getString(
              'early_start_session_same',
            ),
            'old',
          );
        }
        final committed = await db.select(db.users).getSingle();
        fail = false;
        if (failureStage == 'commit') {
          await backup.finishRestoreCleanup();
          final clean = await db.select(db.users).getSingle();
          expect(clean.storeIncarnation, committed.storeIncarnation);
          expect(clean.dataRevision, committed.dataRevision);
          await expectLater(
            backup.applyRestore(candidate!),
            throwsA(isA<DataOperationException>()),
          );
        } else {
          await processingOwner.retryCleanup();
          expect(processingOwner.active, isNull);
        }
        expect(await Directory('${root.path}/owned').list().toList(), isEmpty);
      },
      skip: library == null
          ? 'Requires actual SQLCipher for candidate unlink fault evidence'
          : false,
    );
  }
  test(
    'portable backup uses actual encrypted staging and restores encrypted live DB across reopen',
    () async {
      SharedPreferences.setMockInitialValues({
        'early_start_session_orphan': 'old',
      });
      final root = await Directory.systemTemp.createTemp(
        'ontime-cipher-roundtrip-',
      );
      addTearDown(() => root.delete(recursive: true));
      final file = File('${root.path}/live.sqlite');
      AppDatabase openLive() => AppDatabase.forTesting(
        NativeDatabase(
          file,
          setup: (raw) {
            raw.execute("PRAGMA key = 'synthetic-test-installation-key'");
          },
        ),
      );
      var db = openLive();
      final gate = LocalDataOperationGate();
      addTearDown(gate.dispose);
      await db.userDao.putUser(
        const UserEntity(
          id: 'local-profile',
          spareTime: Duration(minutes: 12),
          note: 'cipher-roundtrip',
        ),
      );
      final service = BackupService(
        db,
        _Metadata(),
        NoopAlarmCleanup(),
        crypto: BackupCrypto(sodiumLoader: loadSodiumForTest),
        operationGate: gate,
        processingOwner: BackupProcessingOwner(),
        ingestionFactory: (b) => BackupIngestionStore.create(
          b,
          root: Directory('${root.path}/ingestion'),
        ),
        runtimeIdentity: RestoreRuntimeIdentity(),
        cleanupPlatform: () async {},
        stagingFactory: () =>
            RestoreStaging.create(root: Directory('${root.path}/staging')),
      );
      final encrypted = await service.createEncryptedBackup(
        'portable backup password',
      );
      final candidate = await service.previewEncryptedBackup(
        encrypted,
        'portable backup password',
      );
      expect(
        (await Directory(
          '${root.path}/staging',
        ).list().toList()).whereType<File>(),
        isNotEmpty,
      );
      final before = await db.select(db.users).getSingle();
      await service.applyRestore(candidate);
      final restored = await db.select(db.users).getSingle();
      expect(restored.storeIncarnation, isNot(before.storeIncarnation));
      expect(restored.note, 'cipher-roundtrip');
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
      expect(await Directory('${root.path}/staging').list().toList(), isEmpty);
      await db.close();
      db = openLive();
      try {
        final reopened = await db.select(db.users).getSingle();
        expect(reopened, restored);
        expect(reopened.restoreCleanupPending, isFalse);
        expect(reopened.rejectLegacyDelivery, isTrue);
      } finally {
        await db.close();
      }
    },
    skip: library == null
        ? 'Requires an actual SQLCipher library; separate host evidence'
        : false,
  );
}

class _Metadata implements AppMetadataProvider {
  @override
  Future<AppMetadata> getMetadata() async =>
      const AppMetadata(version: '1', buildNumber: '1');
}
