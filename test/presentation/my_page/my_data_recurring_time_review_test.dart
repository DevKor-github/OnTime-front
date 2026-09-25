// Actual MyData -> time review -> recurrence -> full validation -> final confirm.
// Typed fake ports isolate route ownership; ciphertext/SQLite are tested apart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/backup_operation.dart';
import 'package:on_time_front/domain/entities/backup_restore_selection.dart';
import 'package:on_time_front/domain/ports/backup_time_review_port.dart';
import 'package:on_time_front/domain/ports/local_data_ports.dart';
import 'package:on_time_front/domain/use-cases/local_data_workflows.dart';
import 'package:on_time_front/presentation/backup/backup_recurring_time_review_screen.dart';
import 'package:on_time_front/presentation/backup/backup_time_review_screen.dart';
import 'package:on_time_front/presentation/my_page/my_data_screen.dart';
import '../backup/backup_recurring_time_review_screen_test.dart' as recurring;
import '../backup/backup_time_review_screen_test.dart' show ReadyInput;

class _Candidate extends recurring.Candidate {
  _Candidate() : super('recurring-current-owner');
  final ready = ReadyInput();
  @override
  Future<BackupRestoreSelection> revalidate() async {
    validations++;
    return choices.isEmpty ? this : ready;
  }
}

class _Port extends Fake implements BackupOperationsPort, BackupTimeReviewPort {
  final review = _Candidate();
  int applied = 0;
  @override
  int generation = 0;
  @override
  Future<BackupFreshnessStatus> freshness() async =>
      const BackupFreshnessStatus(freshness: BackupFreshness.neverExported);
  @override
  Future<BackupRestoreSelection?> selectForRestore(String password) async =>
      review;
  @override
  Future<int> apply(BackupRestoreInput input) async {
    expect(input, same(review.ready));
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
  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    final scrollable = find.byType(Scrollable).last;
    final state = tester.state<ScrollableState>(scrollable);
    state.position.jumpTo(0);
    await tester.pump();
    await tester.scrollUntilVisible(finder, 180, scrollable: scrollable);
    await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> open(WidgetTester tester, _Port port, _Delivery delivery) async {
    await tester.pumpWidget(
      MaterialApp(home: MyDataScreen(workflow: BackupWorkflow(port, delivery))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('백업에서 복원'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'recurring route password');
    await tester.tap(find.text('계속'));
    await tester.pumpAndSettle();
    await tap(tester, 'backup-time-issue-rule-1');
    await tap(tester, 'backup-time-recurrence');
    expect(find.byType(BackupRecurringTimeReviewScreen), findsOneWidget);
    expect(port.review.disposals, 0);
    expect(port.applied, 0);
  }

  for (final apply in [false, true]) {
    testWidgets(
      'recurring choice needs full revalidation and separate final ${apply ? 'apply' : 'cancel'}',
      (tester) async {
        final port = _Port(), delivery = _Delivery();
        await open(tester, port, delivery);
        await tap(tester, 'review-backup-recurrence');
        await tap(tester, 'choose-backup-recurrence');
        await tester.tap(
          find.byKey(const Key('confirm-backup-recurrence-choice')),
        );
        await tester.pumpAndSettle();
        expect(port.review.choices, hasLength(1));
        expect(port.review.validations, 1);
        expect(find.text('복원 내용 확인'), findsOneWidget);
        expect(port.applied, 0);
        expect(delivery.calls, 0);
        await tester.tap(find.text(apply ? '복원' : '취소'));
        await tester.pumpAndSettle();
        expect(port.applied, apply ? 1 : 0);
        expect(delivery.calls, apply ? 1 : 0);
        expect(port.review.ready.disposed, isTrue);
        expect(port.review.disposals, greaterThan(0));
      },
    );
  }
  testWidgets(
    'cancel recurring subreview retains its parent lease and cannot apply',
    (tester) async {
      final port = _Port(), delivery = _Delivery();
      await open(tester, port, delivery);
      await tap(tester, 'cancel-backup-recurrence');
      await tester.pumpAndSettle();
      expect(find.byType(BackupTimeReviewScreen), findsOneWidget);
      expect(port.review.choices, isEmpty);
      expect(port.review.validations, 1);
      expect(port.review.disposals, 0);
      expect(port.applied, 0);
      await tap(tester, 'cancel-backup-time');
      await tester.pumpAndSettle();
      expect(port.review.disposals, greaterThan(0));
      expect(delivery.calls, 0);
    },
  );
}
