import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/restore_staging_fixture.dart';
import 'package:on_time_front/core/database/restore_runtime_identity.dart';
import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_crypto.dart';
import 'package:on_time_front/core/backup/backup_service.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/services/app_metadata_service.dart';
import 'package:on_time_front/data/adapters/local_data_workflow_adapters.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/ports/local_data_ports.dart';
import 'package:on_time_front/domain/use-cases/local_data_workflows.dart';
import '../../helpers/noop_alarm_cleanup.dart';
import '../../helpers/sodium_test_loader.dart';

class _Metadata implements AppMetadataProvider {
  @override
  Future<AppMetadata> getMetadata() async =>
      const AppMetadata(version: '1', buildNumber: '1');
}

class _Cleanup extends NoopAlarmCleanup {
  int calls = 0;
  Completer<void>? barrier;
  final entered = Completer<void>();
  @override
  Future<void> forDataReplacement() async {
    calls++;
    if (!entered.isCompleted) entered.complete();
    if (barrier != null) await barrier!.future;
  }
}

class _Delivery implements RestoreDeliveryPort {
  int calls = 0;
  bool succeeds = false;
  Completer<bool>? barrier;
  @override
  Future<bool> reconcile() async {
    calls++;
    return barrier?.future ?? succeeds;
  }
}

