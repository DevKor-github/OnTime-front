import '../backup/backup_recurring_time_review_screen_test.dart' as recurring;
import 'package:on_time_front/presentation/backup/backup_recurring_time_review_screen.dart';
// Real Recovery and time-review screens with fake ports. File/journal/crypto
// authority is covered separately by the Recovery service tests.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/backup_operation.dart';
import 'package:on_time_front/domain/entities/backup_restore_selection.dart';
import 'package:on_time_front/domain/entities/backup_time_review.dart';
import 'package:on_time_front/domain/ports/backup_time_review_port.dart';
import 'package:on_time_front/domain/ports/recovery_preclaim_cleanup_port.dart';
import 'package:on_time_front/domain/ports/recovery_restore_port.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/backup/backup_time_review_screen.dart';
import 'package:on_time_front/presentation/startup/screens/recovery_restore_screen.dart';

class Candidate extends BackupRestoreInput {
  int releaseCalls = 0, releaseFailures = 0;
  bool disposed = false;
  @override
  BackupRestorePreview get preview => BackupRestorePreview(
    cutoff: DateTime.utc(2030),
    sourceAppVersion: '1.0',
    sourcePlatform: 'android',
    scheduleCount: 1,
    templateCount: 0,
    defaultPreparationStepCount: 0,
  );
  @override
  Future<void> dispose() async {
    releaseCalls++;
    if (releaseFailures > 0) {
      releaseFailures--;
      throw StateError('private file');
    }
    disposed = true;
  }
}

class Review extends BackupTimeReviewInput {
  Review(this.ready);
  final Candidate ready;
  bool transferred = false, disposed = false;
  int validations = 0;
  @override
  BackupTimeReviewSummary get summary => BackupTimeReviewSummary(
    identity: 'review',
    revision: 0,
    validationNowUtc: DateTime.utc(2026),
    rulesIdentity: 'rules',
    issueCount: 0,
    independentStructureChecked: true,
  );
  @override
  Future<BackupTimeReviewIssuePage> issues({String? cursor}) async =>
      BackupTimeReviewIssuePage([]);
  @override
  Future<BackupTimeFieldReview> review(BackupTimeDraft draft) =>
      throw UnimplementedError();
  @override
  Future<void> choose(BackupTimeChoice choice) => throw UnimplementedError();
  @override
  Future<BackupRestoreSelection> revalidate() async {
    validations++;
    transferred = true;
    return ready;
  }

  @override
  Future<void> dispose() async {
    if (!transferred) disposed = true;
  }
}

class RecurringReview extends recurring.Candidate {
  RecurringReview(this.ready) : super('recovery-recurrence');
  final Candidate ready;
  int fullValidations = 0;
  Completer<BackupRestoreSelection>? pendingFullValidation;
  Object? validationFailure;
  BackupTimeReviewInput? replacement;
  @override
  Future<BackupRestoreSelection> revalidate() async {
    fullValidations++;
    if (validationFailure != null) throw validationFailure!;
    if (pendingFullValidation != null) return pendingFullValidation!.future;
    if (replacement != null) return replacement!;
    return choices.isEmpty ? this : ready;
  }
}

