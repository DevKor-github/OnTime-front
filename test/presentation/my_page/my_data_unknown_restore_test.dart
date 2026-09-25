import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/domain/entities/backup_operation.dart';
import 'package:on_time_front/domain/use-cases/local_data_workflows.dart';
import 'package:on_time_front/presentation/my_page/my_data_screen.dart';

class _Candidate extends BackupRestoreInput {
  int releases = 0;
  @override
  BackupRestorePreview get preview => BackupRestorePreview(
    cutoff: DateTime.utc(2030),
    sourceAppVersion: 'test',
    sourcePlatform: 'android',
    scheduleCount: 2,
    templateCount: 0,
    defaultPreparationStepCount: 1,
  );
  @override
  Future<void> dispose() async {
    releases++;
  }
}

class _UnknownWorkflow extends Fake implements BackupWorkflow {
  final candidate = _Candidate();
  int restored = 0;
  @override
  int get generation => 1;
  @override
  Future<BackupFreshnessStatus> freshness() async =>
      const BackupFreshnessStatus(freshness: BackupFreshness.neverExported);
  @override
  Future<BackupRestoreInput?> preview(String password) async => candidate;
  @override
  Future<BackupRestoreInput?> selectForRestore(String password) async =>
      candidate;
  @override
  Future<BackupRestoreReceipt> restore(BackupRestoreInput input) async {
    restored++;
    return const BackupRestoreReceipt.uncertain(generation: 1);
  }
}

void main() {
  setUp(() => getIt.reset());
  tearDown(() => getIt.reset());
  testWidgets(
    'unknown commit cannot turn into failure, retry delivery, export, restore, or reset',
    (tester) async {
      final workflow = _UnknownWorkflow();
      getIt.registerSingleton<BackupWorkflow>(workflow);
      await tester.pumpWidget(const MaterialApp(home: MyDataScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('백업에서 복원'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'portable backup password',
      );
      await tester.tap(find.text('계속'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('복원'));
      await tester.pumpAndSettle();
      expect(workflow.restored, 1);
      expect(workflow.candidate.releases, 0);
      for (final tile in tester.widgetList<ListTile>(find.byType(ListTile))) {
        expect(tile.enabled, false);
      }
      expect(find.textContaining('not yet confirmed'), findsWidgets);
      final retry = tester.widgetList<TextButton>(find.byType(TextButton));
      expect(retry.every((button) => button.onPressed == null), true);
      expect(tester.takeException(), isNull);
    },
  );
}
