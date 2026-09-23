import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_service.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/presentation/my_page/my_data_screen.dart';

class _BackupService extends Fake implements BackupService {
  late final result = Completer<BackupExportResult>();
  int calls = 0;

  @override
  Future<BackupFreshnessStatus> getFreshness() async =>
      const BackupFreshnessStatus(freshness: BackupFreshness.neverExported);

  @override
  Future<BackupExportResult> exportToUserSelectedFile(String password) {
    expect(password, 'test backup password');
    calls++;
    return result.future;
  }
}

void main() {
  late _BackupService service;
  setUp(() async {
    await getIt.reset();
    service = _BackupService();
    getIt.registerSingleton<BackupService>(service);
  });
  tearDown(() => getIt.reset());

  Future<void> startExport(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: MyDataScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('암호화 백업 내보내기'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).at(0),
      'test backup password',
    );
    await tester.enterText(
      find.byType(TextField).at(1),
      'test backup password',
    );
    await tester.tap(find.text('계속'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(service.calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  }

  for (final entry in ['암호화 백업 내보내기', '백업에서 복원']) {
    testWidgets('$entry password cancel disposes only after exit transition', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: MyDataScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        'test backup password',
      );
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(service.calls, 0);
      expect(find.byType(TextField), findsNothing);
    });
  }

  testWidgets('only completed file save announces success', (tester) async {
    await startExport(tester);
    service.result.complete(BackupExportResult.saved);
    await tester.pumpAndSettle();
    expect(find.text('암호화 백업을 저장했습니다.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('cancel clears busy state without announcing success', (
    tester,
  ) async {
    await startExport(tester);
    service.result.complete(BackupExportResult.cancelled);
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      tester
          .widget<ListTile>(find.widgetWithText(ListTile, '암호화 백업 내보내기'))
          .enabled,
      true,
    );
  });

  testWidgets('saved file with metadata failure is explained separately', (
    tester,
  ) async {
    await startExport(tester);
    service.result.complete(BackupExportResult.savedFreshnessUpdateFailed);
    await tester.pumpAndSettle();
    expect(find.textContaining('파일은 저장됐지만 백업 상태를 갱신하지 못했습니다.'), findsOneWidget);
    expect(find.text('암호화 백업을 저장했습니다.'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
