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

class _RestoreService extends Fake implements BackupService {
  _RestoreService(this.delegate, this.candidate);
  final BackupService delegate;
  BackupRestoreCandidate? candidate;
  Object? failure;
  int applied = 0;

  @override
  Future<BackupFreshnessStatus> getFreshness() => delegate.getFreshness();

  @override
  Future<BackupRestoreCandidate?> selectAndPreviewRestore(
    String password,
  ) async {
    expect(password, 'synthetic backup password');
    if (failure != null) throw failure!;
    return candidate;
  }

  @override
  Future<void> applyRestore(BackupRestoreCandidate candidate) async {
    applied++;
    await delegate.applyRestore(candidate);
  }
}

void main() {
  late AppDatabase database;
  late _RestoreService service;

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
    getIt.registerSingleton<BackupService>(service);
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
}
