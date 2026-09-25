import 'dart:async';
import 'package:on_time_front/domain/entities/time_correction_conflict.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/recurrence/recurrence_engine.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/backup_operation.dart';
import 'package:on_time_front/domain/entities/backup_restore_selection.dart';
import 'package:on_time_front/domain/entities/backup_time_review.dart';
import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'package:on_time_front/domain/entities/civil_time_occurrence.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/backup/backup_time_review_screen.dart';

BackupTimeReviewIssue issue(String id, {bool recurrence = false}) =>
    BackupTimeReviewIssue(
      id: id,
      kind: recurrence
          ? BackupTimeFieldKind.recurrenceRule
          : BackupTimeFieldKind.scheduleOccurrence,
      reason: recurrence
          ? BackupTimeIssueReason.recurrenceOrder
          : BackupTimeIssueReason.changedOffset,
      fieldPath: 'schedules[0].scheduleTime',
      name: 'Appointment $id',
      originalLiteral: '2030-01-01T09:00:00.123456',
      currentLiteral: '2030-01-01T09:00:00.123456',
      civil: CivilDateTime.parse('2030-01-01T09:00:00.123456'),
      zone: 'UTC',
    );

class ReviewInput extends BackupTimeReviewInput {
  ReviewInput({List<BackupTimeReviewIssue>? items})
    : items = items ?? [issue('one')];
  final List<BackupTimeReviewIssue> items;
  final cursors = <String?>[];
  final drafts = <BackupTimeDraft>[];
  final choices = <BackupTimeChoice>[];
  int disposeCalls = 0, validateCalls = 0, failuresRemaining = 0;
  bool transferred = false, disposed = false, gap = false;
  Completer<BackupTimeReviewIssuePage>? pendingPage;
  Completer<BackupRestoreSelection>? pendingValidation;
  ReadyInput? ready;
  Map<int, TimeCorrectionConflictProof>? proofs;
  bool omitProof = false;
  List<int> offsets = [0];
  @override
  BackupTimeReviewSummary get summary => BackupTimeReviewSummary(
    identity: 'owner',
    revision: choices.length,
    validationNowUtc: DateTime.utc(2026),
    rulesIdentity: 'rules',
    issueCount: items.length,
    independentStructureChecked: true,
  );
  @override
  Future<BackupTimeReviewIssuePage> issues({String? cursor}) async {
    cursors.add(cursor);
    if (pendingPage != null) return pendingPage!.future;
    return BackupTimeReviewIssuePage([
      cursor == null ? items.first : items.last,
    ], nextCursor: cursor == null && items.length > 1 ? 'page-2' : null);
  }

  @override
  Future<BackupTimeFieldReview> review(BackupTimeDraft draft) async {
    drafts.add(draft);
    return BackupTimeFieldReview(
      draft: draft,
      issue: items.firstWhere((i) => i.id == draft.issueId),
      choices: gap
          ? []
          : [
              for (final offset in offsets)
                CivilTimeOccurrence(
                  offsetSeconds: offset,
                  instantUtc: draft.civil.atOffset(offset),
                ),
            ],
      conflictsByOffset: omitProof
          ? {}
          : {
              for (final offset in offsets)
                offset:
                    proofs?[offset] ??
                    TimeCorrectionConflictProof(
                      conflicts: [],
                      through: draft.civil.toUtcCarrier(),
                      workUnits: 1,
                    ),
            },
      nextValidCivil: gap
          ? CivilDateTime.parse('2030-01-01T10:00:00.123456')
          : null,
    );
  }

  @override
  Future<void> choose(BackupTimeChoice choice) async {
    choices.add(choice);
  }

  @override
  Future<BackupRestoreSelection> revalidate() async {
    validateCalls++;
    if (pendingValidation != null) return pendingValidation!.future;
    if (ready != null) {
      transferred = true;
      return ready!;
    }
    return this;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    if (transferred || disposed) return;
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw StateError('private staging path');
    }
    disposed = true;
  }
}

