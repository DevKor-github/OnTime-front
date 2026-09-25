// Real recovery screen interactions. The fake port verifies UI ownership;
// actual persistence and operation single flight are tested by recovery service tests.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/backup_operation.dart';
import 'package:on_time_front/domain/ports/recovery_restore_port.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/startup/screens/recovery_restore_screen.dart';

class _Port implements RecoveryRestorePort {
  int previews = 0;
  int activations = 0;
  int resumes = 0;
  int aborts = 0;
  Future<BackupRestoreInput?> Function()? previewAction;
  Future<BackupRestoreReceipt> Function()? activateAction;
  Future<BackupRestoreReceipt> Function()? resumeAction;
  Future<BackupRestoreReceipt> Function()? abortAction;

  @override
  Future<BackupRestoreInput?> preview(String password) {
    previews++;
    return previewAction!();
  }

  @override
  Future<BackupRestoreReceipt> activate(BackupRestoreInput input) {
    activations++;
    return activateAction!();
  }

  @override
  Future<BackupRestoreReceipt> resume() {
    resumes++;
    return resumeAction!();
  }

  @override
  Future<BackupRestoreReceipt> abort() {
    aborts++;
    return abortAction!();
  }
}

class _Candidate extends BackupRestoreInput {
  int releases = 0;
  bool failRelease = false;
  @override
  BackupRestorePreview get preview => BackupRestorePreview(
    cutoff: DateTime.utc(2030, 1, 2),
    sourceAppVersion: '1.2.3',
    sourcePlatform: 'android',
    scheduleCount: 12,
    templateCount: 3,
    defaultPreparationStepCount: 4,
  );
  @override
  Future<void> dispose() async {
    releases++;
    if (failRelease) throw StateError('private candidate path');
  }
}

Widget _screen(
  _Port port, {
  String locale = 'en',
  BackupRestoreReceipt? initial,
  VoidCallback? cancelled,
  VoidCallback? completed,
}) => MaterialApp(
  locale: Locale(locale),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: RecoveryRestoreScreen(
    port: () async => port,
    initialReceipt: initial,
    onCancelled: cancelled ?? () {},
    onCompleted: completed ?? () {},
  ),
);

