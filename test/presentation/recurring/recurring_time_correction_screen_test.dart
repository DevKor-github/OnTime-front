import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/screens/schedule_edit_screen.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/time/schedule_time_resolution.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_save.dart';
import 'package:on_time_front/domain/entities/schedule_time_correction.dart';
import 'package:on_time_front/domain/entities/time_correction_conflict.dart';
import 'package:on_time_front/domain/recurrence/recurrence_engine.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
import 'package:on_time_front/domain/recurrence/recurring_time_correction.dart';
import 'package:on_time_front/domain/repositories/recurring_time_correction_repository.dart';
import 'package:on_time_front/domain/repositories/schedule_time_correction_repository.dart';
import 'package:on_time_front/domain/use-cases/recurring_time_correction_workflow.dart';
import 'package:on_time_front/domain/use-cases/schedule_time_correction_workflow.dart';
import 'package:on_time_front/domain/use-cases/schedule_mutation_alarm_effects_coordinator.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/recurring/recurring_time_correction_screen.dart';
import 'package:on_time_front/presentation/schedule_create/screens/schedule_time_correction_screen.dart';

final _civil = DateTime.utc(2030, 1, 2, 10);
const _preparation = PreparationEntity(preparationStepList: []);
ScheduleEntity _row(String id) => ScheduleEntity(
  id: id,
  place: const PlaceEntity(id: 'place', placeName: 'Office'),
  scheduleName: 'Meeting $id',
  scheduleTime: _civil,
  timeZoneId: 'UTC',
  occurrenceOffsetSeconds: 3600,
  isChanged: false,
  isStarted: false,
  moveTime: Duration.zero,
  scheduleSpareTime: Duration.zero,
  scheduleNote: '',
  recurringSegmentId: 'segment',
  recurringSlotKey: _civil.toIso8601String(),
  recurringOrdinal: 1,
  preparationDefinitionId: 'definition',
);
ScheduleTimeCorrectionReview _anchor(String id, {int revision = 1}) {
  final row = _row(id);
  final rule = RecurrenceRule(
    frequency: RecurrenceFrequency.daily,
    start: _civil,
    timeZoneId: 'UTC',
    count: 3,
  );
  return ScheduleTimeCorrectionReview(
    snapshot: ScheduleEditSnapshot(
      row,
      _preparation,
      ScheduleEditBaseline(
        store: 'store',
        generation: 0,
        revision: revision,
        incarnation: id,
        version: revision,
        rootId: 'segment',
        rootIncarnation: 'root',
        rootVersion: revision,
      ),
      segment: RecurringSegment(
        id: 'segment',
        seriesId: 'series',
        rule: rule,
        schedule: row,
        preparation: _preparation,
        preparationId: 'definition',
        fromSlot: _civil,
        createdAt: DateTime.utc(2029),
      ),
    ),
    resolution: ScheduleTimeResolver.resolve(row, nowUtc: DateTime.utc(2029)),
    ruleIdentity: 'test-rules',
    validationNowUtc: DateTime.utc(2029),
  );
}

RecurringTimeCorrectionReview _plan(
  RecurringTimeCorrectionRequest request, {
  bool acknowledgements = false,
  bool unresolved = false,
}) {
  final slot = RecurrenceSlot(
    civilTime: _civil,
    instantUtc: _civil,
    offsetSeconds: 0,
    ordinal: 1,
  );
  return RecurringTimeCorrectionReview(
    request: request,
    sourceDigest: 'source-${request.anchorReview.snapshot.baseline.revision}',
    mapping: RecurringTimeCorrectionMapping(
      rule: request.rule,
      automaticallyRetainedCount: true,
      rows: [
        TimeCorrectionRowMapping(_row('mapped'), slot),
        if (acknowledgements) TimeCorrectionRowMapping(_row('detached'), null),
      ],
      protectedRows: [],
      exclusions: acknowledgements
          ? [
              TimeCorrectionExclusionMapping(
                TimeCorrectionExclusion('segment', _civil.toIso8601String(), 1),
                null,
              ),
            ]
          : [],
      protectedSlots: [],
      firstSlot: slot,
      workUnits: 1,
    ),
    unresolvedOverrides: unresolved
        ? {'mapped': ScheduleTimeResolutionStatus.unknownZone}
        : {},
    conflictProof: TimeCorrectionConflictProof(
      conflicts: [],
      through: _civil,
      workUnits: 1,
      possibleOverlaps: acknowledgements
          ? [
              TimeCorrectionPossibleOverlap(
                id: 'uncertain',
                name: 'Uncertain appointment',
                reason: 'unknownZone',
                originalCivil: _civil,
                timeZoneId: 'Old/Zone',
              ),
            ]
          : [],
    ),
  );
}

