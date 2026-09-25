// Actual MyData route + workflow selection/ready ownership, with typed port
// fixtures. Authenticated crypto/SQLite are covered by service tests separately.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/backup_operation.dart';
import 'package:on_time_front/domain/entities/backup_restore_selection.dart';
import 'package:on_time_front/domain/ports/backup_time_review_port.dart';
import 'package:on_time_front/domain/ports/local_data_ports.dart';
import 'package:on_time_front/domain/use-cases/local_data_workflows.dart';
import 'package:on_time_front/presentation/my_page/my_data_screen.dart';
import 'package:on_time_front/presentation/backup/backup_time_review_screen.dart';
import '../backup/backup_time_review_screen_test.dart'
    show ReviewInput, ReadyInput;

class _Port extends Fake implements BackupOperationsPort, BackupTimeReviewPort {
  final review = ReviewInput();
  final ready = ReadyInput();
  Completer<BackupRestoreSelection?>? pending;
  int applied = 0, selected = 0;
  @override
  int generation = 0;
  @override
  Future<BackupFreshnessStatus> freshness() async =>
      const BackupFreshnessStatus(freshness: BackupFreshness.neverExported);
  @override
  Future<BackupRestoreSelection?> selectForRestore(String password) async {
    selected++;
    return pending?.future ?? review;
  }

  @override
  Future<BackupRestoreInput?> preview(String password) => throw StateError(
    'ready-only legacy API must not receive unresolved input',
  );
  @override
  Future<int> apply(BackupRestoreInput input) async {
    expect(input, same(ready));
    applied++;
    return ++generation;
  }
}

class _Delivery extends Fake implements RestoreDeliveryPort {
  int calls = 0;
  @override
  Future<bool> reconcile() async {
    calls++;
    return true;
  }
}

void main() {
  Future<void> select(
    WidgetTester tester,
    _Port port,
    _Delivery delivery,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: MyDataScreen(workflow: BackupWorkflow(port, delivery))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('백업에서 복원'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'review integration password',
    );
    await tester.tap(find.text('계속'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> makeReady(WidgetTester tester, _Port port) async {
    port.review.ready = port.ready;
    final button = find.byKey(const Key('revalidate-backup-time'));
    await tester.scrollUntilVisible(
      button,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('복원 내용 확인'), findsOneWidget);
    expect(port.applied, 0);
  }

  testWidgets('review cancel cannot apply and disposes provisional owner', (
    tester,
  ) async {
    final port = _Port();
    final delivery = _Delivery();
    await select(tester, port, delivery);
    expect(find.byType(BackupTimeReviewScreen), findsOneWidget);
    expect(port.applied, 0);
    final button = find.byKey(const Key('cancel-backup-time'));
    await tester.scrollUntilVisible(
      button,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(port.review.disposed, isTrue);
    expect(port.applied, 0);
    expect(delivery.calls, 0);
    expect(find.byType(BackupTimeReviewScreen), findsNothing);
  });
  testWidgets('fresh ready still requires independent final confirmation', (
    tester,
  ) async {
    final port = _Port();
    final delivery = _Delivery();
    await select(tester, port, delivery);
    await makeReady(tester, port);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(port.applied, 0);
    expect(port.ready.disposed, isTrue);
    expect(port.review.disposeCalls, greaterThan(0));
    expect(delivery.calls, 0);
  });
  testWidgets(
    'only fresh ready applies once and cleanup releases both owners',
    (tester) async {
      final port = _Port();
      final delivery = _Delivery();
      await select(tester, port, delivery);
      await makeReady(tester, port);
      await tester.tap(find.text('복원'));
      await tester.pumpAndSettle();
      expect(port.applied, 1);
      expect(delivery.calls, 1);
      expect(port.ready.disposed, isTrue);
      expect(port.review.disposeCalls, greaterThan(0));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('late picker result after route disposal cannot open review', (
    tester,
  ) async {
    final port = _Port()..pending = Completer<BackupRestoreSelection?>();
    final delivery = _Delivery();
    await select(tester, port, delivery);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    port.pending!.complete(port.review);
    await tester.pumpAndSettle();
    expect(port.review.disposed, isTrue);
    expect(port.applied, 0);
    expect(delivery.calls, 0);
    expect(tester.takeException(), isNull);
  });
}
