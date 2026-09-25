import 'package:shared_preferences/shared_preferences.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';
import '../../helpers/restore_staging_fixture.dart';
import 'package:on_time_front/core/database/restore_runtime_identity.dart';
import '../../helpers/noop_alarm_cleanup.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:on_time_front/data/repositories/recurring_schedule_repository_impl.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_crypto.dart';
import 'package:on_time_front/core/backup/backup_file_export_port.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/backup/backup_service.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/services/app_metadata_service.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';

import '../../helpers/sodium_test_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const password = 'portable backup password';
  late AppDatabase database;
  late BackupService service;
  late _ExportPort exportPort;
  late LocalDataOperationGate gate;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    exportPort = _ExportPort();
    gate = LocalDataOperationGate();
    service = BackupService(
      database,
      _MetadataProvider(),
      NoopAlarmCleanup(),
      ingestionFactory: memoryBackupIngestion,
      processingOwner: testBackupProcessingOwner(),
      stagingFactory: memoryRestoreStaging,
      runtimeIdentity: RestoreRuntimeIdentity(),
      cleanupPlatform: noPlatformRestoreCleanup,
      crypto: BackupCrypto(sodiumLoader: loadSodiumForTest),
      exportPort: exportPort,
      operationGate: gate,
    );
    await database.userDao.putUser(
      const UserEntity(
        id: 'local-profile',
        spareTime: Duration(minutes: 7),
        note: 'local note',
        eligibleOutcomeCount: 4,
        onTimeOutcomeCount: 3,
        isOnboardingCompleted: true,
      ),
    );
    await database.preparationUserDao.createPreparationUser(
      const PreparationEntity(
        preparationStepList: [
          PreparationStepEntity(
            id: 'default-step',
            preparationName: 'Pack',
            preparationTime: Duration(minutes: 5),
          ),
        ],
      ),
      'local-profile',
    );
    await database.scheduleDao.createSchedule(
      _schedule().toScheduleWithPlaceRow(),
    );
  });

  tearDown(() => database.close());

  test(
    'saved receipt marks only the captured revision despite an ordinary edit',
    () async {
      await database.userDao.updateAlarmSettings(
        userId: 'local-profile',
        enabled: false,
      );
      final initial =
          (await database.select(database.users).getSingle()).dataRevision;
      final pending = service.exportToUserSelectedFile(password);
      await exportPort.opened.future;
      final decoded =
          jsonDecode(
                utf8.decode(
                  await BackupCrypto(
                    sodiumLoader: loadSodiumForTest,
                  ).decrypt(container: exportPort.bytes!, password: password),
                ),
              )
              as Map;
      expect((decoded['schedules'] as List).length, 1);
      expect(exportPort.name, endsWith('.ontimebackup'));
      await database.userDao.updateSpareTime(
        'local-profile',
        const Duration(minutes: 11),
      );
      exportPort.completion.complete(BackupFileExportReceipt.saved);
      expect(await pending, BackupExportResult.saved);
      final row = await database.select(database.users).getSingle();
      expect(row.lastExportedRevision, initial);
      expect(row.dataRevision, initial + 1);
      expect(row.spareTime, 11);
      expect(row.alarmsEnabled, false);
      expect(
        (await service.getFreshness()).freshness,
        BackupFreshness.unexportedChanges,
      );
    },
  );

  test('cancel preserves freshness and releases gate for a retry', () async {
    final pending = service.exportToUserSelectedFile(password);
    await exportPort.opened.future;
    exportPort.completion.complete(BackupFileExportReceipt.cancelled);
    expect(await pending, BackupExportResult.cancelled);
    expect(
      (await service.getFreshness()).freshness,
      BackupFreshness.neverExported,
    );
    await gate.run(() async {});
  });

  test(
    'write failure cannot mark success or expose provider error details',
    () async {
      final pending = service.exportToUserSelectedFile(password);
      final failure = expectLater(
        pending,
        throwsA(isA<BackupFileExportFailure>()),
      );
      await exportPort.opened.future;
      exportPort.completion.completeError(
        StateError('/private/document/sensitive'),
      );
      await failure;
      expect(
        (await service.getFreshness()).freshness,
        BackupFreshness.neverExported,
      );
      await gate.run(() async {});
    },
  );

  test(
    'backup resource lease rejects another backup while ordinary DB writes continue',
    () async {
      final bytes = await service.createEncryptedBackup(password);
      final pending = service.exportToUserSelectedFile(password);
      await exportPort.opened.future;
      await expectLater(
        service.exportToUserSelectedFile(password),
        throwsA(isA<DataOperationException>()),
      );
      await expectLater(
        service.previewEncryptedBackup(bytes, password),
        throwsA(isA<DataOperationException>()),
      );
      await gate.run(() async {
        await database.userDao.updateSpareTime(
          'local-profile',
          const Duration(minutes: 12),
        );
      });
      expect(exportPort.calls, 1);
      exportPort.completion.complete(BackupFileExportReceipt.cancelled);
      await pending;
      final candidate = await service.previewEncryptedBackup(bytes, password);
      await expectLater(
        service.createEncryptedBackup(password),
        throwsA(isA<DataOperationException>()),
      );
      await candidate.dispose();
    },
  );

  test(
    'successful external save with missing profile reports metadata failure',
    () async {
      final pending = service.exportToUserSelectedFile(password);
      await exportPort.opened.future;
      await database.deleteAllDurableData();
      exportPort.completion.complete(BackupFileExportReceipt.saved);
      expect(await pending, BackupExportResult.savedFreshnessUpdateFailed);
      expect(exportPort.calls, 1);
    },
  );

  test(
    'late success cannot write freshness after lifecycle invalidation',
    () async {
      final pending = service.exportToUserSelectedFile(password);
      await exportPort.opened.future;
      gate.invalidate();
      exportPort.completion.complete(BackupFileExportReceipt.saved);
      expect(await pending, BackupExportResult.savedFreshnessUpdateFailed);
      expect(
        (await database.select(database.users).getSingle())
            .lastExportedRevision,
        isNull,
      );
    },
  );

  test('crypto failure releases gate without opening a destination', () async {
    await expectLater(
      service.exportToUserSelectedFile('short'),
      throwsFormatException,
    );
    expect(exportPort.calls, 0);
    await gate.run(() async {});
  });

  test(
    'preview authenticates backup and restore replaces active data',
    () async {
      final encrypted = await service.createEncryptedBackup(password);

      await database.deleteAllDurableData();
      await database.userDao.putUser(
        const UserEntity(
          id: 'local-profile',
          spareTime: Duration.zero,
          note: 'replacement data',
        ),
      );

      final candidate = await service.previewEncryptedBackup(
        encrypted,
        password,
      );
      expect(candidate.preview.scheduleCount, 1);
      expect(candidate.preview.defaultPreparationStepCount, 1);

      await service.applyRestore(candidate);

      final restoredUser = (await database.userDao.getUserById(
        'local-profile',
      ))!;
      final restoredSchedules = await database.scheduleDao.getScheduleList();
      expect(restoredUser.note, 'local note');
      expect(restoredUser.scoreOrNull, 75);
      expect(restoredSchedules.single.schedule.id, 'schedule-1');
    },
  );

  test(
    'format 2 restores owned preparation and exclusions without regenerating deleted slots',
    () async {
      final recurring = RecurringScheduleRepositoryImpl(
        database,
        now: () => DateTime.utc(2030, 1, 1),
      );
      final schedule = _schedule().copyWith(
        id: 'series',
        scheduleTime: DateTime.utc(2030, 1, 2, 10),
        timeZoneId: 'UTC',
        occurrenceOffsetSeconds: 0,
      );
      final preparation = await database.preparationUserDao
          .getPreparationUsersByUserId('local-profile');
      final rule = RecurrenceRule(
        frequency: RecurrenceFrequency.daily,
        start: schedule.scheduleTime,
        timeZoneId: 'UTC',
        count: 3,
      );
      await recurring.create(schedule, preparation, rule);
      final generated = (await database.scheduleDao.getScheduleList())
          .map((r) => r.toScheduleEntity())
          .where((s) => s.isRecurring)
          .toList();
      final frozen = generated.first;
      final frozenAt = DateTime.utc(2030, 1, 1, 23);
      final ownedBefore = await recurring.getPreparation(
        frozen.preparationDefinitionId!,
      );
      await database.customStatement(
        'UPDATE schedules SET started_at=?, preparation_frozen=1, is_started=1 WHERE id=?',
        [frozenAt.millisecondsSinceEpoch ~/ 1000, frozen.id],
      );
      final deleted = generated[1];
      await recurring.delete(deleted, RecurringEditScope.occurrence);
      final oldStore =
          (await database.select(database.users).getSingle()).storeIncarnation;
      final oldSegments = await database
          .select(database.recurringScheduleSegments)
          .get();
      final encrypted = await service.createEncryptedBackup(password);
      final plaintext = utf8.decode(
        await BackupCrypto(
          sodiumLoader: loadSodiumForTest,
        ).decrypt(container: encrypted, password: password),
      );
      for (final internal in [
        'storeIncarnation',
        'aggregateIncarnation',
        'aggregateVersion',
        'lastMutationId',
        'lastMutationDigest',
        'lastMutationVersion',
        'rootSegmentId',
      ]) {
        expect(plaintext, isNot(contains(internal)));
      }
      final candidate = await service.previewEncryptedBackup(
        encrypted,
        password,
      );
      await service.applyRestore(candidate);
      expect(
        (await database.select(database.users).getSingle()).storeIncarnation,
        isNot(oldStore),
      );
      final newSegments = await database
          .select(database.recurringScheduleSegments)
          .get();
      expect(
        newSegments.first.aggregateIncarnation,
        isNot(oldSegments.first.aggregateIncarnation),
      );
      expect(newSegments.first.lastMutationId, isNull);
      await recurring.materialize(DateTime.utc(2030), DateTime.utc(2031));
      final restored = (await database.scheduleDao.getScheduleList())
          .map((r) => r.toScheduleEntity())
          .where((s) => s.isRecurring)
          .toList();
      expect(restored, hasLength(2));
      expect(restored.any((s) => s.id == deleted.id), isFalse);
      final frozenAfter = restored.singleWhere((s) => s.id == frozen.id);
      expect(frozenAfter.startedAt!.toUtc(), frozenAt);
      expect(frozenAfter.preparationFrozen, isTrue);
      expect(frozenAfter.isStarted, isFalse);
      expect(frozenAfter.requiresStartConfirmation, isTrue);
      expect(
        await recurring.getPreparation(frozenAfter.preparationDefinitionId!),
        ownedBefore,
      );

      expect(
        (await recurring.getPreparation(
          restored.first.preparationDefinitionId!,
        )).preparationStepList.single.preparationName,
        'Pack',
      );
    },
  );

  test(
    'format 1 remains importable and malformed new references never replace data',
    () async {
      final crypto = BackupCrypto(sodiumLoader: loadSodiumForTest);
      final encrypted = await service.createEncryptedBackup(password);
      final json =
          jsonDecode(
                utf8.decode(
                  await crypto.decrypt(
                    container: encrypted,
                    password: password,
                  ),
                ),
              )
              as Map<String, dynamic>;
      json['formatVersion'] = 1;
      json.remove('recurring');
      for (final value in json['schedules'] as List) {
        for (final key in [
          'recurringSegmentId',
          'recurringSlotKey',
          'recurringOrdinal',
          'recurringOverrides',
          'preparationDefinitionId',
        ]) {
          (value as Map).remove(key);
        }
      }
      Future<Uint8List> encoded() => crypto.encrypt(
        plaintext: Uint8List.fromList(utf8.encode(jsonEncode(json))),
        password: password,
      );
      final old = await service.previewEncryptedBackup(
        await encoded(),
        password,
      );
      await service.applyRestore(old);
      expect(
        (await database.scheduleDao.getScheduleList()).single.schedule.id,
        'schedule-1',
      );
      json['formatVersion'] = 2;
      json['recurring'] = {
        'definitions': [],
        'steps': [],
        'segments': [],
        'exclusions': [],
      };
      (json['schedules'] as List).first['preparationDefinitionId'] = 'unknown';
      await expectLater(
        service.previewEncryptedBackup(await encoded(), password),
        throwsFormatException,
      );
      expect(
        (await database.scheduleDao.getScheduleList()).single.schedule.id,
        'schedule-1',
      );
    },
  );

  test('wrong password leaves current database unchanged', () async {
    final encrypted = await service.createEncryptedBackup(password);
    await (database.update(database.users)
          ..where((row) => row.id.equals('local-profile')))
        .write(const UsersCompanion(note: Value('must survive')));

    await expectLater(
      service.previewEncryptedBackup(encrypted, 'wrong backup password'),
      throwsFormatException,
    );

    expect(
      (await database.userDao.getUserById('local-profile'))!.note,
      'must survive',
    );
  });
}

