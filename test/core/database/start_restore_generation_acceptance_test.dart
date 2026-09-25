// T03 F03/F10/F21 selected start-to-restore generation boundary.
// Actual: file-backed SQLite + independent read-only sqlite3 readers;
// ScheduleRepositoryImpl and SchedulePreparationSessionUseCase;
// both runtime repositories/data sources and their real JSON/prefs protocol;
// BackupService + sodium crypto + restore transaction/runtime cleanup;
// same shared generation gate and operation owner; FileAlarmJournalStore.
// Controlled boundaries: in-memory SharedPreferences PLATFORM store (not native
// disk durability), one false marker-write receipt, one bounded marker latch,
// existing fake OS/registry, no-op reconcile, memory ingestion/staging.
// No process-kill, power-loss, encrypted active SQLite or mobile proof claimed.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:on_time_front/core/backup/backup_crypto.dart';
import 'package:on_time_front/core/backup/backup_service.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/database/restore_runtime_identity.dart';
import 'package:on_time_front/core/services/alarm_journal_store.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/core/services/alarm_ownership_journal.dart';
import 'package:on_time_front/core/services/app_metadata_service.dart';
import 'package:on_time_front/core/time/schedule_time_resolution.dart';
import 'package:on_time_front/data/data_sources/early_start_session_local_data_source.dart';
import 'package:on_time_front/data/data_sources/preparation_with_time_local_data_source.dart';
import 'package:on_time_front/data/repositories/early_start_session_repository_impl.dart';
import 'package:on_time_front/data/repositories/schedule_repository_impl.dart';
import 'package:on_time_front/data/repositories/timed_preparation_repository_impl.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';
import 'package:on_time_front/domain/use-cases/cancel_all_alarms_use_case.dart';
import 'package:on_time_front/domain/use-cases/cancel_schedule_alarm_use_case.dart';
import 'package:on_time_front/domain/use-cases/schedule_preparation_session_use_case.dart';

