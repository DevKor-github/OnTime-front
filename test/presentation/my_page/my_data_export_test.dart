import 'package:on_time_front/data/adapters/local_data_workflow_adapters.dart';
import 'package:on_time_front/domain/entities/local_reset_result.dart';
import 'package:on_time_front/domain/ports/local_data_ports.dart';
import 'package:on_time_front/domain/use-cases/local_data_workflows.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_service.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/presentation/my_page/my_data_screen.dart';

class _BackupService extends Fake implements BackupOperationsPort {
  late final result = Completer<BackupExportResult>();
  int calls = 0;
  @override
  int generation = 0;
  Object? freshnessFailure;
  Completer<BackupFreshnessStatus>? freshnessPending;

  @override
  Future<BackupFreshnessStatus> freshness() async {
    if (freshnessPending != null) return freshnessPending!.future;
    if (freshnessFailure != null) throw freshnessFailure!;
    return const BackupFreshnessStatus(
      freshness: BackupFreshness.neverExported,
    );
  }

  @override
  Future<BackupExportResult> export(String password) {
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
    getIt.registerSingleton<BackupWorkflow>(
      BackupWorkflow(service, _Delivery()),
    );
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
  testWidgets(
    'freshness failure has safe retry and never exposes raw details',
    (tester) async {
      service.freshnessFailure = StateError('/private/synthetic/secret');
      await tester.pumpWidget(const MaterialApp(home: MyDataScreen()));
      await tester.pumpAndSettle();
      expect(find.text('백업 상태를 확인하지 못했습니다. 다시 시도해 주세요.'), findsOneWidget);
      expect(find.textContaining('/private/'), findsNothing);
      service.freshnessFailure = null;
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(find.text('아직 내보낸 백업이 없습니다.'), findsOneWidget);
    },
  );
  testWidgets('late old-generation export error cannot show a snackbar', (
    tester,
  ) async {
    await startExport(tester);
    service.generation++;
    service.result.completeError(StateError('synthetic secret'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('disposed route never shows late export result', (tester) async {
    await startExport(tester);
    await tester.pumpWidget(const MaterialApp(home: Text('new route')));
    service.result.complete(BackupExportResult.saved);
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('new route'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('late freshness failure after generation change is discarded', (
    tester,
  ) async {
    service.freshnessPending = Completer<BackupFreshnessStatus>();
    await tester.pumpWidget(const MaterialApp(home: MyDataScreen()));
    service.generation++;
    service.freshnessPending!.completeError(StateError('old error'));
    await tester.pumpAndSettle();
    expect(find.text('백업 상태를 확인하지 못했습니다. 다시 시도해 주세요.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'reset confirmation is one intent and rejects a changed installation',
    (tester) async {
      var calls = 0;
      final reset = LocalResetWorkflow(
        RecoveryResetAdapter(() async {
          calls++;
          return const LocalResetResult(intentRecorded: true, completed: {});
        }),
      );
      await tester.pumpWidget(
        MaterialApp(home: MyDataScreen(resetWorkflow: reset)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('로컬 데이터 초기화'));
      await tester.pumpAndSettle();
      expect(find.text('복구하지 않고 삭제하시겠습니까?'), findsOneWidget);
      expect(calls, 0);
      service.generation++;
      await tester.tap(find.text('모두 삭제'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.text('내 데이터'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Delivery implements RestoreDeliveryPort {
  @override
  Future<bool> reconcile() async => true;
}