ScheduleEntity _schedule() => ScheduleEntity(
  id: 'schedule-1',
  place: const PlaceEntity(id: 'place-1', placeName: 'Office'),
  scheduleName: 'Meeting',
  timeZoneId: 'Asia/Seoul',
  occurrenceOffsetSeconds: 9 * 60 * 60,
  scheduleTime: DateTime(2026, 9, 2, 10),
  moveTime: const Duration(minutes: 20),
  isChanged: false,
  isStarted: false,
  scheduleSpareTime: const Duration(minutes: 5),
  scheduleNote: '',
);

class _MetadataProvider implements AppMetadataProvider {
  @override
  Future<AppMetadata> getMetadata() async =>
      const AppMetadata(version: '1.0.1', buildNumber: '1');
}

class _ExportPort implements BackupFileExportPort {
  final opened = Completer<void>();
  final completion = Completer<BackupFileExportReceipt>();
  Uint8List? bytes;
  String? name;
  int calls = 0;

  @override
  Future<BackupFileExportReceipt> exportStream({
    required Stream<List<int>> encrypted,
    required String suggestedName,
    BackupProcessingLease? lease,
  }) async {
    calls++;
    final output = BytesBuilder(copy: false);
    await for (final chunk in encrypted) {
      output.add(chunk);
    }
    bytes = output.takeBytes();
    name = suggestedName;
    opened.complete();
    return completion.future;
  }
}