class Port
    implements
        RecoveryRestorePort,
        BackupTimeReviewPort,
        RecoveryPreclaimCleanupPort {
  BackupRestoreSelection? selection;
  Completer<BackupRestoreSelection?>? pendingSelection;
  Object? activationFailure;
  int selections = 0,
      previews = 0,
      resumes = 0,
      aborts = 0,
      cleanupFailures = 0;
  final activations = <BackupRestoreInput>[];
  final cleanupGenerations = <int>[];
  Completer<void>? pendingCleanup;
  @override
  Future<BackupRestoreSelection?> selectForRestore(String password) async {
    selections++;
    return pendingSelection == null ? selection : pendingSelection!.future;
  }

  @override
  Future<BackupRestoreInput?> preview(String password) async {
    previews++;
    throw StateError('Typed capability should be used');
  }

  @override
  Future<BackupRestoreReceipt> activate(BackupRestoreInput input) async {
    activations.add(input);
    if (activationFailure != null) throw activationFailure!;
    return BackupRestoreReceipt.recovery(
      generation: 7,
      phase: RecoveryFollowUp.awaitingNewProcess,
    );
  }

  @override
  Future<void> retryPreclaimCleanup(int generation) async {
    cleanupGenerations.add(generation);
    if (cleanupFailures > 0) {
      cleanupFailures--;
      throw StateError('private cleanup');
    }
    if (pendingCleanup != null) await pendingCleanup!.future;
  }

  @override
  Future<BackupRestoreReceipt> resume() async {
    resumes++;
    throw StateError('Unexpected confirmed resume');
  }

  @override
  Future<BackupRestoreReceipt> abort() async {
    aborts++;
    throw StateError('Unexpected confirmed abort');
  }
}

