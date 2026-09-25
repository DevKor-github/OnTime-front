import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_crypto.dart';
import 'package:on_time_front/core/backup/backup_service.dart';
import 'package:on_time_front/core/backup/restore_staging.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/database/restore_runtime_identity.dart';
import 'package:on_time_front/core/services/app_metadata_service.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/data/repositories/schedule_repository_impl.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_start_rejected.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/repositories/timed_preparation_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/noop_alarm_cleanup.dart';
import '../../helpers/restore_staging_fixture.dart';
import '../../helpers/sodium_test_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const password = 'portable backup password';
  late AppDatabase db;
  late LocalDataOperationGate gate;
  late RestoreRuntimeIdentity identity;
  late BackupService service;
  late Directory directory;
  Future<void> Function() platform = () async {};
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'early_start_session_same': 'old',
      'preparation_with_time_orphan': 'old',
      'unrelated': 'keep',
    });
    directory = await Directory.systemTemp.createTemp(
      'ontime-restore-protocol-',
    );
    db = AppDatabase.forTesting(
      NativeDatabase(File('${directory.path}/live.sqlite')),
    );
    gate = LocalDataOperationGate();
    identity = RestoreRuntimeIdentity();
    platform = () async {};
    service = BackupService(
      db,
      _Metadata(),
      NoopAlarmCleanup(),
      crypto: BackupCrypto(sodiumLoader: loadSodiumForTest),
      operationGate: gate,
      ingestionFactory: memoryBackupIngestion,
      processingOwner: testBackupProcessingOwner(),
      stagingFactory: memoryRestoreStaging,
      runtimeIdentity: identity,
      cleanupPlatform: () => platform(),
    );
    await db.userDao.putUser(
      const UserEntity(
        id: 'local-profile',
        spareTime: Duration.zero,
        note: 'original',
      ),
    );
    await db.scheduleDao.createSchedule(
      ScheduleEntity(
        id: 'same',
        place: const PlaceEntity(id: 'place', placeName: 'Private'),
        scheduleName: 'Private',
        scheduleTime: DateTime.utc(2030, 1, 1, 10),
        occurrenceOffsetSeconds: 0,
        moveTime: Duration.zero,
        isChanged: false,
        isStarted: true,
        scheduleSpareTime: Duration.zero,
        scheduleNote: '',
        startedAt: DateTime.utc(2029, 12, 31),
        preparationFrozen: true,
      ).toScheduleWithPlaceRow(),
    );
    await db.preparationScheduleDao.createPreparationSchedule(
      const PreparationEntity(
        preparationStepList: [
          PreparationStepEntity(
            id: 'step',
            preparationName: 'Frozen',
            preparationTime: Duration(minutes: 5),
          ),
        ],
      ),
      'same',
    );
  });
  tearDown(() async {
    await db.close();
    await directory.delete(recursive: true);
    gate.dispose();
  });
  Future<BackupRestoreCandidate> preview() async =>
      service.previewEncryptedBackup(
        await service.createEncryptedBackup(password),
        password,
      );

  test(
    'same-ID restore rotates identity, removes orphan runtime and keeps frozen durable data',
    () async {
      final before = await db.select(db.users).getSingle();
      final candidate = await preview();
      await service.applyRestore(candidate);
      final user = await db.select(db.users).getSingle();
      expect(user.storeIncarnation, isNot(before.storeIncarnation));
      expect(user.rejectLegacyDelivery, isTrue);
      expect(user.restoreCleanupPending, isFalse);
      expect(identity.accepts(null), isFalse);
      expect(identity.accepts(before.storeIncarnation), isFalse);
      expect(identity.accepts(user.storeIncarnation), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), {'unrelated'});
      final row = (await db.scheduleDao.getScheduleById('same')).schedule;
      expect(row.startedAt, DateTime.utc(2029, 12, 31).toLocal());
      expect(row.preparationFrozen, isTrue);
      expect(row.isStarted, isFalse);
      expect(row.requiresStartConfirmation, isTrue);
      expect(
        (await db.preparationScheduleDao.getPreparationSchedulesByScheduleId(
          'same',
        )).preparationStepList.single.preparationName,
        'Frozen',
      );
      expect(gate.isAvailable, isTrue);
    },
  );

  test(
    'insert failure rolls back original rows and preserves original runtime',
    () async {
      final candidate = await preview();
      final before = await db.select(db.users).getSingle();
      await db.customStatement(
        "CREATE TRIGGER fail_restore BEFORE INSERT ON schedules BEGIN SELECT RAISE(ABORT,'injected'); END",
      );
      await expectLater(
        service.applyRestore(candidate),
        throwsA(isA<DataOperationException>()),
      );
      final after = await db.select(db.users).getSingle();
      expect(after, before);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'early_start_session_same',
        ),
        'old',
      );
      expect(
        (await db.scheduleDao.getScheduleById('same')).schedule.isStarted,
        isTrue,
      );
      await candidate.dispose();
    },
  );

  test(
    'commit followed by cleanup failure survives file DB reopen and retries cleanup only',
    () async {
      platform = () async => throw StateError('platform unconfirmed');
      final candidate = await preview();
      await service.applyRestore(candidate);
      final committed = await db.select(db.users).getSingle();
      expect(committed.restoreCleanupPending, isTrue);
      expect(gate.isRecoveryPending, isTrue);
      expect(identity.accepts(committed.storeIncarnation), isFalse);
      await candidate.dispose();
      await db.close();
      db = AppDatabase.forTesting(
        NativeDatabase(File('${directory.path}/live.sqlite')),
      );
      final cold = RestoreRuntimeIdentity();
      final coldGate = LocalDataOperationGate();
      addTearDown(coldGate.dispose);
      var nativeCalls = 0;
      await expectLater(
        cold.cleanup(
          db,
          coldGate,
          cleanupPlatform: () async {
            nativeCalls++;
            throw StateError('still unknown');
          },
        ),
        throwsStateError,
      );
      expect(
        (await db.select(db.users).getSingle()).restoreCleanupPending,
        isTrue,
      );
      await cold.cleanup(
        db,
        coldGate,
        cleanupPlatform: () async {
          nativeCalls++;
        },
      );
      final after = await db.select(db.users).getSingle();
      expect(after.storeIncarnation, committed.storeIncarnation);
      expect(after.dataRevision, committed.dataRevision);
      expect(after.restoreCleanupPending, isFalse);
      expect(nativeCalls, 2);
      expect(cold.accepts(null), isFalse);
      expect(
        (await db.scheduleDao.getScheduleById(
          'same',
        )).schedule.requiresStartConfirmation,
        isTrue,
      );
    },
  );

  test(
    'restored confirmation survives legacy whole-row edit; only explicit start clears it',
    () async {
      await service.applyRestore(await preview());
      final original = (await db.scheduleDao.getScheduleById('same')).schedule;
      await db.scheduleDao.updateSchedule(
        original.copyWith(
          requiresStartConfirmation: false,
          scheduleName: 'edited',
        ),
      );
      expect(
        (await db.scheduleDao.getScheduleById(
          'same',
        )).schedule.requiresStartConfirmation,
        isTrue,
      );
      final repository = ScheduleRepositoryImpl(
        database: db,
        timedPreparationRepository: _Timed(),
      );
      addTearDown(repository.dispose);
      await expectLater(
        repository.startSchedule('same'),
        throwsA(isA<ScheduleStartRejected>()),
      );
      final revision = (await db.select(db.users).getSingle()).dataRevision;
      final first = await repository.startSchedule(
        'same',
        startedAt: DateTime.utc(2030, 1, 1, 9, 58),
      );
      expect(first, original.startedAt!.toUtc());
      expect(
        (await db.scheduleDao.getScheduleById(
          'same',
        )).schedule.requiresStartConfirmation,
        isFalse,
      );
      expect(
        (await db.select(db.users).getSingle()).dataRevision,
        revision + 1,
      );
    },
  );

  test(
    'staging materialization failure cannot mutate live rows or runtime',
    () async {
      var released = false;
      final failing = BackupService(
        db,
        _Metadata(),
        NoopAlarmCleanup(),
        crypto: BackupCrypto(sodiumLoader: loadSodiumForTest),
        operationGate: gate,
        runtimeIdentity: identity,
        cleanupPlatform: () => platform(),
        ingestionFactory: memoryBackupIngestion,
        processingOwner: testBackupProcessingOwner(),
        stagingFactory: () async {
          final stage = AppDatabase.forTesting(NativeDatabase.memory());
          await stage.customSelect('SELECT 1').get();
          await stage.customStatement(
            "CREATE TRIGGER fail_stage BEFORE INSERT ON schedules BEGIN SELECT RAISE(ABORT,'injected'); END",
          );
          return RestoreStaging(stage, () async {
            await stage.close();
            released = true;
          });
        },
      );
      final before = await db.select(db.users).getSingle();
      await expectLater(
        failing.previewEncryptedBackup(
          await service.createEncryptedBackup(password),
          password,
        ),
        throwsA(anything),
      );
      expect(released, isTrue);
      expect(await db.select(db.users).getSingle(), before);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'early_start_session_same',
        ),
        'old',
      );
    },
  );

  test(
    'write crossing replacement generation rolls back while export allows ordinary edits',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      final write = db.writeTransaction(() async {
        await db.customStatement("UPDATE users SET note='must rollback'");
        started.complete();
        await release.future;
      }, gate: gate);
      final failure = expectLater(write, throwsA(isA<LocalDataUnavailable>()));
      await started.future;
      await gate.run(() async {}, replacesData: true);
      release.complete();
      await failure;
      expect((await db.select(db.users).getSingle()).note, 'original');
      await gate.run(() async {
        await db.writeTransaction(
          () => db.customStatement("UPDATE users SET note='ordinary edit'"),
          gate: gate,
        );
      });
      expect((await db.select(db.users).getSingle()).note, 'ordinary edit');
    },
  );
  Future<Map<String, dynamic>> backupJson() async =>
      jsonDecode(
            utf8.decode(
              await BackupCrypto(sodiumLoader: loadSodiumForTest).decrypt(
                container: await service.createEncryptedBackup(password),
                password: password,
              ),
            ),
          )
          as Map<String, dynamic>;
  Future<BackupRestoreCandidate> previewJson(
    Map<String, dynamic> value,
  ) async => service.previewEncryptedBackup(
    await BackupCrypto(sodiumLoader: loadSodiumForTest).encrypt(
      plaintext: Uint8List.fromList(utf8.encode(jsonEncode(value))),
      password: password,
    ),
    password,
  );

  test(
    'new durable fields reject malformed types and explicit freeze without first start before mutation',
    () async {
      final original = await backupJson();
      final before = await db.select(db.users).getSingle();
      for (final overrides in [
        {'startedAt': 123},
        {'startedAt': 'not-an-instant'},
        {'preparationFrozen': 'true'},
        {'startedAt': null, 'preparationFrozen': true},
      ]) {
        final data = jsonDecode(jsonEncode(original)) as Map<String, dynamic>;
        ((data['schedules'] as List).single as Map).addAll(overrides);
        await expectLater(previewJson(data), throwsFormatException);
        expect(await db.select(db.users).getSingle(), before);
        expect(
          (await SharedPreferences.getInstance()).getString(
            'early_start_session_same',
          ),
          'old',
        );
      }
    },
  );
  test(
    'wall-clock reversal preserves historical completion without creating a new outcome',
    () async {
      final data = await backupJson();
      final row = (data['schedules'] as List).single as Map;
      row['finishedAt'] = '2029-12-30T00:00:00.000Z';
      row['doneStatus'] = 'normalEnd';
      row['scoreContributionRecorded'] = true;
      (data['profile'] as Map)['eligibleOutcomeCount'] = 1;
      (data['profile'] as Map)['onTimeOutcomeCount'] = 1;
      await service.applyRestore(await previewJson(data));
      final restored = await db.select(db.schedules).getSingle();
      final profile = await db.select(db.users).getSingle();
      expect(restored.finishedAt!.isBefore(restored.startedAt!), isTrue);
      expect(restored.isStarted, isFalse);
      expect(restored.requiresStartConfirmation, isFalse);
      expect(restored.scoreContributionRecorded, isTrue);
      expect(profile.eligibleOutcomeCount, 1);
      expect(profile.onTimeOutcomeCount, 1);
    },
  );

  test(
    'new first-start instant exports UTC and offset-equivalent import preserves epoch without changing civil time',
    () async {
      final data = await backupJson();
      final row = (data['schedules'] as List).single as Map;
      final civil = row['civilTime'];
      expect(row['startedAt'], '2029-12-31T00:00:00.000Z');
      row['startedAt'] = '2029-12-31T09:00:00.000+09:00';
      await service.applyRestore(await previewJson(data));
      expect(
        (await db.select(db.schedules).getSingle())
            .startedAt!
            .millisecondsSinceEpoch,
        DateTime.utc(2029, 12, 31).millisecondsSinceEpoch,
      );
      final exported = (await backupJson())['schedules'] as List;
      expect(exported.single['startedAt'], '2029-12-31T00:00:00.000Z');
      expect(exported.single['civilTime'], civil);
    },
  );
  for (final version in [1, 2]) {
    test(
      'old format $version missing durable start fields keeps historical defaults',
      () async {
        final data = await backupJson();
        data['formatVersion'] = version;
        final row = (data['schedules'] as List).single as Map;
        row.remove('startedAt');
        row.remove('preparationFrozen');
        await service.applyRestore(await previewJson(data));
        final restored = (await db.select(db.schedules).getSingle());
        expect(restored.startedAt, isNull);
        expect(restored.preparationFrozen, isFalse);
        expect(restored.isStarted, isFalse);
      },
    );
  }
  test(
    'future backup version is rejected before any live or runtime mutation',
    () async {
      final data = await backupJson();
      data['formatVersion'] = 99;
      final before = await db.select(db.users).getSingle();
      await expectLater(previewJson(data), throwsFormatException);
      expect(await db.select(db.users).getSingle(), before);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'early_start_session_same',
        ),
        'old',
      );
    },
  );
  test(
    'template original creation and last edit instants survive encrypted portable roundtrip',
    () async {
      final created = DateTime.utc(2028, 1, 2, 3),
          updated = DateTime.utc(2029, 4, 5, 6);
      await db.preparationTemplateDao.put(
        id: 'template',
        name: 'Original',
        preparation: const PreparationEntity(preparationStepList: []),
        now: created,
      );
      await db.preparationTemplateDao.put(
        id: 'template',
        name: 'Edited',
        preparation: const PreparationEntity(preparationStepList: []),
        now: updated,
      );
      final data = await backupJson();
      expect(
        (data['templates'] as List).single['createdAt'],
        created.toIso8601String(),
      );
      await service.applyRestore(await previewJson(data));
      final template = await db.preparationTemplateDao.getById('template');
      expect(template.createdAt.toUtc(), created);
      expect(template.updatedAt.toUtc(), updated);
      expect(template.name, 'Edited');
      (data['templates'] as List).single['updatedAt'] =
          '2029-04-05T06:00:00.001Z';
      await expectLater(previewJson(data), throwsFormatException);
    },
  );
  test(
    'cancel releases candidate without changing live profile or old runtime',
    () async {
      final before = await db.select(db.users).getSingle();
      final candidate = await preview();
      await candidate.dispose();
      await candidate.dispose();
      expect(await db.select(db.users).getSingle(), before);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'early_start_session_same',
        ),
        'old',
      );
      await expectLater(
        service.applyRestore(candidate),
        throwsA(isA<DataOperationException>()),
      );
    },
  );
  test(
    'committed staging release failure keeps durable marker and cleanup retry cannot reapply',
    () async {
      var fail = true, releases = 0;
      final custom = BackupService(
        db,
        _Metadata(),
        NoopAlarmCleanup(),
        crypto: BackupCrypto(sodiumLoader: loadSodiumForTest),
        operationGate: gate,
        runtimeIdentity: identity,
        cleanupPlatform: () => platform(),
        ingestionFactory: memoryBackupIngestion,
        processingOwner: testBackupProcessingOwner(),
        stagingFactory: () async {
          final stage = AppDatabase.forTesting(NativeDatabase.memory());
          return RestoreStaging(stage, () async {
            releases++;
            if (fail) throw StateError('unlink fault');
            await stage.close();
          });
        },
      );
      final candidate = await custom.previewEncryptedBackup(
        await service.createEncryptedBackup(password),
        password,
      );
      await custom.applyRestore(candidate);
      final committed = await db.select(db.users).getSingle();
      expect(committed.restoreCleanupPending, isTrue);
      expect(gate.isRecoveryPending, isTrue);
      await expectLater(
        candidate.dispose(),
        throwsA(isA<RestoreStagingCleanupFailure>()),
      );
      fail = false;
      await custom.finishRestoreCleanup();
      final clean = await db.select(db.users).getSingle();
      expect(clean.storeIncarnation, committed.storeIncarnation);
      expect(clean.dataRevision, committed.dataRevision);
      expect(clean.restoreCleanupPending, isFalse);
      await expectLater(
        custom.applyRestore(candidate),
        throwsA(isA<DataOperationException>()),
      );
      expect(releases, 3);
    },
  );
  test(
    'marker commit failure stays pending and retry preserves committed identity',
    () async {
      final candidate = await preview();
      await db.customStatement(
        "CREATE TRIGGER fail_marker BEFORE UPDATE OF restore_cleanup_pending ON users WHEN NEW.restore_cleanup_pending=0 BEGIN SELECT RAISE(ABORT,'marker fault'); END",
      );
      await service.applyRestore(candidate);
      final committed = await db.select(db.users).getSingle();
      expect(committed.restoreCleanupPending, isTrue);
      expect(gate.isRecoveryPending, isTrue);
      await db.customStatement('DROP TRIGGER fail_marker');
      await service.finishRestoreCleanup();
      final clean = await db.select(db.users).getSingle();
      expect(clean.storeIncarnation, committed.storeIncarnation);
      expect(clean.dataRevision, committed.dataRevision);
      expect(clean.restoreCleanupPending, isFalse);
    },
  );
}

class _Metadata implements AppMetadataProvider {
  @override
  Future<AppMetadata> getMetadata() async =>
      const AppMetadata(version: '1', buildNumber: '1');
}

class _Timed implements TimedPreparationRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<void> clearTimedPreparation(String scheduleId) async {}
}
