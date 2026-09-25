import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:on_time_front/core/backup/backup_crypto.dart';
import 'package:on_time_front/core/backup/backup_file_export_port.dart';
import 'package:on_time_front/core/backup/backup_service.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/database/restore_runtime_identity.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/core/services/app_metadata_service.dart';
import 'package:on_time_front/core/services/detailed_notification_preference_service.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';
import 'package:on_time_front/presentation/my_page/cubit/detailed_notification_settings_cubit.dart';

import '../../helpers/noop_alarm_cleanup.dart';
import '../../helpers/restore_staging_fixture.dart';
import '../../helpers/sodium_test_loader.dart';

class _Metadata implements AppMetadataProvider {
  @override
  Future<AppMetadata> getMetadata() async =>
      const AppMetadata(version: '1.0', buildNumber: '1');
}

class _Destination implements BackupFileExportPort {
  final opened = Completer<void>();
  final finish = Completer<BackupFileExportReceipt>();
  Uint8List? bytes;
  @override
  Future<BackupFileExportReceipt> exportStream({
    required Stream<List<int>> encrypted,
    required String suggestedName,
    BackupProcessingLease? lease,
  }) async {
    final output = BytesBuilder(copy: false);
    await for (final chunk in encrypted) {
      output.add(chunk);
    }
    bytes = output.takeBytes();
    opened.complete();
    return finish.future;
  }
}

// Backup boundaries use a result-only delivery port. Real reconciliation is
// covered in the separate delivery acceptance file, not claimed here.
class _NoDelivery extends Fake implements ReconcileAlarmsUseCase {
  @override
  Future<AlarmReconciliationResult> call() async => AlarmReconciliationResult(
    status: AlarmReconciliationStatus.armed,
    nativeAlarmProvider: AlarmProvider.none,
    fallbackProvider: AlarmProvider.none,
    armedScheduleIds: const [],
    skippedScheduleCount: 0,
    failures: const [],
    scheduleWindowStart: DateTime.utc(2030),
    scheduleWindowEnd: DateTime.utc(2030, 1, 2),
    alarmCoverageStart: DateTime.utc(2030),
    alarmCoverageEnd: DateTime.utc(2030, 1, 2),
  );
}

class _QueuedWrite implements DetailedNotificationPreferencePort {
  _QueuedWrite(this.actual);
  final DetailedNotificationPreferenceService actual;
  final entered = Completer<void>(),
      release = Completer<void>(),
      drained = Completer<void>();
  @override
  Future<DetailedNotificationPreferenceSnapshot> read({
    required int expectedGeneration,
  }) => actual.read(expectedGeneration: expectedGeneration);
  @override
  Future<DetailedNotificationPreferenceSnapshot> write(
    bool enabled, {
    required int expectedGeneration,
  }) async {
    entered.complete();
    await release.future;
    try {
      return await actual.write(
        enabled,
        expectedGeneration: expectedGeneration,
      );
    } finally {
      drained.complete();
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const password = 'detailed preference backup password';
  late AppDatabase db;
  late LocalDataOperationGate gate;
  late AlarmOperationCoordinator owner;
  late DetailedNotificationPreferenceService preferences;
  late BackupService backup;
  late _Destination destination;
  late RestoreRuntimeIdentity identity;
  late BackupCrypto crypto;
  bool failCleanup = false;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    gate = LocalDataOperationGate();
    owner = AlarmOperationCoordinator(gate);
    preferences = DetailedNotificationPreferenceService(db, gate: gate);
    destination = _Destination();
    identity = RestoreRuntimeIdentity();
    crypto = BackupCrypto(sodiumLoader: loadSodiumForTest);
    failCleanup = false;
    backup = BackupService(
      db,
      _Metadata(),
      NoopAlarmCleanup(),
      crypto: crypto,
      operationGate: gate,
      exportPort: destination,
      ingestionFactory: memoryBackupIngestion,
      processingOwner: testBackupProcessingOwner(),
      stagingFactory: memoryRestoreStaging,
      runtimeIdentity: identity,
      cleanupPlatform: () async {
        if (failCleanup) throw StateError('unconfirmed');
      },
    );
    await db.customStatement(
      "INSERT INTO users(id,spare_time,note,data_revision,detailed_notification_content,"
      "store_incarnation) VALUES('local-profile',0,'preserved',9,1,'old-store')",
    );
  });
  tearDown(() async {
    if (!destination.finish.isCompleted) {
      destination.finish.complete(BackupFileExportReceipt.cancelled);
    }
    owner.dispose();
    gate.dispose();
    await db.close();
  });