class _Individual implements ScheduleTimeCorrectionRepository {
  final reads = <String>[];
  int revision = 1;
  final commands = <ScheduleTimeCorrectionCommand>[];
  @override
  Future<ScheduleTimeCorrectionReview> review(String id) async {
    reads.add(id);
    return _anchor(id, revision: revision);
  }

  @override
  Future<TimeCorrectionConflictProof> reviewChoice(
    ScheduleTimeCorrectionCommand command,
  ) async =>
      TimeCorrectionConflictProof(conflicts: [], through: _civil, workUnits: 0);
  @override
  Future<ScheduleSaveReceipt> confirm(
    ScheduleTimeCorrectionCommand command,
  ) async {
    commands.add(command);
    revision++;
    return ScheduleSaveReceipt(
      scheduleId: command.review.snapshot.schedule.id,
      mutationId: command.mutationId,
      generation: 0,
      changed: true,
    );
  }

  @override
  bool isCurrent(ScheduleSaveReceipt receipt) => true;
}

class _Repository implements RecurringTimeCorrectionRepository {
  final requests = <RecurringTimeCorrectionRequest>[];
  final commands = <RecurringTimeCorrectionCommand>[];
  Future<RecurringTimeCorrectionReview> Function(
    RecurringTimeCorrectionRequest,
  )?
  reader;
  bool acknowledgements = false, unresolved = false;
  Object? failure;
  @override
  Future<RecurringTimeCorrectionReview> review(
    RecurringTimeCorrectionRequest request,
  ) async {
    requests.add(request);
    return reader != null
        ? reader!(request)
        : _plan(
            request,
            acknowledgements: acknowledgements,
            unresolved: unresolved,
          );
  }

  @override
  Future<ScheduleSaveReceipt> confirm(
    RecurringTimeCorrectionCommand command,
  ) async {
    commands.add(command);
    if (failure != null) throw failure!;
    return ScheduleSaveReceipt(
      scheduleId: command.review.request.anchorReview.snapshot.schedule.id,
      mutationId: command.mutationId,
      generation: 0,
      changed: true,
    );
  }

  @override
  bool isCurrent(ScheduleSaveReceipt receipt) => true;
}

class _Effects extends Fake implements ScheduleMutationAlarmEffectsCoordinator {
  int calls = 0;
  bool complete = true;
  @override
  Future<bool> afterCommit() async {
    calls++;
    return complete;
  }
}

class _FormBloc extends Fake implements ScheduleFormBloc {
  _FormBloc(this.state);
  @override
  final ScheduleFormState state;
  final events = <ScheduleFormEvent>[];
  @override
  Stream<ScheduleFormState> get stream => const Stream.empty();
  @override
  void add(ScheduleFormEvent event) => events.add(event);
  @override
  Future<void> close() async {}
}

