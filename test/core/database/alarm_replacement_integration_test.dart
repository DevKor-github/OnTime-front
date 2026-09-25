import 'package:on_time_front/core/database/local_reset_actions.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_crypto.dart';
import 'package:on_time_front/core/backup/backup_service.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/installation_key_store.dart';
import 'package:on_time_front/core/database/local_data_reset_service.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/core/services/app_metadata_service.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/use-cases/alarm_reconciliation_concurrency_test.dart'
    as concurrency;
import '../../helpers/sodium_test_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'sentinel': 'keep'});
    FlutterSecureStorage.setMockInitialValues({'key-sentinel': 'keep'});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.userDao.putUser(
      const UserEntity(
        id: 'local-profile',
        spareTime: Duration.zero,
        note: 'backup value',
      ),
    );
    await database.preparationUserDao.createPreparationUser(
      const PreparationEntity(preparationStepList: []),
      'local-profile',
    );
  });
  tearDown(() => database.close());

  BackupService backup(concurrency.Rig r) => BackupService(
    database,
    _Metadata(),
    r.cancelAll,
    operationGate: r.gate,
    crypto: BackupCrypto(sodiumLoader: loadSodiumForTest),
  );
  Future<BackupRestoreCandidate> candidate(BackupService service) async =>
      service.previewEncryptedBackup(
        await service.createEncryptedBackup('replacement fixture password'),
        'replacement fixture password',
      );

  test(
    'actual restore waits for late platform completion before replacing database',
    () async {
      final native = concurrency.BlockingNative();
      final r = concurrency.Rig(native: native);
      addTearDown(r.dispose);
      final service = backup(r);
      final restore = await candidate(service);
      await database
          .update(database.users)
          .write(const UsersCompanion(note: Value('current value')));
      r.repository.schedules = [r.schedule('old')];
      final invalidated = expectLater(
        r.reconcile(),
        throwsA(isA<AlarmOperationInvalidated>()),
      );
      await native.entered.future;
      var complete = false;
      final pending = service.applyRestore(restore).then((_) {
        complete = true;
      });
      await invalidated;
      await pumpEventQueue();
      expect(complete, false);
      expect(
        (await database.select(database.users).getSingle()).note,
        'current value',
      );
      native.release.complete();
      await pending;
      expect(native.events, ['schedule:old', 'cancel:old']);
      expect(
        (await database.select(database.users).getSingle()).note,
        'backup value',
      );
      expect(r.gate.isAvailable, true);
    },
  );

  test(
    'actual restore cancellation failure preserves original database and ownership',
    () async {
      final r = concurrency.Rig();
      addTearDown(r.dispose);
      final service = backup(r);
      final restore = await candidate(service);
      await database
          .update(database.users)
          .write(const UsersCompanion(note: Value('current value')));
      r.repository.schedules = [r.schedule('old')];
      await r.reconcile();
      r.fallback.throwOnCancelIds.add('old');
      await expectLater(
        service.applyRestore(restore),
        throwsA(
          isA<DataOperationException>()
              .having((e) => e.followUpPending, 'cleanup remains pending', true)
              .having((e) => e.generation, 'actual claim generation', 1),
        ),
      );
      expect(
        (await database.select(database.users).getSingle()).note,
        'current value',
      );
      expect(r.registry.records.single.cancellationPending, true);
      expect(r.gate.isAvailable, true);
      r.fallback.throwOnCancelIds.clear();
      await service.applyRestore(restore);
      expect(
        (await database.select(database.users).getSingle()).note,
        'backup value',
      );
    },
  );

  test(
    'reset retains independent cancellation ownership after content deletion and retries only cleanup',
    () async {
      final native = concurrency.BlockingNative()..throwOnCancelIds.add('old');
      final r = concurrency.Rig(native: native);
      addTearDown(r.dispose);
      final keys = _Keys();
      final service = LocalDataResetService(
        database,
        keys,
        r.cancelAll,
        operationGate: r.gate,
        resetActions: DeviceLocalResetActions(
          keyStore: keys,
          closeDatabase: database.close,
          deleteFiles: () async {}, // In-memory Drift fixture owns no DB files.
          clearDeliveries:
              () async {}, // Provider cancellation is exercised by r.
          clearLaunch: () async {},
          clearNativeDeliveries: () async => false,
        ),
      );
      r.repository.schedules = [r.schedule('old')];
      final invalidated = expectLater(
        r.reconcile(),
        throwsA(isA<AlarmOperationInvalidated>()),
      );
      await native.entered.future;
      final pending = service.reset();
      await invalidated;
      await pumpEventQueue();
      expect(keys.deleted, false);
      expect(
        (await database.select(database.users).getSingle()).note,
        'backup value',
      );
      native.release.complete();
      final result = await pending;
      expect(result.isComplete, false);
      expect(result.dataDeleted, true);
      expect(r.gate.isInvalidated, true);
      expect(keys.deleted, true);
      expect(
        (await SharedPreferences.getInstance()).getString('sentinel'),
        null,
      );
      expect(
        await const FlutterSecureStorage().read(
          key: 'ontime_local_reset_pending_v1',
        ),
        'pending',
      );
      expect(r.registry.records.single.cancellationPending, true);
      await expectLater(
        r.reconcile(),
        throwsA(isA<AlarmOperationInvalidated>()),
      );
      expect((await r.operations.journal.read()).ownership, hasLength(1));
      native.throwOnCancelIds.clear();
      final completed = await service.reset();
      expect(completed.isComplete, true);
      // A late progress-screen mount must not start a second destructive reset.
      await (await SharedPreferences.getInstance()).setString(
        'post-reset-sentinel',
        'keep',
      );
      expect(await service.reset(), same(completed));
      expect(
        (await SharedPreferences.getInstance()).getString(
          'post-reset-sentinel',
        ),
        'keep',
      );
      expect((await r.operations.journal.read()).ownership, isEmpty);
      // Even after cleanup succeeds, the old closed DB is not reopened for editing.
      expect(r.gate.isInvalidated, true);
    },
  );
}

class _Keys extends InstallationKeyStore {
  bool deleted = false;
  @override
  Future<void> delete() async {
    deleted = true;
  }
}

class _Metadata implements AppMetadataProvider {
  @override
  Future<AppMetadata> getMetadata() async =>
      const AppMetadata(version: 'test', buildNumber: '1');
}
