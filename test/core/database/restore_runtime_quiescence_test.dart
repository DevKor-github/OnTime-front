import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_service.dart';
import 'package:on_time_front/core/backup/backup_crypto.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/restore_runtime_identity.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/core/services/app_metadata_service.dart';
import 'package:on_time_front/data/repositories/schedule_repository_impl.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/repositories/timed_preparation_repository.dart';
import 'package:on_time_front/domain/use-cases/cancel_all_alarms_use_case.dart';
import 'package:on_time_front/domain/use-cases/delete_schedule_use_case.dart';
import 'package:on_time_front/data/repositories/recurring_schedule_repository_impl.dart';
import 'package:on_time_front/data/repositories/schedule_aggregate_repository_impl.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';
import 'package:on_time_front/domain/entities/timed_preparation_snapshot_entity.dart';
import 'package:on_time_front/domain/use-cases/schedule_preparation_session_use_case.dart';
import '../../helpers/schedule_deletion_workflow_fixture.dart';
import '../../helpers/noop_alarm_reconciliation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/use-cases/alarm_reconciliation_concurrency_test.dart'
    as concurrency;
import '../../helpers/restore_staging_fixture.dart';
import '../../helpers/sodium_test_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'restore waits for actual old delete-runtime Future before same-ID replacement',
    () async {
      SharedPreferences.setMockInitialValues({
        'preparation_with_time_same': 'old',
      });
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db.userDao.putUser(
        const UserEntity(
          id: 'local-profile',
          spareTime: Duration.zero,
          note: 'original',
        ),
      );
      final timed = _BlockingTimed();
      final repository = ScheduleRepositoryImpl(
        database: db,
        timedPreparationRepository: timed,
      );
      addTearDown(repository.dispose);
      final rig = concurrency.Rig();
      addTearDown(rig.dispose);
      final original = rig.schedule('same');
      await repository.createSchedule(original);
      final owner = rig.operations;
      final cancel = CancelAllAlarmsUseCase(
        rig.registry,
        rig.scheduler,
        rig.fallback,
        operations: owner,
      );
      final backup = BackupService(
        db,
        _Metadata(),
        cancel,
        crypto: BackupCrypto(sodiumLoader: loadSodiumForTest),
        operationGate: rig.gate,
        ingestionFactory: memoryBackupIngestion,
        processingOwner: testBackupProcessingOwner(),
        stagingFactory: memoryRestoreStaging,
        runtimeIdentity: RestoreRuntimeIdentity(),
        cleanupPlatform: noPlatformRestoreCleanup,
      );
      final bytes = await backup.createEncryptedBackup(
        'portable backup password',
      );
      final aggregate = ScheduleAggregateRepositoryImpl(
        db,
        RecurringScheduleRepositoryImpl(db),
        gate: rig.gate,
      );
      final sessions = SchedulePreparationSessionUseCase(
        repository,
        _Preparation(),
        timed,
        DeletionEarly(),
        rig.cancelOne,
        NoopAlarmReconciliation(),
        operations: owner,
      );
      addTearDown(sessions.dispose);
      final useCase = DeleteScheduleUseCase(
        aggregate,
        rig.registry,
        rig.scheduler,
        rig.fallback,
        sessions,
        NoopAlarmReconciliation(),
        operations: owner,
      );
      final deletion = useCase.confirm(await useCase.prepare(original.id));
      final interrupted = expectLater(
        deletion,
        throwsA(isA<AlarmOperationInvalidated>()),
      );
      await timed.entered.future;
      expect(await db.select(db.schedules).get(), isEmpty);
      final candidate = await backup.previewEncryptedBackup(
        bytes,
        'portable backup password',
      );
      var restored = false;
      final restoring = backup
          .applyRestore(candidate)
          .then((_) => restored = true);
      await pumpEventQueue();
      expect(restored, isFalse);
      expect(await db.select(db.schedules).get(), isEmpty);
      timed.release.complete();
      await interrupted;
      await restoring;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('preparation_with_time_same', 'new-run');
      await pumpEventQueue();
      expect(prefs.getString('preparation_with_time_same'), 'new-run');
      expect(timed.calls, 1);
      expect(
        (await db.select(db.schedules).getSingle()).requiresStartConfirmation,
        isTrue,
      );
    },
  );
}

class _BlockingTimed implements TimedPreparationRepository {
  final entered = Completer<void>(), release = Completer<void>();
  int calls = 0;
  @override
  Future<TimedPreparationSnapshotEntity?> getTimedPreparationSnapshot(
    String scheduleId,
  ) async => null;
  @override
  Future<void> clearTimedPreparation(String scheduleId) async {
    calls++;
    entered.complete();
    await release.future;
    await (await SharedPreferences.getInstance()).remove(
      'preparation_with_time_$scheduleId',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Preparation extends Fake implements PreparationRepository {}

class _Metadata implements AppMetadataProvider {
  @override
  Future<AppMetadata> getMetadata() async =>
      const AppMetadata(version: '1', buildNumber: '1');
}