void main() {
  late _Repository repository;
  late _Individual individual;
  late _Effects effects;
  late RecurringTimeCorrectionWorkflow workflow;
  late ScheduleTimeCorrectionWorkflow individualWorkflow;
  var saved = 0;
  setUp(() {
    repository = _Repository();
    individual = _Individual();
    effects = _Effects();
    workflow = RecurringTimeCorrectionWorkflow(repository, effects);
    individualWorkflow = ScheduleTimeCorrectionWorkflow(individual, effects);
    saved = 0;
  });
  Future<void> pump(
    WidgetTester tester, {
    String id = 'one',
    bool settle = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: RecurringTimeCorrectionScreen(
            scheduleId: id,
            workflow: workflow,
            individualWorkflow: individualWorkflow,
            onSaved: () => saved++,
          ),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  Future<void> tapKey(
    WidgetTester tester,
    String key, {
    bool settle = true,
    bool? checkboxBefore,
  }) async {
    final finder = find.byKey(ValueKey(key));
    if (finder.evaluate().isEmpty) {
      // ListView lazily removes far-away controls. Reset only fixture scroll
      // position, then use real visible taps for every product action.
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pump();
      await tester.scrollUntilVisible(finder, 250, maxScrolls: 60);
    }
    await tester.ensureVisible(finder);
    await tester.pump();
    expect(finder.hitTestable(), findsOneWidget);
    if (checkboxBefore != null) {
      expect(tester.widget<CheckboxListTile>(finder).value, checkboxBefore);
    }
    await tester.tap(finder.hitTestable());
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  Future<void> buildPlan(WidgetTester tester) =>
      tapKey(tester, 'build-recurring-time-plan');
  Future<void> openConfirm(WidgetTester tester) async {
    await tapKey(tester, 'review-recurring-time-confirm');
    expect(
      find.byKey(const Key('confirm-recurring-time')).hitTestable(),
      findsOneWidget,
    );
  }

  Future<void> confirm(WidgetTester tester) async {
    await openConfirm(tester);
    await tester.tap(
      find.byKey(const Key('confirm-recurring-time')).hitTestable(),
    );
    await tester.pumpAndSettle();
  }

  Future<void> acknowledge(WidgetTester tester) async {
    await tapKey(tester, 'detached-detached');
    await tapKey(tester, 'exclusion-segment\n${_civil.toIso8601String()}');
    await tapKey(tester, 'ack-recurring-uncertain');
  }

  testWidgets(
    'plan review and cancelling the final dialog never save or reconcile',
    (tester) async {
      await pump(tester);
      await buildPlan(tester);
      expect(repository.requests, hasLength(1));
      expect(repository.commands, isEmpty);
      expect(effects.calls, 0);
      await openConfirm(tester);
      await tester.tap(find.text('Cancel').hitTestable());
      await tester.pumpAndSettle();
      expect(repository.commands, isEmpty);
      expect(effects.calls, 0);
      expect(saved, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('a newly built plan requires fresh exact acknowledgements', (
    tester,
  ) async {
    repository.acknowledgements = true;
    await pump(tester);
    await buildPlan(tester);
    await tapKey(tester, 'review-recurring-time-confirm');
    expect(find.byKey(const Key('confirm-recurring-time')), findsNothing);
    await acknowledge(tester);
    await buildPlan(tester);
    expect(repository.requests, hasLength(2));
    for (final key in [
      'detached-detached',
      'exclusion-segment\n${_civil.toIso8601String()}',
      'ack-recurring-uncertain',
    ]) {
      await tapKey(tester, key, checkboxBefore: false);
    }
    // Each set was independently reset. Withhold one again: the other two
    // acknowledgements cannot substitute for the missing uncertain-impact set.
    await tapKey(tester, 'ack-recurring-uncertain', checkboxBefore: true);
    await tapKey(tester, 'review-recurring-time-confirm');
    expect(find.byKey(const Key('confirm-recurring-time')), findsNothing);
    expect(repository.commands, isEmpty);
    expect(effects.calls, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'a late plan from the old schedule cannot become the new owner plan',
    (tester) async {
      final pending = Completer<RecurringTimeCorrectionReview>();
      repository.reader = (request) =>
          request.anchorReview.snapshot.schedule.id == 'one'
          ? pending.future
          : Future.value(_plan(request));
      await pump(tester);
      await tapKey(tester, 'build-recurring-time-plan', settle: false);
      final old = repository.requests.single;
      await pump(tester, id: 'two');
      pending.complete(_plan(old));
      await tester.pumpAndSettle();
      expect(find.text('Meeting two'), findsOneWidget);
      expect(
        find.byKey(const Key('review-recurring-time-confirm')),
        findsNothing,
      );
      await buildPlan(tester);
      await confirm(tester);
      expect(
        repository
            .commands
            .single
            .review
            .request
            .anchorReview
            .snapshot
            .schedule
            .id,
        'two',
      );
      expect(saved, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('accepting an old owner dialog cannot save either owner', (
    tester,
  ) async {
    await pump(tester);
    await buildPlan(tester);
    await openConfirm(tester);
    await pump(tester, id: 'two');
    await tester.tap(
      find.byKey(const Key('confirm-recurring-time')).hitTestable(),
    );
    await tester.pumpAndSettle();
    expect(repository.commands, isEmpty);
    expect(effects.calls, 0);
    expect(saved, 0);
    expect(find.text('Meeting two'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'uncertain save response retries the identical confirmed intent without rebuilding the plan',
    (tester) async {
      repository.failure = StateError('response unavailable');
      await pump(tester);
      await buildPlan(tester);
      await confirm(tester);
      expect(repository.commands, hasLength(1));
      expect(saved, 0);
      expect(effects.calls, 0);
      final original = repository.commands.single;
      repository.failure = null;
      await confirm(tester);
      expect(repository.requests, hasLength(1));
      expect(repository.commands, hasLength(2));
      expect(identical(repository.commands.last, original), isTrue);
      expect(repository.commands.last.mutationId, original.mutationId);
      expect(saved, 1);
      expect(effects.calls, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'pending notification synchronization retries effects without another save',
    (tester) async {
      effects.complete = false;
      await pump(tester);
      await buildPlan(tester);
      await confirm(tester);
      expect(repository.commands, hasLength(1));
      expect(saved, 0);
      expect(effects.calls, 1);
      final retry = find.text('Retry notification synchronization');
      await tester.scrollUntilVisible(retry, 250);
      expect(retry.hitTestable(), findsOneWidget);
      effects.complete = true;
      await tester.tap(retry.hitTestable());
      await tester.pumpAndSettle();
      expect(repository.commands, hasLength(1));
      expect(effects.calls, 2);
      expect(saved, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'a changed authority requires a fresh record instead of retrying a rejected command',
    (tester) async {
      repository.failure = const ScheduleSaveRejected(
        ScheduleSaveFailure.conflict,
      );
      await pump(tester);
      await buildPlan(tester);
      await confirm(tester);
      await tapKey(tester, 'review-recurring-time-confirm');
      expect(find.byKey(const Key('confirm-recurring-time')), findsNothing);
      expect(repository.commands, hasLength(1));
      individual.revision = 2;
      await tapKey(tester, 'reload-recurring-time');
      repository.failure = null;
      await buildPlan(tester);
      await confirm(tester);
      expect(
        repository
            .commands
            .last
            .review
            .request
            .anchorReview
            .snapshot
            .baseline
            .revision,
        2,
      );
      expect(
        repository.commands.last.mutationId,
        isNot(repository.commands.first.mutationId),
      );
      expect(saved, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'unresolved individual review blocks the plan and returning requires a fresh anchor',
    (tester) async {
      repository.unresolved = true;
      await pump(tester);
      await buildPlan(tester);
      await tapKey(tester, 'review-recurring-time-confirm');
      expect(find.byKey(const Key('confirm-recurring-time')), findsNothing);
      await tapKey(tester, 'resolve-mapped');
      expect(find.byType(ScheduleTimeCorrectionScreen), findsOneWidget);
      expect(individual.reads, ['one', 'mapped']);
      individual.revision = 2;
      // Back is cancellation; even then the old following review loses authority.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(individual.reads, ['one', 'mapped', 'one']);
      expect(
        find.byKey(const Key('review-recurring-time-confirm')),
        findsNothing,
      );
      repository.unresolved = false;
      await buildPlan(tester);
      await confirm(tester);
      expect(
        repository
            .commands
            .single
            .review
            .request
            .anchorReview
            .snapshot
            .baseline
            .revision,
        2,
      );
      expect(individual.commands, isEmpty);
      expect(saved, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final scope in RecurringEditScope.values) {
    testWidgets(
      'actual edit entry routes unresolved recurring $scope to the correct review',
      (tester) async {
        getIt.pushNewScope();
        addTearDown(getIt.popScope);
        final form = _FormBloc(
          ScheduleFormState(
            status: ScheduleFormStatus.success,
            id: 'one',
            originalSchedule: _anchor('one').snapshot.schedule,
            recurringScope: scope,
            mutationId: 'route-intent',
          ),
        );
        getIt.registerFactory<ScheduleFormBloc>(() => form);
        getIt.registerSingleton<RecurringTimeCorrectionWorkflow>(workflow);
        getIt.registerSingleton<ScheduleTimeCorrectionWorkflow>(
          individualWorkflow,
        );
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ScheduleEditScreen(scheduleId: 'one', scope: scope),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(RecurringTimeCorrectionScreen),
          scope == RecurringEditScope.following ? findsOneWidget : findsNothing,
        );
        expect(
          find.byType(ScheduleTimeCorrectionScreen),
          scope == RecurringEditScope.occurrence
              ? findsOneWidget
              : findsNothing,
        );
        final request = form.events
            .whereType<ScheduleFormEditRequested>()
            .single;
        expect(request.scheduleId, 'one');
        expect(request.scope, scope);
        expect(individual.reads, ['one']);
        expect(repository.commands, isEmpty);
        expect(individual.commands, isEmpty);
        expect(effects.calls, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