  test(
    'encrypted export freezes ON at cutoff while OFF commits during destination selection',
    () async {
      final exporting = backup.exportToUserSelectedFile(password);
      try {
        await Future.any([
          destination.opened.future,
          exporting.then<void>((_) {
            fail('export ended without reaching destination');
          }),
        ]);
        final decoded =
            jsonDecode(
                  utf8.decode(
                    await crypto.decrypt(
                      container: destination.bytes!,
                      password: password,
                    ),
                  ),
                )
                as Map;
        expect(decoded['preferences']['detailedNotificationContent'], isTrue);
        expect(decoded['dataRevision'], 9);
        await preferences.write(false, expectedGeneration: 0);
        destination.finish.complete(BackupFileExportReceipt.saved);
        expect(await exporting, BackupExportResult.saved);
        final row = await db.select(db.users).getSingle();
        expect(row.detailedNotificationContent, isFalse);
        expect(row.dataRevision, 10);
        expect(row.lastExportedRevision, 9);
        final again =
            jsonDecode(
                  utf8.decode(
                    await crypto.decrypt(
                      container: destination.bytes!,
                      password: password,
                    ),
                  ),
                )
                as Map;
        expect(again, decoded);
        final next = await backup.createEncryptedBackup(password);
        final nextDecoded =
            jsonDecode(
                  utf8.decode(
                    await crypto.decrypt(container: next, password: password),
                  ),
                )
                as Map;
        expect(
          nextDecoded['preferences']['detailedNotificationContent'],
          isFalse,
        );
        expect(nextDecoded['dataRevision'], 10);
      } finally {
        if (!destination.finish.isCompleted) {
          destination.finish.complete(BackupFileExportReceipt.cancelled);
        }
        await exporting;
      }
    },
  );

  test(
    'restore renews store and rejects accepted old OFF when queued write finally runs',
    () async {
      final bytes = await backup.createEncryptedBackup(password);
      final queued = _QueuedWrite(preferences);
      final controller = DetailedNotificationSettingsCubit.test(
        queued,
        _NoDelivery(),
        operations: owner,
      );
      final candidate = await backup.previewEncryptedBackup(bytes, password);
      try {
        await controller.refresh();
        controller.request(false);
        await queued.entered.future.timeout(const Duration(seconds: 10));
        expect(controller.state.requestedEnabled, isFalse);
        await backup.applyRestore(candidate);
        final restored = await db.select(db.users).getSingle();
        expect(gate.generation, 1);
        expect(restored.storeIncarnation, isNot('old-store'));
        expect(restored.detailedNotificationContent, isTrue);
        queued.release.complete();
        await queued.drained.future;
        // Observe the controller's post-error state without a wall-clock delay.
        await Future<void>.delayed(Duration.zero);
        expect(controller.state.requestedEnabled, isNull);
        expect(controller.state.load, DetailedPreferenceLoad.unavailable);
        expect(
          (await db.select(db.users).getSingle()).dataRevision,
          restored.dataRevision,
        );
        expect(
          (await db.select(db.users).getSingle()).detailedNotificationContent,
          isTrue,
        );
        await controller.refresh();
        expect(controller.state.confirmedEnabled, isTrue);
        expect(controller.state.generation, 1);
      } finally {
        if (!queued.release.isCompleted) queued.release.complete();
        await controller.close();
        await candidate.dispose();
      }
    },
  );

  test(
    'committed restore with pending cleanup has no readable setting authority until cleanup',
    () async {
      await preferences.write(false, expectedGeneration: 0);
      final bytes = await backup.createEncryptedBackup(password);
      await preferences.write(true, expectedGeneration: 0);
      final candidate = await backup.previewEncryptedBackup(bytes, password);
      failCleanup = true;
      try {
        await backup.applyRestore(candidate);
        final restored = await db.select(db.users).getSingle();
        expect(restored.detailedNotificationContent, isFalse);
        expect(restored.restoreCleanupPending, isTrue);
        expect(gate.isRecoveryPending, isTrue);
        await expectLater(
          preferences.read(expectedGeneration: gate.generation),
          throwsA(isA<LocalDataUnavailable>()),
        );
        failCleanup = false;
        await backup.finishRestoreCleanup();
        expect(
          (await preferences.read(
            expectedGeneration: gate.generation,
          )).detailedEnabled,
          isFalse,
        );
        final cleaned = await db.select(db.users).getSingle();
        expect(cleaned.storeIncarnation, restored.storeIncarnation);
        expect(cleaned.dataRevision, restored.dataRevision);
        expect(cleaned.restoreCleanupPending, isFalse);
      } finally {
        await candidate.dispose();
      }
    },
  );
}
