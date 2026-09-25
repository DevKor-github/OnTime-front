import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/backup_recurring_time_review.dart';
import 'package:on_time_front/domain/entities/backup_restore_selection.dart';
import 'package:on_time_front/domain/entities/backup_time_review.dart';
import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_time_resolution.dart';
import 'package:on_time_front/domain/entities/time_correction_conflict.dart';
import 'package:on_time_front/domain/recurrence/recurrence_engine.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'package:on_time_front/domain/recurrence/recurring_time_correction.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/backup/backup_recurring_time_review_screen.dart';

final start = DateTime.utc(2031, 1, 1, 9);
final sourceRule = RecurrenceRule(
  frequency: RecurrenceFrequency.daily,
  start: start,
  timeZoneId: 'UTC',
  count: 3,
);
final sourceIssue = BackupTimeReviewIssue(
  id: 'rule-1',
  kind: BackupTimeFieldKind.recurrenceRule,
  reason: BackupTimeIssueReason.recurrenceOrder,
  fieldPath: 'recurring.segments[0].ruleJson',
  name: 'Morning',
  originalLiteral: 'opaque source',
  currentLiteral: 'opaque source',
  civil: CivilDateTime.fromFields(start),
  zone: 'UTC',
);
ScheduleEntity schedule(String id) => ScheduleEntity(
  id: id,
  place: const PlaceEntity(id: 'place', placeName: 'Home'),
  scheduleName: 'Appointment $id',
  scheduleTime: start,
  occurrenceOffsetSeconds: 0,
  moveTime: Duration.zero,
  isChanged: false,
  isStarted: false,
  scheduleSpareTime: Duration.zero,
  scheduleNote: '',
);
final slot = RecurrenceSlot(
  civilTime: start,
  instantUtc: start,
  offsetSeconds: 0,
  ordinal: 1,
);
const tombstone = TimeCorrectionExclusion(
  'old-segment',
  '2031-01-02T09:00:00.000',
  2,
);
const tombstoneKey = 'old-segment\n2031-01-02T09:00:00.000';

class Candidate extends BackupTimeReviewInput
    implements BackupRecurringTimeReviewPort {
  Candidate(this.identity);
  final String identity;
  int disposals = 0, validations = 0, revision = 0;
  final drafts = <BackupRecurringTimeDraft>[];
  final choices = <BackupRecurringTimeChoice>[];
  bool wholeRequired = false,
      impacts = false,
      knownConflict = false,
      persistent = false,
      unresolved = false,
      empty = false;
  int possibleCount = 0;
  Completer<RecurrenceRule>? pendingSeed;
  Completer<BackupRecurringTimePlan>? pendingPlan;
  Completer<void>? pendingChoice;
  @override
  BackupTimeReviewSummary get summary => BackupTimeReviewSummary(
    identity: identity,
    revision: revision,
    validationNowUtc: DateTime.utc(2030),
    rulesIdentity: 'rules-v1',
    issueCount: 1,
    independentStructureChecked: true,
  );
  @override
  Future<RecurrenceRule> recurrenceRule(String issueId) async {
    expect(issueId, sourceIssue.id);
    return pendingSeed?.future ?? sourceRule;
  }

  BackupRecurringTimePlan plan(BackupRecurringTimeDraft draft) =>
      BackupRecurringTimePlan(
        draft: draft,
        issue: sourceIssue,
        anchor: BackupRecurringTimeAnchor(
          segmentId: 'old-segment',
          originalSlot: start,
          scheduleId: empty ? null : 'anchor',
          originalOrdinal: empty ? null : 1,
        ),
        originalRule: sourceRule,
        originalSchedule: schedule('anchor'),
        originalFrom: start,
        originalBefore: null,
        closeAt: start,
        mapping: RecurringTimeCorrectionMapping(
          rule: draft.rule,
          automaticallyRetainedCount: false,
          rows: impacts
              ? [TimeCorrectionRowMapping(schedule('detached'), null)]
              : [],
          protectedRows: [],
          exclusions: impacts
              ? [const TimeCorrectionExclusionMapping(tombstone, null)]
              : [],
          protectedSlots: [],
          workUnits: 1,
          firstSlot: slot,
        ),
        conflicts: TimeCorrectionConflictProof(
          conflicts:
              knownConflict && !draft.excludedConflictSlots.contains(slot.key)
              ? [
                  TimeCorrectionConflict(
                    slot: slot,
                    other: TimeCorrectionBusyInterval(
                      schedule('other'),
                      start.subtract(const Duration(minutes: 30)),
                      start,
                    ),
                    persistent: persistent,
                  ),
                ]
              : [],
          possibleOverlaps: [
            for (var i = 0; i < possibleCount; i++)
              TimeCorrectionPossibleOverlap(
                id: 'possible-$i',
                name: 'Uncertain appointment $i',
                reason: 'unknown zone',
                originalCivil: start,
                timeZoneId: 'Removed/Zone',
              ),
          ],
          through: start.add(const Duration(days: 3)),
          workUnits: 1,
          earliestPreparationUtc: start,
        ),
        unresolvedOverrides: unresolved
            ? {'override': ScheduleTimeResolutionStatus.unknownZone}
            : {},
      );
  @override
  Future<BackupRecurringTimePlan> reviewRecurrence(
    BackupRecurringTimeDraft draft,
  ) async {
    drafts.add(draft);
    if (wholeRequired && !draft.replaceWholeSourceInterval) {
      throw const BackupRecurringWholeReplacementRequired();
    }
    return pendingPlan?.future ?? plan(draft);
  }

  @override
  Future<void> chooseRecurrence(BackupRecurringTimeChoice choice) async {
    choices.add(choice);
    if (pendingChoice != null) await pendingChoice!.future;
    revision++;
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }

  @override
  Future<BackupRestoreSelection> revalidate() async {
    validations++;
    return this;
  }

  @override
  Future<BackupTimeReviewIssuePage> issues({String? cursor}) async =>
      BackupTimeReviewIssuePage([sourceIssue]);
  @override
  Future<BackupTimeFieldReview> review(BackupTimeDraft draft) =>
      throw StateError('scalar review not expected');
  @override
  Future<void> choose(BackupTimeChoice choice) =>
      throw StateError('scalar choice not expected');
}

