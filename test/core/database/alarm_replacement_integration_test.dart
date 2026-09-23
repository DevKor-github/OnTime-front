import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_crypto.dart';
import 'package:on_time_front/core/backup/backup_service.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/installation_key_store.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
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
        throwsA(isA<AlarmCleanupIncomplete>()),
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
    'durable reset intent blocks writers after cancellation failure without deleting data',
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
      );
      r.repository.schedules = [r.schedule('old')];
      final invalidated = expectLater(
        r.reconcile(),
        throwsA(isA<AlarmOperationInvalidated>()),
      );
      await native.entered.future;
      final pending = service.reset();
      final failed = expectLater(
        pending,
        throwsA(isA<AlarmCleanupIncomplete>()),
      );
      await invalidated;
      await pumpEventQueue();
      expect(keys.deleted, false);
      expect(
        (await database.select(database.users).getSingle()).note,
        'backup value',
      );
      native.release.complete();
      await failed;
      expect(r.gate.isInvalidated, true);
      expect(keys.deleted, false);
      expect(
        (await SharedPreferences.getInstance()).getString('sentinel'),
        'keep',
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
      await expectLater(service.reset(), throwsA(isA<LocalDataUnavailable>()));
      // Existing policy: restart resumes the pending reset; no ordinary retry or
      // registry wipe can silently reopen this installation in the same process.
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