class ReadyInput extends BackupRestoreInput {
  bool disposed = false;
  @override
  BackupRestorePreview get preview => BackupRestorePreview(
    cutoff: DateTime.utc(2026),
    sourceAppVersion: 'test',
    sourcePlatform: 'test',
    scheduleCount: 1,
    templateCount: 0,
    defaultPreparationStepCount: 0,
  );
  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

class RouteHost {
  final navigator = GlobalKey<NavigatorState>();
  BackupRestoreInput? result;
  bool completed = false;
  Future<void> open(
    WidgetTester tester,
    ReviewInput input, {
    Locale locale = const Locale('en'),
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const Scaffold(body: Text('Home')),
      ),
    );
    navigator.currentState!
        .push<BackupRestoreInput?>(
          MaterialPageRoute(
            builder: (_) => BackupTimeReviewScreen(input: input),
          ),
        )
        .then((value) {
          result = value;
          completed = true;
        });
    await tester.pumpAndSettle();
  }
}

Future<void> tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 40,
  );
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> chooseOffset(WidgetTester tester) async {
  await tap(tester, 'backup-time-issue-one');
  await tap(tester, 'review-backup-time-field');
  expect(
    tester
        .widget<FilledButton>(find.byKey(const Key('choose-backup-time-field')))
        .onPressed,
    isNull,
  );
  await tap(tester, 'backup-time-offset-0');
  await tap(tester, 'choose-backup-time-field');
}

TimeCorrectionConflictProof possibleProof(String id) =>
    TimeCorrectionConflictProof(
      conflicts: [],
      through: DateTime.utc(2030, 1, 1, 9),
      workUnits: 1,
      possibleOverlaps: [
        TimeCorrectionPossibleOverlap(
          id: id,
          name: 'Uncertain $id',
          reason: 'unknownZone',
          originalCivil: DateTime.utc(2030, 1, 1, 9),
          timeZoneId: 'Old/Unavailable',
        ),
      ],
    );

TimeCorrectionConflictProof knownProof() {
  final when = DateTime.utc(2030, 1, 1, 9);
  final schedule = ScheduleEntity(
    id: 'other',
    place: const PlaceEntity(id: 'place', placeName: 'Office'),
    scheduleName: 'Other meeting',
    scheduleNote: '',
    scheduleTime: when,
    timeZoneId: 'UTC',
    occurrenceOffsetSeconds: 0,
    moveTime: Duration.zero,
    scheduleSpareTime: Duration.zero,
    isChanged: false,
    isStarted: false,
  );
  return TimeCorrectionConflictProof(
    conflicts: [
      TimeCorrectionConflict(
        slot: RecurrenceSlot(
          civilTime: when,
          instantUtc: when,
          offsetSeconds: 0,
          ordinal: 1,
        ),
        other: TimeCorrectionBusyInterval(
          schedule,
          when.subtract(const Duration(minutes: 30)),
          when,
        ),
      ),
    ],
    through: when,
    workUnits: 1,
  );
}

Future<void> reviewOffset(WidgetTester tester) async {
  await tap(tester, 'backup-time-issue-one');
  await tap(tester, 'review-backup-time-field');
  await tap(tester, 'backup-time-offset-0');
}