class Host {
  final navigator = GlobalKey<NavigatorState>();
  late ValueNotifier<Candidate> current;
  bool returned = false;
  Future<void> open(
    WidgetTester tester,
    Candidate candidate, {
    Locale locale = const Locale('en'),
    double scale = 1,
  }) async {
    current = ValueNotifier(candidate);
    addTearDown(current.dispose);
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
        home: const Scaffold(body: Text('Parent')),
      ),
    );
    navigator.currentState!
        .push<void>(
          MaterialPageRoute(
            builder: (_) => ValueListenableBuilder<Candidate>(
              valueListenable: current,
              builder: (_, input, _) => BackupRecurringTimeReviewScreen(
                input: input,
                issue: sourceIssue,
              ),
            ),
          ),
        )
        .then((_) => returned = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }
}

Future<void> reveal(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  if (finder.evaluate().isEmpty) {
    // A previous plan can scroll the earlier review button out of the lazy
    // viewport. Search from the beginning rather than past the bottom.
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pump();
  }
  await tester.scrollUntilVisible(
    finder,
    220,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 80,
  );
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pump();
}

Future<void> tap(WidgetTester tester, String key) async {
  await reveal(tester, key);
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> expectChoose(WidgetTester tester, bool enabled) async {
  await reveal(tester, 'choose-backup-recurrence');
  expect(
    tester
        .widget<FilledButton>(find.byKey(const Key('choose-backup-recurrence')))
        .onPressed,
    enabled ? isNotNull : isNull,
  );
}

Future<void> confirm(WidgetTester tester) async {
  await tap(tester, 'choose-backup-recurrence');
  await tester.tap(find.byKey(const Key('confirm-backup-recurrence-choice')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  setUp(() {
    WidgetController.hitTestWarningShouldBeFatal = true;
  });
  tearDown(() {
    WidgetController.hitTestWarningShouldBeFatal = false;
  });

  testWidgets(
    'read and cancel borrow ownership without staging or full validation',
    (tester) async {
      final input = Candidate('one');
      final host = Host();
      await host.open(tester, input);
      expect(input.drafts, isEmpty);
      expect(input.choices, isEmpty);
      await tap(tester, 'cancel-backup-recurrence');
      expect(host.returned, isTrue);
      expect(input.disposals, 0);
      expect(input.validations, 0);
    },
  );
  testWidgets('preview and canceled confirmation never change candidate', (
    tester,
  ) async {
    final input = Candidate('one');
    final host = Host();
    await host.open(tester, input);
    await tap(tester, 'review-backup-recurrence');
    expect(input.drafts.single.endExplicitlyChosen, isFalse);
    expect(input.drafts.single.rule.repeatedTime, isNull);
    expect(input.choices, isEmpty);
    await tap(tester, 'choose-backup-recurrence');
    host.navigator.currentState!.pop(false);
    await tester.pumpAndSettle();
    expect(input.choices, isEmpty);
    expect(host.returned, isFalse);
    expect(input.disposals, 0);
  });
  testWidgets(
    'explicit confirm changes candidate only and returns borrowed owner',
    (tester) async {
      final input = Candidate('one');
      final host = Host();
      await host.open(tester, input);
      await tap(tester, 'review-backup-recurrence');
      await confirm(tester);
      expect(input.choices, hasLength(1));
      expect(input.choices.single.plan.draft.identity, 'one');
      expect(host.returned, isTrue);
      expect(input.disposals, 0);
      expect(input.validations, 0);
    },
  );
  testWidgets(
    'whole source request and actual impact acknowledgement are separate explicit choices',
    (tester) async {
      final input = Candidate('one')..wholeRequired = true;
      final host = Host();
      await host.open(tester, input);
      await tap(tester, 'review-backup-recurrence');
      await reveal(tester, 'request-backup-recurrence-whole');
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('request-backup-recurrence-whole')),
            )
            .value,
        isFalse,
      );
      expect(input.choices, isEmpty);
      await tap(tester, 'request-backup-recurrence-whole');
      await tap(tester, 'review-backup-recurrence');
      expect(input.drafts.last.replaceWholeSourceInterval, isTrue);
      await expectChoose(tester, false);
      await tap(tester, 'confirm-backup-recurrence-whole');
      await expectChoose(tester, true);
      await confirm(tester);
      expect(input.choices.single.confirmedWholeSourceReplacement, isTrue);
    },
  );
  testWidgets(
    'standalone, unmatched deletion and uncertainty require exact independent acknowledgement',
    (tester) async {
      final input = Candidate('one')
        ..impacts = true
        ..possibleCount = 2;
      await Host().open(tester, input);
      await tap(tester, 'review-backup-recurrence');
      await expectChoose(tester, false);
      await tap(tester, 'detached-detached');
      await expectChoose(tester, false);
      await tap(tester, 'exclusion-$tombstoneKey');
      await expectChoose(tester, false);
      await tap(tester, 'ack-backup-recurrence-possible');
      await expectChoose(tester, true);
      await tap(tester, 'detached-detached');
      await expectChoose(tester, false);
      await tap(tester, 'detached-detached');
      await confirm(tester);
      final choice = input.choices.single;
      expect(choice.confirmedDetachedIds, {'detached'});
      expect(choice.confirmedUnmatchedExclusions, {tombstoneKey});
      expect(choice.acknowledgedPossibleIds, {'possible-0', 'possible-1'});
    },
  );
  testWidgets('new plan resets all previous acknowledgements', (tester) async {
    final input = Candidate('one')
      ..impacts = true
      ..possibleCount = 1;
    await Host().open(tester, input);
    await tap(tester, 'review-backup-recurrence');
    await tap(tester, 'detached-detached');
    await tap(tester, 'exclusion-$tombstoneKey');
    await tap(tester, 'ack-backup-recurrence-possible');
    await expectChoose(tester, true);
    await tap(tester, 'review-backup-recurrence');
    await expectChoose(tester, false);
    for (final key in [
      'detached-detached',
      'exclusion-$tombstoneKey',
      'ack-backup-recurrence-possible',
    ]) {
      await reveal(tester, key);
      expect(
        tester.widget<CheckboxListTile>(find.byKey(Key(key))).value,
        isFalse,
      );
    }
    expect(input.choices, isEmpty);
  });
  testWidgets('finite conflict exclusion creates a fresh complete plan', (
    tester,
  ) async {
    final input = Candidate('one')
      ..knownConflict = true
      ..possibleCount = 1;
    await Host().open(tester, input);
    await tap(tester, 'review-backup-recurrence');
    await tap(tester, 'ack-backup-recurrence-possible');
    await expectChoose(tester, false);
    await tap(tester, 'exclude-backup-slot-${slot.key}');
    expect(input.drafts, hasLength(2));
    expect(input.drafts.last.excludedConflictSlots, {slot.key});
    await expectChoose(tester, false);
    await tap(tester, 'ack-backup-recurrence-possible');
    await expectChoose(tester, true);
    expect(input.choices, isEmpty);
  });
  testWidgets(
    'persistent conflict cannot be excluded and unresolved override returns parent without disposal',
    (tester) async {
      final input = Candidate('one')
        ..knownConflict = true
        ..persistent = true
        ..unresolved = true;
      final host = Host();
      await host.open(tester, input);
      await tap(tester, 'review-backup-recurrence');
      await expectChoose(tester, false);
      expect(find.byKey(Key('exclude-backup-slot-${slot.key}')), findsNothing);
      await tap(tester, 'resolve-override');
      expect(host.returned, isTrue);
      expect(input.disposals, 0);
      expect(input.choices, isEmpty);
    },
  );
  testWidgets(
    'zero materialized anchor reports zero without inventing an ordinal',
    (tester) async {
      final input = Candidate('one')..empty = true;
      await Host().open(tester, input);
      await tap(tester, 'review-backup-recurrence');
      await reveal(tester, 'choose-backup-recurrence');
      expect(find.textContaining('0 existing appointments'), findsOneWidget);
      expect(find.textContaining('#null'), findsNothing);
      expect(input.drafts.single.endExplicitlyChosen, isFalse);
    },
  );
  testWidgets('late source read cannot replace a different candidate', (
    tester,
  ) async {
    final old = Candidate('old')..pendingSeed = Completer();
    final next = Candidate('next');
    final host = Host();
    await host.open(tester, old);
    host.current.value = next;
    await tester.pump();
    await tester.pump();
    old.pendingSeed!.complete(sourceRule.withTimeZone('Removed/Zone'));
    await tester.pump();
    await tap(tester, 'review-backup-recurrence');
    expect(next.drafts.single.rule.timeZoneId, 'UTC');
    expect(old.drafts, isEmpty);
  });
  testWidgets(
    'late review plan cannot enable replacement candidate confirmation',
    (tester) async {
      final old = Candidate('old')..pendingPlan = Completer();
      final next = Candidate('next');
      final host = Host();
      await host.open(tester, old);
      await tap(tester, 'review-backup-recurrence');
      host.current.value = next;
      await tester.pump();
      await tester.pump();
      old.pendingPlan!.complete(old.plan(old.drafts.single));
      await tester.pump();
      expect(find.byKey(const Key('choose-backup-recurrence')), findsNothing);
      expect(old.choices, isEmpty);
      expect(next.choices, isEmpty);
    },
  );
  testWidgets(
    'confirmation opened by retired owner cannot submit to either candidate',
    (tester) async {
      final old = Candidate('old');
      final next = Candidate('next');
      final host = Host();
      await host.open(tester, old);
      await tap(tester, 'review-backup-recurrence');
      await tap(tester, 'choose-backup-recurrence');
      host.current.value = next;
      await tester.pump();
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('confirm-backup-recurrence-choice')),
      );
      await tester.pumpAndSettle();
      expect(old.choices, isEmpty);
      expect(next.choices, isEmpty);
      expect(host.returned, isFalse);
    },
  );
  testWidgets(
    'in-flight choice blocks back; its late completion cannot pop replacement',
    (tester) async {
      final old = Candidate('old')..pendingChoice = Completer();
      final next = Candidate('next');
      final host = Host();
      await host.open(tester, old);
      await tap(tester, 'review-backup-recurrence');
      await confirm(tester);
      await host.navigator.currentState!.maybePop();
      await tester.pump();
      expect(host.returned, isFalse);
      host.current.value = next;
      await tester.pump();
      await tester.pump();
      old.pendingChoice!.complete();
      await tester.pumpAndSettle();
      expect(host.returned, isFalse);
      expect(old.choices, hasLength(1));
      expect(next.choices, isEmpty);
      expect(old.disposals, 0);
    },
  );
  for (final locale in ['ko', 'en']) {
    testWidgets(
      '$locale large text small screen can review and confirm without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final input = Candidate('one');
        final host = Host();
        await host.open(tester, input, locale: Locale(locale), scale: 2.5);
        await tap(tester, 'review-backup-recurrence');
        await tap(tester, 'choose-backup-recurrence');
        final button = find.byKey(
          const Key('confirm-backup-recurrence-choice'),
        );
        await Scrollable.ensureVisible(tester.element(button), alignment: 0.5);
        await tester.pump();
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(host.returned, isTrue);
        expect(input.choices, hasLength(1));
      },
    );
  }
  testWidgets(
    'uncertain impact pagination retains exact acknowledgement for all records',
    (tester) async {
      final input = Candidate('one')..possibleCount = 11;
      await Host().open(tester, input);
      await tap(tester, 'review-backup-recurrence');
      await reveal(tester, 'backup-recurrence-possible-next');
      expect(find.textContaining('Uncertain appointment 10\n'), findsNothing);
      await tap(tester, 'backup-recurrence-possible-next');
      expect(find.textContaining('Uncertain appointment 10\n'), findsOneWidget);
      await tap(tester, 'ack-backup-recurrence-possible');
      await confirm(tester);
      expect(input.choices.single.acknowledgedPossibleIds, {
        for (var i = 0; i < 11; i++) 'possible-$i',
      });
    },
  );
}
