// Structured synthetic QA evidence is intentionally emitted to captured logs.
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:on_time_front/core/backup/backup_crypto.dart';
import 'package:on_time_front/core/backup/backup_content.dart';
import 'package:on_time_front/core/backup/backup_service.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/database/restore_runtime_identity.dart';
import 'package:on_time_front/core/services/app_metadata_service.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import '../../helpers/noop_alarm_cleanup.dart';
import '../../helpers/restore_staging_fixture.dart';
import '../../helpers/sodium_test_loader.dart';
import 'backup_validation_contract_test.dart' show validBackup;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const password = 'Synthetic legacy instant password';
  late AppDatabase db;
  late BackupService service;
  final crypto = BackupCrypto(sodiumLoader: loadSodiumForTest);
  Future<Uint8List> bytes(Map<String, dynamic> input) => crypto.encrypt(
    plaintext: Uint8List.fromList(utf8.encode(jsonEncode(input))),
    password: password,
  );
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.userDao.putUser(
      const UserEntity(
        id: 'local-profile',
        spareTime: Duration.zero,
        note: 'original sentinel',
      ),
    );
    service = BackupService(
      db,
      _Metadata(),
      NoopAlarmCleanup(),
      crypto: crypto,
      operationGate: LocalDataOperationGate(),
      runtimeIdentity: RestoreRuntimeIdentity(),
      cleanupPlatform: noPlatformRestoreCleanup,
      ingestionFactory: memoryBackupIngestion,
      stagingFactory: memoryRestoreStaging,
      processingOwner: testBackupProcessingOwner(),
    );
  });
  tearDown(() => db.close());
  test(
    'normal authenticated preview/apply/reexport preserves foreign civil gap raw text',
    () async {
      final input = validBackup();
      input['schedules'][0]['civilTime'] = '2026-03-08T02:30:00.123456';
      final candidate = await service.previewEncryptedBackup(
        await bytes(input),
        password,
      );
      await service.applyRestore(candidate);
      final raw =
          (await db
                  .customSelect('SELECT schedule_time FROM schedules')
                  .getSingle())
              .read<String>('schedule_time');
      expect(raw, '2026-03-08T02:30:00.123456');
      final output = await service.createEncryptedBackup(password);
      final decoded = jsonDecode(
        utf8.decode(
          await crypto.decrypt(container: output, password: password),
        ),
      );
      expect(decoded['schedules'][0]['civilTime'], raw);
    },
  );
  for (final field in ['createdAt', 'updatedAt']) {
    test(
      'template $field cannot infer an offsetless instant from device TZ',
      () async {
        final input = validBackup();
        final template = <String, dynamic>{
          'id': 'template',
          'name': 'Preparation',
          'createdAt': '2026-01-01T00:00:00Z',
          'updatedAt': '2026-01-01T00:00:00Z',
          'preparation': [],
        };
        template[field] = '2026-03-08T02:30:00';
        expect(
          () => BackupContent.fromJson({
            ...input,
            'templates': [template],
          }),
          throwsA(isA<BackupProcessingFailure>()),
        );
        input['templates'] = [template];
        await expectLater(
          service.previewEncryptedBackup(await bytes(input), password),
          throwsA(
            isA<BackupProcessingFailure>().having(
              (e) => e.kind,
              'kind',
              BackupFailureKind.unsupportedRepresentation,
            ),
          ),
        );
        expect(
          (await db.select(db.users).getSingle()).note,
          'original sentinel',
        );
        expect(await db.select(db.schedules).get(), isEmpty);
      },
    );
  }
  test(
    'template explicit offset epochs agree across both codecs and subsecond values reject',
    () async {
      for (final literal in [
        '2026-01-01T00:00:00Z',
        '2026-01-01T09:00:00+09:00',
      ]) {
        final input = validBackup();
        input['templates'] = [
          {
            'id': 'template',
            'name': 'Prep',
            'createdAt': literal,
            'updatedAt': literal,
            'preparation': [],
          },
        ];
        expect(
          BackupContent.fromJson(input).templates.single.createdAt,
          DateTime.utc(2026),
        );
        final candidate = await service.previewEncryptedBackup(
          await bytes(input),
          password,
        );
        await service.applyRestore(candidate);
        final stored = await db.select(db.preparationTemplates).getSingle();
        expect(stored.createdAt.toUtc(), DateTime.utc(2026));
      }
      final input = validBackup();
      input['templates'] = [
        {
          'id': 'template',
          'name': 'Prep',
          'createdAt': '2026-01-01T00:00:00.001Z',
          'updatedAt': '2026-01-01T00:00:00Z',
          'preparation': [],
        },
      ];
      expect(
        () => BackupContent.fromJson(input),
        throwsA(isA<BackupProcessingFailure>()),
      );
      final before = await db.select(db.preparationTemplates).getSingle();
      await expectLater(
        service.previewEncryptedBackup(await bytes(input), password),
        throwsA(isA<BackupProcessingFailure>()),
      );
      expect(await db.select(db.preparationTemplates).getSingle(), before);
    },
  );
  for (final field in ['startedAt', 'finishedAt']) {
    for (final literal in [
      '2026-03-08T02:30:00',
      '2026-11-01T01:30:00',
      '2026-01-01T00:00:00.001Z',
    ]) {
      test(
        '$field $literal is unsupported without changing original DB',
        () async {
          final input = validBackup();
          input['schedules'][0][field] = literal;
          final before = (await db.select(db.users).getSingle());
          await expectLater(
            service.previewEncryptedBackup(await bytes(input), password),
            throwsA(
              isA<BackupProcessingFailure>().having(
                (e) => e.kind,
                'kind',
                BackupFailureKind.unsupportedRepresentation,
              ),
            ),
          );
          expect(await db.select(db.users).getSingle(), before);
          expect(await db.select(db.schedules).get(), isEmpty);
        },
      );
    }
  }
  test(
    'explicit Z and +09:00 completion represent the same restored epoch',
    () async {
      for (final literal in [
        '2026-09-01T00:00:00Z',
        '2026-09-01T09:00:00+09:00',
      ]) {
        final input = validBackup();
        input['schedules'][0]['finishedAt'] = literal;
        final candidate = await service.previewEncryptedBackup(
          await bytes(input),
          password,
        );
        await service.applyRestore(candidate);
        expect(
          (await db.select(db.schedules).getSingle()).finishedAt!.toUtc(),
          DateTime.utc(2026, 9, 1),
        );
      }
    },
  );
  test(
    'UTC conversion outside supported years fails before changing original',
    () async {
      final before = await db.select(db.users).getSingle();
      for (final literal in [
        '0001-01-01T00:00:00+09:00',
        '9999-12-31T23:59:59-09:00',
      ]) {
        final input = validBackup();
        input['schedules'][0]['finishedAt'] = literal;
        await expectLater(
          service.previewEncryptedBackup(await bytes(input), password),
          throwsA(isA<BackupProcessingFailure>()),
        );
        expect(await db.select(db.users).getSingle(), before);
      }
    },
  );
  test(
    'offsetless cutoff retains literal metadata and commit installs actual local marker',
    () async {
      const literal = '2026-03-08T02:30:00';
      final input = validBackup()..['cutoff'] = literal;
      final candidate = await service.previewEncryptedBackup(
        await bytes(input),
        password,
      );
      expect(candidate.preview.cutoffLiteral, literal);
      expect(candidate.preview.cutoff, DateTime.utc(2026, 3, 8, 2, 30));
      expect((await db.select(db.users).getSingle()).note, 'original sentinel');
      final before = DateTime.now().toUtc().subtract(
        const Duration(seconds: 1),
      );
      await service.applyRestore(candidate);
      final row = await db.select(db.users).getSingle();
      expect(row.firstDurableDataAt!.toUtc().isBefore(before), false);
      expect(
        row.lastDurableDataAt!.toUtc().isAfter(DateTime.now().toUtc()),
        false,
      );
      expect(row.firstDurableDataAt, row.lastDurableDataAt);
      print(
        'D05_LEGACY_CUTOFF deviceTZ=${Platform.environment['TZ']} literal=${candidate.preview.cutoffLiteral} carrier=${candidate.preview.cutoff} actualCommitMarker=${row.firstDurableDataAt!.toUtc()}',
      );
    },
  );
}

class _Metadata implements AppMetadataProvider {
  @override
  Future<AppMetadata> getMetadata() async =>
      const AppMetadata(version: '1', buildNumber: '1');
}