void main() {
  setUp(() {
    WidgetController.hitTestWarningShouldBeFatal = true;
  });
  tearDown(() {
    WidgetController.hitTestWarningShouldBeFatal = false;
  });
  testWidgets('a queued ready navigation cannot pop a replacement owner', (
    tester,
  ) async {
    final pending = Completer<BackupRestoreSelection>();
    final old = ReviewInput()..pendingValidation = pending;
    final replacement = ReviewInput(items: [issue('new')]);
    final selected = ValueNotifier<BackupTimeReviewInput>(old);
    addTearDown(selected.dispose);
    final navigator = GlobalKey<NavigatorState>();
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: Text('Home')),
      ),
    );
    navigator.currentState!
        .push<BackupRestoreInput?>(
          MaterialPageRoute(
            builder: (_) => ValueListenableBuilder<BackupTimeReviewInput>(
              valueListenable: selected,
              builder: (_, input, _) => BackupTimeReviewScreen(input: input),
            ),
          ),
        )
        .then((_) => completed = true);
    await tester.pumpAndSettle();
    await tap(tester, 'revalidate-backup-time');
    final ready = ReadyInput();
    old.transferred = true;
    pending.complete(ready);
    await tester.idle();
    selected.value = replacement;
    await tester.pumpAndSettle();
    expect(completed, isFalse);
    expect(ready.disposed, isTrue);
    expect(find.byKey(const Key('backup-time-issue-new')), findsOneWidget);
    expect(replacement.disposed, isFalse);
  });
  testWidgets(
    'legacy instant keeps civil fields read only and does not require an appointment conflict proof',
    (tester) async {
      final original = issue('one');
      final input = ReviewInput(
        items: [
          BackupTimeReviewIssue(
            id: 'one',
            kind: BackupTimeFieldKind.templateCreatedAt,
            reason: BackupTimeIssueReason.missingInstantOffset,
            fieldPath: 'templates[0].createdAt',
            name: 'Template created',
            originalLiteral: original.originalLiteral,
            currentLiteral: original.currentLiteral,
            civil: original.civil,
            zone: 'UTC',
          ),
        ],
      )..omitProof = true;
      await RouteHost().open(tester, input);
      await tap(tester, 'backup-time-issue-one');
      expect(find.byKey(const Key('backup-time-date')), findsNothing);
      expect(find.byKey(const Key('backup-time-clock')), findsNothing);
      await tap(tester, 'review-backup-time-field');
      await tap(tester, 'backup-time-offset-0');
      await tap(tester, 'choose-backup-time-field');
      await tester.tap(find.byKey(const Key('confirm-backup-time-choice')));
      await tester.pumpAndSettle();
      expect(input.choices.single.review.draft.civil, original.civil);
      expect(input.choices.single.acknowledgedPossibleIds, isEmpty);
      expect(input.validateCalls, 1);
    },
  );

  testWidgets('missing overlap proof never enables schedule selection', (
    tester,
  ) async {
    final input = ReviewInput()..omitProof = true;
    await RouteHost().open(tester, input);
    await reviewOffset(tester);
    expect(find.byKey(const Key('backup-time-missing-proof')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('choose-backup-time-field')),
          )
          .onPressed,
      isNull,
    );
    expect(input.choices, isEmpty);
  });

  testWidgets('known conflict shows affected appointment and blocks choice', (
    tester,
  ) async {
    final input = ReviewInput()..proofs = {0: knownProof()};
    await RouteHost().open(tester, input);
    await reviewOffset(tester);
    expect(find.textContaining('Other meeting'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('choose-backup-time-field')),
          )
          .onPressed,
      isNull,
    );
    expect(input.choices, isEmpty);
    expect(input.validateCalls, 0);
  });

  testWidgets(
    'possible overlap requires an unchecked acknowledgement and sends exact reviewed IDs',
    (tester) async {
      final input = ReviewInput()..proofs = {0: possibleProof('uncertain-a')};
      await RouteHost().open(tester, input);
      await reviewOffset(tester);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('backup-time-possible-ack')),
            )
            .value,
        isFalse,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('choose-backup-time-field')),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('choose-backup-time-field')),
            )
            .onPressed,
        isNull,
      );
      await tap(tester, 'backup-time-possible-ack');
      await tap(tester, 'choose-backup-time-field');
      expect(input.choices, isEmpty);
      await tester.tap(find.byKey(const Key('confirm-backup-time-choice')));
      await tester.pumpAndSettle();
      expect(input.choices.single.acknowledgedPossibleIds, {'uncertain-a'});
      expect(input.validateCalls, 1);
      expect(find.byType(BackupTimeReviewScreen), findsOneWidget);
    },
  );

  testWidgets(
    'changing occurrence clears acknowledgement and uses only its own overlap proof',
    (tester) async {
      final input = ReviewInput()
        ..offsets = [0, 3600]
        ..proofs = {0: possibleProof('first'), 3600: possibleProof('second')};
      await RouteHost().open(tester, input);
      await reviewOffset(tester);
      await tap(tester, 'backup-time-possible-ack');
      await tap(tester, 'backup-time-offset-3600');
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('backup-time-possible-ack')),
            )
            .value,
        isFalse,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('choose-backup-time-field')),
            )
            .onPressed,
        isNull,
      );
      expect(find.textContaining('Uncertain second'), findsOneWidget);
      expect(find.textContaining('Uncertain first'), findsNothing);
      await tap(tester, 'backup-time-possible-ack');
      await tap(tester, 'choose-backup-time-field');
      await tester.tap(find.byKey(const Key('confirm-backup-time-choice')));
      await tester.pumpAndSettle();
      expect(input.choices.single.acknowledgedPossibleIds, {'second'});
      expect(input.choices.single.offsetSeconds, 3600);
    },
  );

  testWidgets(
    'replacing an input ignores its pending page and disposes its lease',
    (tester) async {
      final pending = Completer<BackupTimeReviewIssuePage>();
      final old = ReviewInput()..pendingPage = pending;
      final current = ReviewInput(items: [issue('new')]);
      final selected = ValueNotifier<BackupTimeReviewInput>(old);
      addTearDown(selected.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ValueListenableBuilder<BackupTimeReviewInput>(
            valueListenable: selected,
            builder: (_, input, _) => BackupTimeReviewScreen(input: input),
          ),
        ),
      );
      await tester.pump();
      selected.value = current;
      await tester.pumpAndSettle();
      expect(old.disposed, isTrue);
      expect(find.byKey(const Key('backup-time-issue-new')), findsOneWidget);
      pending.complete(BackupTimeReviewIssuePage([issue('obsolete')]));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('backup-time-issue-obsolete')), findsNothing);
      expect(find.byKey(const Key('backup-time-issue-new')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'confirmation from a replaced input cannot choose on either owner',
    (tester) async {
      final old = ReviewInput();
      final current = ReviewInput(items: [issue('new')]);
      final selected = ValueNotifier<BackupTimeReviewInput>(old);
      addTearDown(selected.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ValueListenableBuilder<BackupTimeReviewInput>(
            valueListenable: selected,
            builder: (_, input, _) => BackupTimeReviewScreen(input: input),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await chooseOffset(tester);
      selected.value = current;
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-backup-time-choice')));
      await tester.pumpAndSettle();
      expect(old.disposed, isTrue);
      expect(old.choices, isEmpty);
      expect(current.choices, isEmpty);
      expect(old.validateCalls, 0);
      expect(current.validateCalls, 0);
      expect(find.byKey(const Key('backup-time-issue-new')), findsOneWidget);
    },
  );

  testWidgets(
    'reading and cancelling never chooses or validates a replacement',
    (tester) async {
      final input = ReviewInput();
      final host = RouteHost();
      await host.open(tester, input);
      expect(find.textContaining('schedules[0]'), findsNothing);
      expect(input.choices, isEmpty);
      expect(input.validateCalls, 0);
      await tap(tester, 'cancel-backup-time');
      await tester.pumpAndSettle();
      expect(host.completed, isTrue);
      expect(host.result, isNull);
      expect(input.disposed, isTrue);
    },
  );

  testWidgets(
    'explicit occurrence and confirmation return fresh ready input without applying it',
    (tester) async {
      final ready = ReadyInput();
      final input = ReviewInput()..ready = ready;
      final host = RouteHost();
      await host.open(tester, input);
      await chooseOffset(tester);
      expect(input.choices, isEmpty);
      expect(input.validateCalls, 0);
      await tester.tap(find.byKey(const Key('confirm-backup-time-choice')));
      await tester.pumpAndSettle();
      expect(input.choices.single.offsetSeconds, 0);
      expect(input.validateCalls, 1);
      expect(host.result, same(ready));
      expect(ready.disposed, isFalse);
      expect(
        input.choices.single.review.draft.civil.toUtcCarrier().microsecond,
        456,
      );
    },
  );

  testWidgets('back from confirmation leaves original candidate untouched', (
    tester,
  ) async {
    final input = ReviewInput();
    await RouteHost().open(tester, input);
    await chooseOffset(tester);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(input.choices, isEmpty);
    expect(input.validateCalls, 0);
  });

  testWidgets(
    'gap suggestion only changes draft and requires another review and choice',
    (tester) async {
      final input = ReviewInput()..gap = true;
      await RouteHost().open(tester, input);
      await tap(tester, 'backup-time-issue-one');
      await tap(tester, 'review-backup-time-field');
      await tap(tester, 'backup-time-gap-proposal');
      expect(input.choices, isEmpty);
      expect(input.validateCalls, 0);
      expect(input.drafts.length, 1);
      input.gap = false;
      await tap(tester, 'review-backup-time-field');
      expect(input.drafts.last.civil.toUtcCarrier().hour, 10);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('choose-backup-time-field')),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'pagination requests bounded pages and restores previous cursor',
    (tester) async {
      final input = ReviewInput(items: [issue('one'), issue('two')]);
      await RouteHost().open(tester, input);
      await tap(tester, 'backup-time-next');
      expect(find.byKey(const Key('backup-time-issue-two')), findsOneWidget);
      await tap(tester, 'backup-time-previous');
      expect(find.byKey(const Key('backup-time-issue-one')), findsOneWidget);
      expect(input.cursors, [null, 'page-2', null]);
      expect(input.choices, isEmpty);
    },
  );

  testWidgets('cleanup failure retains screen and enables cleanup retry only', (
    tester,
  ) async {
    final input = ReviewInput()..failuresRemaining = 1;
    final host = RouteHost();
    await host.open(tester, input);
    await tap(tester, 'cancel-backup-time');
    expect(host.completed, isFalse);
    expect(input.disposed, isFalse);
    expect(find.textContaining('private staging path'), findsNothing);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('revalidate-backup-time')),
          )
          .onPressed,
      isNull,
    );
    await tap(tester, 'cancel-backup-time');
    await tester.pumpAndSettle();
    expect(input.disposed, isTrue);
    expect(host.completed, isTrue);
    expect(input.disposeCalls, greaterThanOrEqualTo(2));
  });

  testWidgets(
    'late ready result after cancellation is disposed and never returned',
    (tester) async {
      final pending = Completer<BackupRestoreSelection>();
      final input = ReviewInput()..pendingValidation = pending;
      final host = RouteHost();
      await host.open(tester, input);
      await tap(tester, 'revalidate-backup-time');
      await tap(tester, 'cancel-backup-time');
      await tester.pumpAndSettle();
      final ready = ReadyInput();
      pending.complete(ready);
      await tester.pumpAndSettle();
      expect(ready.disposed, isTrue);
      expect(host.completed, isTrue);
      expect(host.result, isNull);
    },
  );

  testWidgets(
    'unavailable recurrence editor cannot silently validate the issue as resolved',
    (tester) async {
      final input = ReviewInput(items: [issue('one', recurrence: true)]);
      await RouteHost().open(tester, input);
      await tap(tester, 'backup-time-issue-one');
      await tester.ensureVisible(
        find.byKey(const Key('backup-time-recurrence')),
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('backup-time-recurrence')),
            )
            .onPressed,
        isNull,
      );
      expect(input.choices, isEmpty);
      expect(input.validateCalls, 0);
    },
  );

  for (final language in ['ko', 'en']) {
    testWidgets('$language remains usable at narrow width and large text', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final input = ReviewInput();
      await RouteHost().open(
        tester,
        input,
        locale: Locale(language),
        scale: 2.5,
      );
      await tap(tester, 'backup-time-issue-one');
      await tap(tester, 'review-backup-time-field');
      await tap(tester, 'backup-time-offset-0');
      await tap(tester, 'choose-backup-time-field');
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.byKey(const Key('confirm-backup-time-choice')),
      );
      expect(find.byType(AlertDialog), findsOneWidget);
    });
  }
}