Future<void> _choose(WidgetTester tester) async {
  await tester.tap(find.text('Choose backup file'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  expect(find.byType(RecoveryPasswordDialog), findsOneWidget);
  await tester.enterText(find.byType(TextField), 'portable backup password');
  await tester.tap(find.text('Continue'));
  // The picker/preview may intentionally remain outstanding.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  for (final locale in ['en', 'ko']) {
    testWidgets(
      '$locale unknown outcome keeps one live requery and no destructive choices',
      (tester) async {
        final pending = Completer<BackupRestoreReceipt>();
        final port = _Port()..resumeAction = () => pending.future;
        var exited = 0;
        var completed = 0;
        await tester.pumpWidget(
          _screen(
            port,
            locale: locale,
            initial: const BackupRestoreReceipt.uncertain(generation: 1),
            cancelled: () => exited++,
            completed: () => completed++,
          ),
        );
        await tester.pumpAndSettle();
        final next = locale == 'ko' ? '복구 계속' : 'Continue recovery';
        expect(
          find.text(locale == 'ko' ? '백업 파일 선택' : 'Choose backup file'),
          findsNothing,
        );
        expect(
          find.text(locale == 'ko' ? '이 복구 중단' : 'Stop this recovery'),
          findsNothing,
        );
        expect(find.text(locale == 'ko' ? '돌아가기' : 'Back'), findsNothing);
        await tester.tap(find.text(next));
        await tester.pump();
        await tester.tap(find.text(next));
        await tester.pump(const Duration(seconds: 30));
        expect(port.resumes, 1);
        expect(port.previews, 0);
        expect(port.aborts, 0);
        expect(port.activations, 0);
        expect(exited, 0);
        expect(completed, 0);
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, next))
              .onPressed,
          isNull,
        );
        pending.complete(const BackupRestoreReceipt.uncertain(generation: 1));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, next))
              .onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'unapplied recovery cancellation requires confirmation and waits for cleanup',
    (tester) async {
      final pending = Completer<BackupRestoreReceipt>();
      final port = _Port()..abortAction = () => pending.future;
      var normalApp = 0;
      await tester.pumpWidget(
        _screen(
          port,
          initial: BackupRestoreReceipt(
            disposition: BackupCommitDisposition.notCommitted,
            generation: 2,
            followUpPending: true,
          ),
          completed: () => normalApp++,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stop this recovery'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Keep the original data and key'),
        findsOneWidget,
      );
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(port.aborts, 0);
      await tester.tap(find.text('Stop this recovery'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stop recovery'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(port.aborts, 1);
      expect(find.text('Choose backup file'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Continue recovery'),
            )
            .onPressed,
        isNull,
      );
      pending.complete(
        BackupRestoreReceipt(
          disposition: BackupCommitDisposition.notCommitted,
          generation: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Choose backup file'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Choose backup file'),
            )
            .onPressed,
        isNotNull,
      );
      expect(normalApp, 0); // Keeping the damaged original is not a ready app.
    },
  );

  testWidgets(
    'late preview after screen disposal releases candidate without activation',
    (tester) async {
      final pending = Completer<BackupRestoreInput?>();
      final candidate = _Candidate();
      final port = _Port()..previewAction = () => pending.future;
      await tester.pumpWidget(_screen(port));
      await tester.pumpAndSettle();
      await _choose(tester);
      expect(port.previews, 1);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      pending.complete(candidate);
      await tester.pumpAndSettle();
      expect(candidate.releases, 1);
      expect(port.activations, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'preview cancellation reports unknown original count and releases the candidate',
    (tester) async {
      final candidate = _Candidate();
      final port = _Port()..previewAction = () async => candidate;
      await tester.pumpWidget(_screen(port));
      await tester.pumpAndSettle();
      await _choose(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.textContaining(
          '12 schedules · 3 templates · 4 default preparation steps',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('The damaged original count is unknown.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(port.activations, 0);
      expect(candidate.releases, 1);
      expect(find.text('Choose backup file'), findsOneWidget);
    },
  );

  testWidgets(
    'failed candidate release keeps replacement and exit blocked without leaking cause',
    (tester) async {
      final candidate = _Candidate()..failRelease = true;
      final port = _Port()..previewAction = () async => candidate;
      await tester.pumpWidget(_screen(port));
      await tester.pumpAndSettle();
      await _choose(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(candidate.releases, 1);
      expect(find.textContaining('private candidate path'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Choose backup file'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Back'))
            .onPressed,
        isNull,
      );
      expect(port.activations, 0);
    },
  );

  testWidgets(
    'applied recovery waits for restart and follow-up without importing again',
    (tester) async {
      final pending = Completer<BackupRestoreReceipt>();
      final port = _Port()..resumeAction = () => pending.future;
      var normalApp = 0;
      await tester.pumpWidget(
        _screen(
          port,
          initial: const BackupRestoreReceipt.recovery(
            generation: 3,
            phase: RecoveryFollowUp.awaitingNewProcess,
          ),
          completed: () => normalApp++,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Fully close and reopen'), findsOneWidget);
      expect(find.text('Stop this recovery'), findsNothing);
      expect(find.text('Choose backup file'), findsNothing);
      await tester.tap(find.text('Continue recovery'));
      await tester.pump();
      expect(normalApp, 0);
      pending.complete(
        BackupRestoreReceipt(
          disposition: BackupCommitDisposition.committed,
          generation: 3,
        ),
      );
      await tester.pumpAndSettle();
      expect(normalApp, 1);
      expect(port.previews, 0);
      expect(port.activations, 0);
    },
  );
}
