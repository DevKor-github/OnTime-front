import 'package:on_time_front/domain/entities/time_correction_conflict.dart';
import 'dart:async';
import 'package:on_time_front/domain/recurrence/recurrence_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/time/schedule_time_resolution.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_save.dart';
import 'package:on_time_front/domain/entities/schedule_time_correction.dart';
import 'package:on_time_front/domain/repositories/schedule_time_correction_repository.dart';
import 'package:on_time_front/domain/use-cases/schedule_mutation_alarm_effects_coordinator.dart';
import 'package:on_time_front/domain/use-cases/schedule_time_correction_workflow.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/schedule_create/screens/schedule_time_correction_screen.dart';

class _Repository implements ScheduleTimeCorrectionRepository {
  final values = <String, ScheduleTimeCorrectionReview>{};
  final commands = <ScheduleTimeCorrectionCommand>[];
  Future<ScheduleTimeCorrectionReview> Function(String)? reader;
  Future<TimeCorrectionConflictProof> Function(ScheduleTimeCorrectionCommand)?
  choiceReader;
  ScheduleSaveFailure? failure;
  Object? error;
  @override
  Future<ScheduleTimeCorrectionReview> review(String id) async =>
      reader == null ? values[id]! : reader!(id);
  @override
  Future<TimeCorrectionConflictProof> reviewChoice(
    ScheduleTimeCorrectionCommand command,
  ) async => choiceReader != null
      ? choiceReader!(command)
      : TimeCorrectionConflictProof(
          conflicts: [],
          through: command.civil.toUtcCarrier(),
          workUnits: 0,
        );
  @override
  Future<ScheduleSaveReceipt> confirm(
    ScheduleTimeCorrectionCommand command,
  ) async {
    commands.add(command);
    if (error != null) throw error!;
    if (failure != null) throw ScheduleSaveRejected(failure!);
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

class _Effects extends Fake implements ScheduleMutationAlarmEffectsCoordinator {
  int calls = 0;
  bool complete = true;
  @override
  Future<bool> afterCommit() async {
    calls++;
    return complete;
  }
}

ScheduleTimeCorrectionReview _review({
  String id = 'one',
  String zone = 'UTC',
  DateTime? civil,
  int? offset = 3600,
  ScheduleSaveFailure? blockedBy,
}) {
  final schedule = ScheduleEntity(
    id: id,
    place: const PlaceEntity(id: 'place', placeName: 'Office'),
    scheduleName: 'Meeting $id',
    scheduleTime: civil ?? DateTime.utc(2030, 1, 2, 10, 0, 59, 123, 456),
    timeZoneId: zone,
    occurrenceOffsetSeconds: offset,
    moveTime: Duration.zero,
    isChanged: false,
    isStarted: false,
    scheduleSpareTime: Duration.zero,
    scheduleNote: 'Keep this note',
  );
  return ScheduleTimeCorrectionReview(
    snapshot: ScheduleEditSnapshot(
      schedule,
      const PreparationEntity(preparationStepList: []),
      const ScheduleEditBaseline(
        store: 'store',
        generation: 0,
        revision: 1,
        incarnation: 'row',
        version: 1,
      ),
    ),
    resolution: ScheduleTimeResolver.resolve(
      schedule,
      nowUtc: DateTime.utc(2029),
    ),
    ruleIdentity: 'test-rule',
    validationNowUtc: DateTime.utc(2029),
    blockedBy: blockedBy,
  );
}

void main() {
  late _Repository repository;
  late _Effects effects;
  late ScheduleTimeCorrectionWorkflow workflow;
  var saved = 0;
  setUp(() {
    repository = _Repository()..values['one'] = _review();
    effects = _Effects();
    workflow = ScheduleTimeCorrectionWorkflow(repository, effects);
    saved = 0;
  });
  Future<void> pump(
    WidgetTester tester, {
    String id = 'one',
    String locale = 'en',
    double scale = 1,
    bool settle = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(320, 568),
            textScaler: TextScaler.linear(scale),
          ),
          child: Scaffold(
            body: ScheduleTimeCorrectionScreen(
              scheduleId: id,
              workflow: workflow,
              onSaved: () => saved++,
            ),
          ),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  Future<void> openConfirmation(WidgetTester tester) async {
    final button = find.byKey(const Key('review-time-correction'));
    await tester.scrollUntilVisible(button, 300);
    await tester.pumpAndSettle();
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    expect(button.hitTestable(), findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('confirm-time-correction')), findsOneWidget);
  }

  Future<void> confirm(WidgetTester tester) async {
    await openConfirmation(tester);
    await tester.tap(find.byKey(const Key('confirm-time-correction')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'known conflicts show the other appointment and cannot open confirmation',
    (tester) async {
      final other = _review(id: 'other').snapshot.schedule;
      final at = other.scheduleTime;
      repository.choiceReader = (command) async => TimeCorrectionConflictProof(
        conflicts: [
          TimeCorrectionConflict(
            slot: RecurrenceSlot(
              civilTime: at,
              instantUtc: at,
              offsetSeconds: 0,
              ordinal: 1,
            ),
            other: TimeCorrectionBusyInterval(other, at, at),
          ),
        ],
        through: at,
        workUnits: 1,
      );
      await pump(tester);
      final button = find.byKey(const Key('review-time-correction'));
      await tester.scrollUntilVisible(button, 300);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('confirm-time-correction')), findsNothing);
      expect(find.textContaining('Meeting other'), findsOneWidget);
      expect(repository.commands, isEmpty);
    },
  );
  testWidgets(
    'uncertain same-name appointments show civil zone reason and require explicit acknowledgement',
    (tester) async {
      repository.choiceReader = (command) async => TimeCorrectionConflictProof(
        conflicts: [],
        through: command.civil.toUtcCarrier(),
        workUnits: 1,
        possibleOverlaps: [
          TimeCorrectionPossibleOverlap(
            id: 'first',
            name: 'Same name',
            reason: 'unknownZone',
            originalCivil: DateTime.utc(2030, 1, 2, 8),
            timeZoneId: 'Old/First',
          ),
          TimeCorrectionPossibleOverlap(
            id: 'second',
            name: 'Same name',
            reason: 'ambiguous',
            originalCivil: DateTime.utc(2030, 1, 2, 9),
            timeZoneId: 'Old/Second',
          ),
        ],
      );
      await pump(tester);
      await openConfirmation(tester);
      expect(find.textContaining('Old/First'), findsOneWidget);
      expect(find.textContaining('Old/Second'), findsOneWidget);
      expect(
        find.textContaining('The saved time zone is unavailable'),
        findsOneWidget,
      );
      expect(find.textContaining('This time occurs twice'), findsOneWidget);
      expect(
        find.textContaining('new starts and alarms remain on hold'),
        findsOneWidget,
      );
      expect(repository.commands, isEmpty);
      await tester.tap(find.byKey(const Key('confirm-time-correction')));
      await tester.pumpAndSettle();
      expect(repository.commands.single.acknowledgedUncertainIds, {
        'first',
        'second',
      });
    },
  );
  testWidgets(
    'late conflict review cannot open a modal for a replacement owner',
    (tester) async {
      final pending = Completer<TimeCorrectionConflictProof>();
      repository.values['two'] = _review(id: 'two');
      repository.choiceReader = (_) => pending.future;
      await pump(tester);
      final button = find.byKey(const Key('review-time-correction'));
      await tester.scrollUntilVisible(button, 300);
      await tester.tap(button);
      await tester.pump();
      await pump(tester, id: 'two');
      pending.complete(
        TimeCorrectionConflictProof(
          conflicts: [],
          through: DateTime.utc(2030),
          workUnits: 0,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('confirm-time-correction')), findsNothing);
      expect(find.text('Meeting two'), findsOneWidget);
      expect(repository.commands, isEmpty);
    },
  );

  testWidgets(
    'review and cancel never submit; explicit confirmation keeps precision',
    (tester) async {
      await pump(tester);
      expect(repository.commands, isEmpty);
      expect(find.textContaining('2030-01-02T10:00:59.123456Z'), findsWidgets);
      await openConfirmation(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.commands, isEmpty);
      await confirm(tester);
      expect(repository.commands, hasLength(1));
      final command = repository.commands.single;
      expect(
        command.civil.toUtcCarrier(),
        DateTime.utc(2030, 1, 2, 10, 0, 59, 123, 456),
      );
      expect(command.offsetSeconds, 0);
      expect(command.timeZoneId, 'UTC');
      expect(saved, 1);
      expect(effects.calls, 1);
    },
  );
  testWidgets('overlap requires explicit occurrence choice', (tester) async {
    repository.values['one'] = _review(
      zone: 'America/New_York',
      civil: DateTime.utc(2030, 11, 3, 1, 30),
      offset: null,
    );
    await pump(tester);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('review-time-correction')))
          .onPressed,
      isNull,
    );
    final option = find.byKey(const ValueKey('correction-offset--18000'));
    await tester.ensureVisible(option);
    await tester.tap(option);
    await tester.pumpAndSettle();
    expect(repository.commands, isEmpty);
    await confirm(tester);
    expect(repository.commands.single.offsetSeconds, -18000);
  });
  testWidgets('gap proposal only changes the draft until confirmation', (
    tester,
  ) async {
    repository.values['one'] = _review(
      zone: 'America/New_York',
      civil: DateTime.utc(2030, 3, 10, 2, 30),
      offset: null,
    );
    await pump(tester);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('review-time-correction')))
          .onPressed,
      isNull,
    );
    final proposal = find.byKey(const Key('correction-gap-proposal'));
    await tester.ensureVisible(proposal);
    await tester.tap(proposal);
    await tester.pumpAndSettle();
    expect(repository.commands, isEmpty);
    await confirm(tester);
    expect(
      repository.commands.single.civil.toUtcCarrier(),
      DateTime.utc(2030, 3, 10, 3),
    );
  });
  testWidgets('pending delivery retries only the owner and never resaves', (
    tester,
  ) async {
    effects.complete = false;
    await pump(tester);
    await confirm(tester);
    expect(repository.commands, hasLength(1));
    expect(saved, 0);
    expect(
      find.textContaining('Notification synchronization is still pending'),
      findsOneWidget,
    );
    effects.complete = true;
    final retry = find.text('Retry notification synchronization');
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(repository.commands, hasLength(1));
    expect(effects.calls, 2);
    expect(saved, 1);
  });
  testWidgets(
    'protected review explains the record and has no confirmation authority',
    (tester) async {
      repository.values['one'] = _review(
        blockedBy: ScheduleSaveFailure.protected,
      );
      await pump(tester);
      expect(
        find.textContaining('Running or historical records'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('review-time-correction')),
        300,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('review-time-correction')),
            )
            .onPressed,
        isNull,
      );
      expect(repository.commands, isEmpty);
    },
  );
  testWidgets('late review completion cannot replace another schedule', (
    tester,
  ) async {
    final pending = Completer<ScheduleTimeCorrectionReview>();
    repository.values['two'] = _review(id: 'two');
    repository.reader = (id) =>
        id == 'one' ? pending.future : Future.value(repository.values[id]!);
    await pump(tester, settle: false);
    await tester.pump();
    await pump(tester, id: 'two');
    pending.complete(_review());
    await tester.pumpAndSettle();
    expect(find.text('Meeting two'), findsOneWidget);
    expect(find.text('Meeting one'), findsNothing);
    expect(repository.commands, isEmpty);
  });
  testWidgets('conflict remains unsaved and requires a fresh review', (
    tester,
  ) async {
    repository.failure = ScheduleSaveFailure.conflict;
    await pump(tester);
    await confirm(tester);
    expect(saved, 0);
    expect(effects.calls, 0);
    expect(find.text('Review latest record'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('review-time-correction')))
          .onPressed,
      isNull,
    );
  });
  testWidgets('an uncertain failure retries the same immutable intent', (
    tester,
  ) async {
    repository.error = StateError('storage result unavailable');
    await pump(tester);
    await confirm(tester);
    expect(repository.commands, hasLength(1));
    expect(saved, 0);
    repository.error = null;
    await confirm(tester);
    expect(repository.commands, hasLength(2));
    expect(
      identical(repository.commands.first, repository.commands.last),
      isTrue,
    );
    expect(saved, 1);
  });
  testWidgets(
    'a confirmation from the previous owner cannot save a replacement',
    (tester) async {
      repository.values['two'] = _review(id: 'two');
      await pump(tester);
      await openConfirmation(tester);
      await pump(tester, id: 'two');
      await tester.tap(find.byKey(const Key('confirm-time-correction')));
      await tester.pumpAndSettle();
      expect(repository.commands, isEmpty);
      expect(saved, 0);
      expect(find.text('Meeting two'), findsOneWidget);
    },
  );
  for (final locale in ['ko', 'en']) {
    testWidgets(
      '$locale review and confirmation fit a narrow screen with large text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await pump(tester, locale: locale, scale: 2.5);
        await openConfirmation(tester);
        expect(tester.takeException(), isNull);
        expect(repository.commands, isEmpty);
      },
    );
  }
}