class _DelayedAdapter extends LocalBackupAdapter {
  _DelayedAdapter(super.backup, this.gate);
  final LocalDataOperationGate gate;
  @override
  Future<int> apply(BackupRestoreInput input) async {
    final committedGeneration = await super.apply(input);
    await gate.run(() async {}, replacesData: true);
    return committedGeneration;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  late AppDatabase db;
  late BackupService service;
  late LocalDataOperationGate gate;
  late _Cleanup cleanup;
  late _Delivery delivery;
  late BackupWorkflow workflow;
  const password = 'synthetic backup password';
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    gate = LocalDataOperationGate();
    cleanup = _Cleanup();
    delivery = _Delivery();
    service = BackupService(
      db,
      _Metadata(),
      cleanup,
      ingestionFactory: memoryBackupIngestion,
      processingOwner: testBackupProcessingOwner(),
      stagingFactory: memoryRestoreStaging,
      runtimeIdentity: RestoreRuntimeIdentity(),
      cleanupPlatform: noPlatformRestoreCleanup,
      crypto: BackupCrypto(sodiumLoader: loadSodiumForTest),
      operationGate: gate,
    );
    workflow = BackupWorkflow(LocalBackupAdapter(service), delivery);
    await db.userDao.putUser(
      const UserEntity(
        id: 'local-profile',
        spareTime: Duration.zero,
        note: 'backup sentinel',
      ),
    );
  });
  tearDown(() async {
    await db.close();
    gate.dispose();
  });
  Future<BackupRestoreCandidate> candidate() async =>
      service.previewEncryptedBackup(
        await service.createEncryptedBackup(password),
        password,
      );
  Future<int> revision() async =>
      (await db.select(db.users).getSingle()).dataRevision;

  test(
    'preclaim durable edit rejects without cleanup or generation change',
    () async {
      final input = await candidate();
      await db.userDao.updateSpareTime(
        'local-profile',
        const Duration(minutes: 7),
      );
      final before = await revision();
      final result = await workflow.restore(input);
      expect(result.committed, false);
      expect(result.failure, DataOperationFailure.stalePreview);
      expect(result.followUpPending, false);
      expect(cleanup.calls, 0);
      expect(gate.generation, 0);
      expect(await revision(), before);
      expect((await db.select(db.users).getSingle()).spareTime, 7);
    },
  );
  test(
    'replacement generation invalidates preview with no additional effects',
    () async {
      final input = await candidate();
      await gate.run(() async {}, replacesData: true);
      final result = await workflow.restore(input);
      expect(result.failure, DataOperationFailure.stalePreview);
      expect(cleanup.calls, 0);
      expect(gate.generation, 1);
    },
  );
  test(
    'edit while cleanup awaits rejects transaction and exposes pending recovery',
    () async {
      final input = await candidate();
      cleanup.barrier = Completer<void>();
      final pending = workflow.restore(input);
      await cleanup.entered.future;
      await db.userDao.updateSpareTime(
        'local-profile',
        const Duration(minutes: 9),
      );
      final before = await revision();
      cleanup.barrier!.complete();
      final result = await pending;
      expect(result.committed, false);
      expect(result.followUpPending, true);
      expect(result.failure, DataOperationFailure.stalePreview);
      expect(result.generation, 1);
      expect((await db.select(db.users).getSingle()).spareTime, 9);
      expect(await revision(), before);
      delivery.succeeds = true;
      final recovered = await workflow.retryFollowUp(result);
      expect(recovered.committed, false);
      expect(recovered.followUpPending, false);
      expect(cleanup.calls, 1);
      expect(await revision(), before);
    },
  );
  test(
    'same token shares full pending receipt and delivery retry never reapplies',
    () async {
      final input = await candidate();
      delivery.barrier = Completer<bool>();
      final first = workflow.restore(input);
      final second = workflow.restore(input);
      expect(identical(first, second), true);
      await cleanup.entered.future;
      while (delivery.calls == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(identical(workflow.restore(input), first), true);
      final committedRevision = await revision();
      delivery.barrier!.complete(false);
      final partial = await first;
      expect(partial.committed, true);
      expect(partial.followUpPending, true);
      expect(partial.generation, 1);
      delivery.barrier = null;
      delivery.succeeds = true;
      final complete = await workflow.retryFollowUp(partial);
      expect(complete.followUpPending, false);
      expect(cleanup.calls, 1);
      expect(await revision(), committedRevision);
      expect((await workflow.restore(input)).followUpPending, false);
      expect(cleanup.calls, 1);
      expect(delivery.calls, 2);
      await expectLater(
        service.applyRestore(input),
        throwsA(
          isA<DataOperationException>().having(
            (e) => e.failure,
            'consumed token',
            DataOperationFailure.stalePreview,
          ),
        ),
      );
      expect(await revision(), committedRevision);
    },
  );
  test(
    'failed actual replacement transaction preserves data and retry commits once',
    () async {
      final input = await candidate();
      final before = await revision();
      await db.customStatement(
        "CREATE TRIGGER fail_restore BEFORE INSERT ON users BEGIN SELECT RAISE(ABORT, 'synthetic'); END",
      );
      final result = await workflow.restore(input);
      expect(result.committed, false);
      expect(result.followUpPending, true);
      expect(await revision(), before);
      expect((await db.select(db.users).getSingle()).note, 'backup sentinel');
      await db.customStatement('DROP TRIGGER fail_restore');
      delivery.succeeds = true;
      final retry = await workflow.restore(input);
      expect(retry.committed, true);
      expect(await revision(), before + 1);
      expect(gate.generation, 2);
    },
  );
  test(
    'claim generation survives a later replacement before continuation',
    () async {
      final input = await candidate();
      workflow = BackupWorkflow(_DelayedAdapter(service, gate), delivery);
      final result = await workflow.restore(input);
      expect(result.committed, true);
      expect(result.generation, 1);
      expect(gate.generation, 2);
      expect(result.followUpPending, true);
      expect(result.failure, DataOperationFailure.stalePreview);
      expect(delivery.calls, 0);
    },
  );
  test('old delayed retry cannot absorb a newer generation receipt', () async {
    final first = await workflow.restore(await candidate());
    delivery.barrier = Completer<bool>();
    final oldRetry = workflow.retryFollowUp(first);
    final oldBarrier = delivery.barrier!;
    delivery.barrier = null;
    final second = await workflow.restore(await candidate());
    delivery.succeeds = true;
    final newRetry = workflow.retryFollowUp(second);
    expect(identical(oldRetry, newRetry), false);
    expect((await newRetry).generation, 2);
    oldBarrier.complete(true);
    final old = await oldRetry;
    expect(old.generation, 1);
    expect(old.followUpPending, true);
  });
}