class Host {
  Host(this.port);
  final Port port;
  int factories = 0, exited = 0, completed = 0;
  Future<void> open(
    WidgetTester tester, {
    String locale = 'en',
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(locale),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: RecoveryRestoreScreen(
          port: () async {
            factories++;
            if (factories > 1) {
              throw StateError('Do not recreate a cleanup owner');
            }
            return port;
          },
          onCancelled: () => exited++,
          onCompleted: () => completed++,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

Future<void> tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      150,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> select(WidgetTester tester, {String locale = 'en'}) async {
  await tap(tester, 'select-recovery-backup');
  await tester.enterText(find.byType(TextField), 'portable backup password');
  final next = find.text(locale == 'ko' ? '계속' : 'Continue');
  await tester.ensureVisible(next);
  await tester.tap(next);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> activate(WidgetTester tester, {String locale = 'en'}) async {
  await select(tester, locale: locale);
  await tap(tester, 'confirm-recovery-replacement');
  await tester.pumpAndSettle();
}

const staleAfterCleanup = DataOperationException(
  DataOperationFailure.stalePreview,
  followUpPending: true,
  generation: 7,
);

void main() {
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
  testWidgets(
    'typed review must produce a fresh ready input before separate replacement confirmation',
    (tester) async {
      final ready = Candidate();
      final review = Review(ready);
      final port = Port()..selection = review;
      final host = Host(port);
      await host.open(tester);
      await select(tester);
      expect(find.byType(BackupTimeReviewScreen), findsOneWidget);
      expect(port.previews, 0);
      expect(port.activations, isEmpty);
      await tap(tester, 'revalidate-backup-time');
      // The parent operation remains busy while awaiting this modal choice.
      await tester.pump(const Duration(milliseconds: 350));
      expect(review.validations, 1);
      expect(
        find.byKey(const Key('confirm-recovery-replacement')),
        findsOneWidget,
      );
      expect(port.activations, isEmpty);
      expect(ready.disposed, isFalse);
      await tap(tester, 'confirm-recovery-replacement');
      await tester.pumpAndSettle();
      expect(port.activations, [ready]);
      expect(host.factories, 1);
      expect(host.completed, 0);
      expect(find.textContaining('Fully close and reopen'), findsOneWidget);
    },
  );

  testWidgets(
    'cancelled time review releases selection without activation or replacement dialog',
    (tester) async {
      final review = Review(Candidate());
      final port = Port()..selection = review;
      await Host(port).open(tester);
      await select(tester);
      await tap(tester, 'cancel-backup-time');
      await tester.pumpAndSettle();
      expect(review.disposed, isTrue);
      expect(port.activations, isEmpty);
      expect(port.previews, 0);
      expect(
        find.byKey(const Key('confirm-recovery-replacement')),
        findsNothing,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('select-recovery-backup')),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'cancelled final replacement releases fresh ready input and never activates',
    (tester) async {
      final ready = Candidate();
      final port = Port()..selection = Review(ready);
      await Host(port).open(tester);
      await select(tester);
      await tap(tester, 'revalidate-backup-time');
      // The parent operation remains busy while awaiting this modal choice.
      await tester.pump(const Duration(milliseconds: 350));
      await tap(tester, 'cancel-recovery-replacement');
      await tester.pumpAndSettle();
      expect(ready.disposed, isTrue);
      expect(port.activations, isEmpty);
    },
  );

  testWidgets(
    'Recovery recurrence confirmation waits for whole validation and separate replacement',
    (tester) async {
      final ready = Candidate();
      final review = RecurringReview(ready)
        ..pendingFullValidation = Completer();
      final port = Port()..selection = review;
      await Host(port).open(tester);
      await select(tester);
      await tap(tester, 'backup-time-issue-rule-1');
      await tap(tester, 'backup-time-recurrence');
      expect(find.byType(BackupRecurringTimeReviewScreen), findsOneWidget);
      await recurring.tap(tester, 'review-backup-recurrence');
      expect(port.activations, isEmpty);
      expect(review.fullValidations, 0);
      await recurring.confirm(tester);
      expect(review.choices, hasLength(1));
      expect(review.fullValidations, 1);
      expect(port.activations, isEmpty);
      expect(
        find.byKey(const Key('confirm-recovery-replacement')),
        findsNothing,
      );
      review.pendingFullValidation!.complete(ready);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        find.byKey(const Key('confirm-recovery-replacement')),
        findsOneWidget,
      );
      expect(port.activations, isEmpty);
      await tap(tester, 'confirm-recovery-replacement');
      await tester.pumpAndSettle();
      expect(port.activations, [ready]);
      expect(ready.disposed, isTrue);
    },
  );

  testWidgets(
    'canceling Recovery recurrence returns to parent with no candidate edit or activation',
    (tester) async {
      final review = RecurringReview(Candidate());
      final port = Port()..selection = review;
      await Host(port).open(tester);
      await select(tester);
      await tap(tester, 'backup-time-issue-rule-1');
      await tap(tester, 'backup-time-recurrence');
      await recurring.tap(tester, 'cancel-backup-recurrence');
      // The parent stays busy during review, so settle only the route return.
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(BackupTimeReviewScreen), findsOneWidget);
      expect(review.fullValidations, 1);
      expect(review.choices, isEmpty);
      expect(review.disposals, 0);
      expect(port.activations, isEmpty);
      await tap(tester, 'cancel-backup-time');
      await tester.pumpAndSettle();
      expect(review.disposals, greaterThan(0));
      expect(port.activations, isEmpty);
    },
  );

  testWidgets(
    'failed whole validation after recurrence change cannot show replacement confirmation',
    (tester) async {
      final review = RecurringReview(Candidate())
        ..validationFailure = StateError('private relation failure');
      final port = Port()..selection = review;
      await Host(port).open(tester);
      await select(tester);
      await tap(tester, 'backup-time-issue-rule-1');
      await tap(tester, 'backup-time-recurrence');
      await recurring.tap(tester, 'review-backup-recurrence');
      await recurring.confirm(tester);
      expect(review.choices, hasLength(1));
      expect(review.fullValidations, 1);
      expect(find.byType(BackupTimeReviewScreen), findsOneWidget);
      expect(
        find.byKey(const Key('confirm-recovery-replacement')),
        findsNothing,
      );
      expect(port.activations, isEmpty);
      expect(find.textContaining('private relation failure'), findsNothing);
      await tap(tester, 'cancel-backup-time');
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'Recovery recurrence route receives the current owner returned by revalidation',
    (tester) async {
      final old = RecurringReview(Candidate());
      final next = RecurringReview(Candidate());
      old.replacement = next;
      final port = Port()..selection = old;
      await Host(port).open(tester);
      await select(tester);
      await tap(tester, 'revalidate-backup-time');
      await tap(tester, 'backup-time-issue-rule-1');
      await tap(tester, 'backup-time-recurrence');
      await recurring.tap(tester, 'review-backup-recurrence');
      expect(old.drafts, isEmpty);
      expect(next.drafts, hasLength(1));
      await recurring.tap(tester, 'cancel-backup-recurrence');
      await tap(tester, 'cancel-backup-time');
      await tester.pumpAndSettle();
      expect(port.activations, isEmpty);
    },
  );

  testWidgets(
    'preclaim cleanup failure retains same owner and retries only cleanup',
    (tester) async {
      final candidate = Candidate();
      final port = Port()
        ..selection = candidate
        ..activationFailure = staleAfterCleanup
        ..cleanupFailures = 1;
      final host = Host(port);
      await host.open(tester);
      await activate(tester);
      expect(candidate.disposed, isTrue);
      expect(find.textContaining('The backup was not applied'), findsOneWidget);
      expect(find.text('Continue recovery'), findsNothing);
      expect(find.text('Stop this recovery'), findsNothing);
      expect(find.byKey(const Key('select-recovery-backup')), findsNothing);
      await tap(tester, 'retry-recovery-preclaim-cleanup');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('retry-recovery-preclaim-cleanup')),
        findsOneWidget,
      );
      expect(find.textContaining('private cleanup'), findsNothing);
      await tap(tester, 'retry-recovery-preclaim-cleanup');
      await tester.pumpAndSettle();
      expect(port.cleanupGenerations, [7, 7]);
      expect(port.activations, [candidate]);
      expect(host.factories, 1);
      expect(port.resumes, 0);
      expect(port.aborts, 0);
      expect(host.completed, 0);
      expect(host.exited, 0);
      expect(find.byKey(const Key('select-recovery-backup')), findsOneWidget);
    },
  );

  testWidgets(
    'preclaim retry remains single flight while native cleanup is pending',
    (tester) async {
      final pending = Completer<void>();
      final port = Port()
        ..selection = Candidate()
        ..activationFailure = staleAfterCleanup
        ..pendingCleanup = pending;
      await Host(port).open(tester);
      await activate(tester);
      await tap(tester, 'retry-recovery-preclaim-cleanup');
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('retry-recovery-preclaim-cleanup')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(
        find.byKey(const Key('retry-recovery-preclaim-cleanup')),
      );
      await tester.pump();
      expect(port.cleanupGenerations, [7]);
      expect(port.activations.length, 1);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('select-recovery-backup')), findsOneWidget);
    },
  );

  testWidgets(
    'candidate cleanup failure blocks another selection and offers local retry',
    (tester) async {
      final candidate = Candidate()..releaseFailures = 1;
      final port = Port()..selection = candidate;
      await Host(port).open(tester);
      await select(tester);
      await tap(tester, 'cancel-recovery-replacement');
      await tester.pumpAndSettle();
      expect(candidate.disposed, isFalse);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('select-recovery-backup')),
            )
            .onPressed,
        isNull,
      );
      expect(find.textContaining('private file'), findsNothing);
      await tap(tester, 'retry-recovery-candidate-cleanup');
      await tester.pumpAndSettle();
      expect(candidate.disposed, isTrue);
      expect(port.selections, 1);
      expect(port.activations, isEmpty);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('select-recovery-backup')),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'late picker result after screen removal is disposed without activation',
    (tester) async {
      final pending = Completer<BackupRestoreSelection?>();
      final port = Port()..pendingSelection = pending;
      await Host(port).open(tester);
      await select(tester);
      await tester.pumpWidget(const MaterialApp(home: Text('Removed')));
      final candidate = Candidate();
      pending.complete(candidate);
      await tester.pumpAndSettle();
      expect(candidate.disposed, isTrue);
      expect(port.activations, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final locale in ['ko', 'en']) {
    testWidgets(
      '$locale preclaim state is usable at narrow width with large text',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 568));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final port = Port()
          ..selection = Candidate()
          ..activationFailure = staleAfterCleanup;
        await Host(port).open(tester, locale: locale, scale: 2.5);
        await activate(tester, locale: locale);
        await tap(tester, 'retry-recovery-preclaim-cleanup');
        await tester.pumpAndSettle();
        expect(port.cleanupGenerations, [7]);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
