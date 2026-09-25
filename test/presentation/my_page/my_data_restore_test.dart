import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/restore_staging_fixture.dart';
import 'package:on_time_front/core/database/restore_runtime_identity.dart';
import 'dart:async';
import 'package:on_time_front/domain/ports/local_data_ports.dart';
import 'package:on_time_front/domain/use-cases/local_data_workflows.dart';
import '../../helpers/noop_alarm_cleanup.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_crypto.dart';
import 'package:on_time_front/core/backup/backup_service.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/core/services/app_metadata_service.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/presentation/my_page/my_data_screen.dart';

import '../../helpers/sodium_test_loader.dart';

class _Metadata implements AppMetadataProvider {
  @override
  Future<AppMetadata> getMetadata() async =>
      const AppMetadata(version: '1.0.0', buildNumber: '1');
}

class _RestoreService extends Fake implements BackupOperationsPort {
  _RestoreService(this.delegate, this.candidate);
  final BackupService delegate;
  BackupRestoreCandidate? candidate;
  Object? failure;
  int applied = 0;
  final appliedDone = Completer<void>();
  @override
  int get generation => delegate.generation;

  @override
  Future<BackupFreshnessStatus> freshness() => delegate.getFreshness();

  @override
  Future<BackupRestoreCandidate?> preview(String password) async {
    expect(password, 'synthetic backup password');
    if (failure != null) throw failure!;
    return candidate;
  }

  @override
  Future<int> apply(BackupRestoreInput candidate) async {
    applied++;
    final generation = await delegate.applyRestoreWithReceipt(
      candidate as BackupRestoreCandidate,
    );
    appliedDone.complete();
    return generation;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  late AppDatabase database;
  late _RestoreService service;
  late _Delivery delivery;

  setUp(() async {
    await getIt.reset();
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.userDao.putUser(
      const UserEntity(
        id: 'local-profile',
        spareTime: Duration.zero,
        note: 'synthetic backup',
      ),
    );
    final delegate = BackupService(
      database,
      _Metadata(),
      NoopAlarmCleanup(),
      ingestionFactory: memoryBackupIngestion,
      processingOwner: testBackupProcessingOwner(),
      stagingFactory: memoryRestoreStaging,
      runtimeIdentity: RestoreRuntimeIdentity(),
      cleanupPlatform: noPlatformRestoreCleanup,
      crypto: BackupCrypto(sodiumLoader: loadSodiumForTest),
    );
    final candidate = await delegate.previewEncryptedBackup(
      await delegate.createEncryptedBackup('synthetic backup password'),
      'synthetic backup password',
    );
    await database
        .update(database.users)
        .write(const UsersCompanion(note: Value('current sentinel')));
    service = _RestoreService(delegate, candidate);
    delivery = _Delivery();
    getIt.registerSingleton<BackupWorkflow>(BackupWorkflow(service, delivery));
  });

  tearDown(() async {
    await getIt.reset();
    await database.close();
  });

  Future<void> select(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: MyDataScreen()));
    // Drift futures are rooted outside the widget clock.
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('백업에서 복원'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'synthetic backup password');
    await tester.tap(find.text('계속'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('validated preview cancellation never applies backup', (
    tester,
  ) async {
    await select(tester);
    expect(find.text('복원 내용 확인'), findsOneWidget);
    expect(service.applied, 0);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(service.applied, 0);
    expect(
      await tester.runAsync(
        () async => (await database.select(database.users).getSingle()).note,
      ),
      'current sentinel',
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picker cancel skips preview and leaves data untouched', (
    tester,
  ) async {
    service.candidate = null;
    await select(tester);
    await tester.pumpAndSettle();
    expect(find.text('복원 내용 확인'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(service.applied, 0);
    expect(
      await tester.runAsync(
        () async => (await database.select(database.users).getSingle()).note,
      ),
      'current sentinel',
    );
  });

  testWidgets(
    'invalid selected file reports failure and permits another attempt',
    (tester) async {
      service.failure = const FormatException('Invalid backup');
      await select(tester);
      await tester.pumpAndSettle();
      expect(find.textContaining('작업을 완료하지 못했습니다'), findsOneWidget);
      expect(find.text('복원 내용 확인'), findsNothing);
      expect(service.applied, 0);
      expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, '백업에서 복원'))
            .enabled,
        true,
      );
      expect(
        await tester.runAsync(
          () async => (await database.select(database.users).getSingle()).note,
        ),
        'current sentinel',
      );
    },
  );
  testWidgets(
    'committed restore reports partial then retry changes no durable data',
    (tester) async {
      delivery.succeeds = false;
      await select(tester);
      await tester.tap(find.text('복원'));
      await tester.pump();
      await tester.runAsync(() => service.appliedDone.future);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('데이터는 복원됐지만 남은 정리와 알림 처리가 완료되지 않았습니다.'),
        findsWidgets,
      );
      expect(service.applied, 1);
      final before = await tester.runAsync(
        () => database.select(database.users).getSingle(),
      );
      expect(before!.note, 'synthetic backup');
      delivery.succeeds = true;
      await tester.tap(find.text('남은 처리 다시 시도'));
      await tester.pumpAndSettle();
      expect(find.text('현재 데이터의 알림 처리를 완료했습니다.'), findsOneWidget);
      expect(service.applied, 1);
      final after = await tester.runAsync(
        () => database.select(database.users).getSingle(),
      );
      expect(after!.dataRevision, before.dataRevision);
      expect(delivery.calls, 2);
    },
  );
}

class _Delivery implements RestoreDeliveryPort {
  bool succeeds = true;
  int calls = 0;
  @override
  Future<bool> reconcile() async {
    calls++;
    return succeeds;
  }
}