import '../../helpers/noop_alarm_reconciliation.dart';
import '../../helpers/restore_staging_fixture.dart';
import '../../helpers/sodium_test_loader.dart';
import '../../domain/use-cases/reconcile_alarms_use_case_test.dart'
    show
        FakeAlarmRegistryRepository,
        FakeAlarmSchedulerService,
        FakeFallbackAlarmNotificationService;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'T03 actual start commit partial runtime retry cannot resurrect same-ID restored run',
    () async {
      const password = 't03 synthetic portable password';
      const id = 'same';
      const markerKey = 'flutter.early_start_session_same';
      const snapshotKey = 'flutter.preparation_with_time_same';
      final now = DateTime.utc(2030, 1, 1, 8);
      final startedAt = now.add(const Duration(minutes: 1));
      final directory = await Directory.systemTemp.createTemp(
        't03-start-restore-',
      );
      final databaseFile = File('${directory.path}/active.sqlite');
      final db = AppDatabase.forTesting(NativeDatabase(databaseFile));
      // Production ScheduleRepositoryImpl observes/writes this gate, so use it
      // consistently for owner, BackupService and the retained UI intent.
      final gate = LocalDataOperationGate.shared;
      final oldGeneration = gate.generation;
      final identity = RestoreRuntimeIdentity.shared;
      final priorIdentity = (
        identity.storeIncarnation,
        identity.rejectLegacy,
        identity.pending,
      );
      SharedPreferences.setMockInitialValues({});
      final platform = _RuntimeStore(markerKey);
      SharedPreferencesStorePlatform.instance = platform;
      final journal = AlarmOwnershipJournal(
        FileAlarmJournalStore(
          () async => Directory('${directory.path}/journal'),
        ),
      );
      final owner = AlarmOperationCoordinator(gate, journal: journal);
      final registry = FakeAlarmRegistryRepository();
      final native = FakeAlarmSchedulerService();
      final fallback = FakeFallbackAlarmNotificationService();
      final cancelOne = CancelScheduleAlarmUseCase(
        registry,
        native,
        fallback,
        operations: owner,
      );
      final cancelAll = CancelAllAlarmsUseCase(
        registry,
        native,
        fallback,
        operations: owner,
      );
      final timed = TimedPreparationRepositoryImpl(
        localDataSource: PreparationWithTimeLocalDataSourceImpl(),
      );
      final early = EarlyStartSessionRepositoryImpl(
        localDataSource: EarlyStartSessionLocalDataSourceImpl(),
      );
      final schedules = ScheduleRepositoryImpl(
        database: db,
        timedPreparationRepository: timed,
        now: () => now,
      );
      final reconcile = NoopAlarmReconciliation();
      final sessions = SchedulePreparationSessionUseCase(
        schedules,
        _UnusedPreparation(),
        timed,
        early,
        cancelOne,
        reconcile,
        operations: owner,
      );
      final backup = BackupService(
        db,
        _Metadata(),
        cancelAll,
        crypto: BackupCrypto(sodiumLoader: loadSodiumForTest),
        operationGate: gate,
        ingestionFactory: memoryBackupIngestion,
        processingOwner: testBackupProcessingOwner(),
        stagingFactory: memoryRestoreStaging,
        runtimeIdentity: identity,
        cleanupPlatform: noPlatformRestoreCleanup,
        now: () => now,
      );
      BackupRestoreCandidate? candidate;
      Future<void>? oldRetryAssertion;
      Future<int>? restoring;
      final generationClaimed = Completer<void>();
      void changed() {
        if (gate.generation != oldGeneration &&
            !generationClaimed.isCompleted) {
          generationClaimed.complete();
        }
      }

      gate.addListener(changed);
      try {
        await db.userDao.putUser(
          const UserEntity(
            id: 'local-profile',
            spareTime: Duration.zero,
            note: 'synthetic profile sentinel',
            isOnboardingCompleted: true,
          ),
        );
        await identity.load(db);
        final oldIncarnation = identity.storeIncarnation;
        await schedules.createSchedule(
          ScheduleEntity(
            id: id,
            place: const PlaceEntity(
              id: 'place-same',
              placeName: 'private-place-sentinel',
            ),
            scheduleName: 'private-title-sentinel',
            scheduleTime: DateTime.utc(2030, 1, 1, 12),
            timeZoneId: 'UTC',
            occurrenceOffsetSeconds: 0,
            moveTime: Duration.zero,
            isChanged: false,
            isStarted: false,
            scheduleSpareTime: Duration.zero,
            scheduleNote: 'private-note-sentinel',
          ),
        );
        const preparation = PreparationEntity(
          preparationStepList: [
            PreparationStepEntity(
              id: 'step-same',
              preparationName: 'private-preparation-sentinel',
              preparationTime: Duration(minutes: 5),
            ),
          ],
        );
        await db.preparationScheduleDao.createPreparationSchedule(
          preparation,
          id,
        );
        final originalSchedule = await schedules.getScheduleById(id);
        final original =
            ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
              originalSchedule,
              PreparationWithTimeEntity.fromPreparation(preparation),
              timeResolution: ScheduleTimeResolver.resolve(
                originalSchedule,
                nowUtc: now,
              ),
            );
        final beforeStart = _readLogicalSnapshot(databaseFile);
        final beforeRevision =
            beforeStart['users']!.single['data_revision'] as int;
        bool oldIntentIsCurrent() => gate.generation == oldGeneration;

        // Failure is injected at the existing platform storage boundary AFTER
        // the real durable start commit. Snapshot serialization remains real.
        platform.failNextMarker = true;
        final receipt = await sessions.startEarlySession(
          original,
          startedAt: startedAt,
          isCurrent: oldIntentIsCurrent,
        );
        expect(receipt.hasPendingRecovery, isTrue);
        expect(receipt.startedAt.toUtc(), startedAt);
        expect(receipt.durableStartedAt?.toUtc(), startedAt);
        final committed = _readLogicalSnapshot(databaseFile);
        expect(committed['users']!.single['data_revision'], beforeRevision + 1);
        expect(committed['schedules']!.single['is_started'], 1);
        expect(committed['schedules']!.single['preparation_frozen'], 1);
        final firstStoredInstant = committed['schedules']!.single['started_at'];
        expect(firstStoredInstant, isNotNull);
        final rawRuntime = await platform.getAll();
        expect(rawRuntime.containsKey(markerKey), isFalse);
        expect(rawRuntime[snapshotKey], isA<String>());
        final snapshotPayload = rawRuntime[snapshotKey] as String;
        for (final sentinel in [
          'private-title-sentinel',
          'private-place-sentinel',
          'private-note-sentinel',
          'private-preparation-sentinel',
        ]) {
          expect(snapshotPayload, isNot(contains(sentinel)));
        }
        // Legacy SharedPreferences updates its cache before a false platform
        // receipt. Reload so the assertion observes the actual platform store.
        await (await SharedPreferences.getInstance()).reload();
        expect(await early.getSession(id), isNull);
        expect(
          (await timed.getTimedPreparationSnapshot(id))!.startedAt!.toUtc(),
          startedAt,
        );

        // Export after the durable partial start, then restore the same ID and
        // identical timing/preparation shape. Backup excludes active runtime.
        final bytes = await backup.createEncryptedBackup(password);
        candidate = await backup.previewEncryptedBackup(bytes, password);
        final beforeRace = _readLogicalSnapshot(databaseFile);
        platform.holdNextMarker = true;
        final oldRetry = sessions.startEarlySession(
          original,
          startedAt: startedAt,
          isCurrent: oldIntentIsCurrent,
        );
        oldRetryAssertion = expectLater(
          oldRetry,
          throwsA(isA<AlarmOperationInvalidated>()),
        );
        await platform.markerEntered.future.timeout(
          const Duration(seconds: 10),
        );
        var restoreCompleted = false;
        restoring = backup.applyRestoreWithReceipt(candidate).then((value) {
          restoreCompleted = true;
          return value;
        });
        await generationClaimed.future.timeout(const Duration(seconds: 10));
        expect(gate.generation, oldGeneration + 1);
        expect(gate.isReplacingData, isTrue);
        expect(restoreCompleted, isFalse);
        // A separately opened SQL reader proves replacement has not overtaken
        // the still-owned runtime write. No timing/sleep-based success oracle.
        expect(_readLogicalSnapshot(databaseFile), beforeRace);
        expect(platform.markerRelease.isCompleted, isFalse);
        platform.markerRelease.complete();
        await oldRetryAssertion.timeout(const Duration(seconds: 10));
        expect(
          await restoring.timeout(const Duration(seconds: 10)),
          oldGeneration + 1,
        );
        expect(gate.isAvailable, isTrue);
        final restored = _readLogicalSnapshot(databaseFile);
        expect(
          restored['users']!.single['store_incarnation'],
          isNot(oldIncarnation),
        );
        expect(restored['users']!.single['restore_cleanup_pending'], 0);
        final restoredSchedule = restored['schedules']!.single;
        expect(restoredSchedule['id'], id);
        expect(restoredSchedule['is_started'], 0);
        expect(restoredSchedule['requires_start_confirmation'], 1);
        expect(restoredSchedule['started_at'], firstStoredInstant);
        expect(restoredSchedule['preparation_frozen'], 1);
        final currentSchedule = await schedules.getScheduleById(id);
        final currentPreparation = await db.preparationScheduleDao
            .getPreparationSchedulesByScheduleId(id);
        final sameContent =
            ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
              currentSchedule,
              PreparationWithTimeEntity.fromPreparation(currentPreparation),
              timeResolution: ScheduleTimeResolver.resolve(
                currentSchedule,
                nowUtc: now,
              ),
            );
        expect(sameContent.cacheFingerprint, original.cacheFingerprint);
        expect(await platform.getAll(), isEmpty);
        expect(await early.getSession(id), isNull);
        expect(await timed.getTimedPreparationSnapshot(id), isNull);

        // Re-dispatch of the OLD captured intent is distinct from a new user
        // confirmation. The production Bloc supplies this generation validity
        // callback; this test uses its public use-case contract directly.
        final runtimeWrites = platform.setAttempts;
        final reconcileCalls = reconcile.callCount;
        await expectLater(
          sessions.startEarlySession(
            original,
            startedAt: startedAt,
            isCurrent: oldIntentIsCurrent,
          ),
          throwsA(isA<AlarmOperationInvalidated>()),
        );
        expect(_readLogicalSnapshot(databaseFile), restored);
        expect(await platform.getAll(), isEmpty);
        expect(platform.setAttempts, runtimeWrites);
        expect(reconcile.callCount, reconcileCalls);
        expect(native.scheduledNative, isEmpty);
        expect(fallback.scheduledFallback, isEmpty);
      } finally {
        if (!platform.markerRelease.isCompleted) {
          platform.markerRelease.complete();
        }
        // Always settle the owned futures before disposing repositories/files.
        try {
          await oldRetryAssertion;
          await restoring;
        } finally {
          await candidate?.dispose();
          sessions.dispose();
          await schedules.dispose();
          owner.dispose();
          gate.removeListener(changed);
          await db.close();
          identity.storeIncarnation = priorIdentity.$1;
          identity.rejectLegacy = priorIdentity.$2;
          identity.pending = priorIdentity.$3;
          SharedPreferences.setMockInitialValues({});
          if (gate.isRecoveryPending) gate.setRecoveryPending(false);
          await directory.delete(recursive: true);
        }
      }
    },
  );
}

// Test-only platform adapter. Product runtime repositories/serialization are
// unchanged. This deliberately claims only a memory-backed host prefs store.
class _RuntimeStore extends InMemorySharedPreferencesStore {
  _RuntimeStore(this.markerKey) : super.empty();
  final String markerKey;
  bool failNextMarker = false;
  bool holdNextMarker = false;
  int setAttempts = 0;
  final markerEntered = Completer<void>();
  final markerRelease = Completer<void>();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    setAttempts++;
    if (key == markerKey && failNextMarker) {
      failNextMarker = false;
      return false;
    }
    if (key == markerKey && holdNextMarker) {
      holdNextMarker = false;
      markerEntered.complete();
      await markerRelease.future;
    }
    return super.setValue(valueType, key, value);
  }
}

Map<String, List<Map<String, Object?>>> _readLogicalSnapshot(File file) {
  final reader = sqlite.sqlite3.open(file.path, mode: sqlite.OpenMode.readOnly);
  try {
    final names = reader.select(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
    );
    return {
      for (final table in names)
        table['name'] as String: _readRows(reader, table['name'] as String),
    };
  } finally {
    reader.dispose();
  }
}

List<Map<String, Object?>> _readRows(sqlite.Database reader, String table) {
  final escaped = table.replaceAll('"', '""');
  final rows = reader
      .select('SELECT * FROM "$escaped"')
      .map((row) => Map<String, Object?>.from(row))
      .toList();
  rows.sort((a, b) => jsonEncode(a).compareTo(jsonEncode(b)));
  return rows;
}

class _UnusedPreparation extends Fake implements PreparationRepository {}

class _Metadata implements AppMetadataProvider {
  @override
  Future<AppMetadata> getMetadata() async =>
      const AppMetadata(version: '1', buildNumber: '1');
}
