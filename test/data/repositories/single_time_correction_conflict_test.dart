import 'package:flutter/material.dart';
import 'package:on_time_front/domain/repositories/schedule_time_correction_repository.dart';
import 'package:on_time_front/domain/entities/time_correction_conflict.dart';
import 'package:on_time_front/domain/use-cases/schedule_time_correction_workflow.dart';
import 'package:on_time_front/domain/use-cases/schedule_mutation_alarm_effects_coordinator.dart';
import 'package:on_time_front/presentation/schedule_create/screens/schedule_time_correction_screen.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/time/time_zone_rules.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/data/repositories/recurring_schedule_repository_impl.dart';
import 'package:on_time_front/data/repositories/schedule_aggregate_repository_impl.dart';
import 'package:on_time_front/data/repositories/schedule_time_correction_repository_impl.dart';
import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_save.dart';
import 'package:on_time_front/domain/entities/schedule_time_correction.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/use-cases/schedule_form_submission.dart';

void main() {
  const zone = 'Test/A10_Conflict_Target';
  const otherZone = 'Test/A10_Conflict_Other';
  late AppDatabase db;
  late LocalDataOperationGate gate;
  late ScheduleAggregateRepositoryImpl aggregates;
  late ScheduleTimeCorrectionRepositoryImpl repository;
  late Map<String, tz.Location> original;
  final now = DateTime.utc(2030, 1, 1);
  void rules(String id, int seconds) =>
      tz.timeZoneDatabase.locations[id] = tz.Location(id, [], [], [
        tz.TimeZone(seconds * 1000, isDst: false, abbreviation: 'QA'),
      ]);
  ScheduleEntity row(
    String id,
    DateTime civil, {
    String? inZone,
    int offset = 0,
  }) => ScheduleEntity(
    id: id,
    place: PlaceEntity(id: 'place-$id', placeName: id),
    scheduleName: id,
    scheduleTime: civil,
    timeZoneId: inZone ?? zone,
    occurrenceOffsetSeconds: offset,
    moveTime: Duration.zero,
    scheduleSpareTime: Duration.zero,
    scheduleNote: 'Preserve',
    isChanged: false,
    isStarted: false,
  );
  setUp(() async {
    TimeZoneRules.ensureInitialized();
    original = Map.of(tz.timeZoneDatabase.locations);
    rules(zone, 0);
    rules(otherZone, 0);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    gate = LocalDataOperationGate();
    final recurring = RecurringScheduleRepositoryImpl(db, now: () => now);
    aggregates = ScheduleAggregateRepositoryImpl(
      db,
      recurring,
      gate: gate,
      now: () => now,
    );
    repository = ScheduleTimeCorrectionRepositoryImpl(
      db,
      aggregates,
      gate: gate,
      now: () => now,
    );
    await db.userDao.putUser(
      const UserEntity(
        id: 'local-profile',
        spareTime: Duration.zero,
        note: '',
        isOnboardingCompleted: true,
      ),
    );
    await aggregates.save(
      ScheduleFormSubmission(
        schedule: row('target', DateTime.utc(2030, 1, 2, 10)),
        preparation: const PreparationEntity(
          preparationStepList: [
            PreparationStepEntity(
              id: 'ready',
              preparationName: 'Ready',
              preparationTime: Duration(minutes: 10),
            ),
          ],
        ),
        preparationChanged: true,
        baseline: await aggregates.newBaseline(),
        mutationId: 'create-target',
      ),
      editing: false,
    );
    rules(zone, 3600);
  });
  tearDown(() async {
    await db.close();
    gate.dispose();
    tz.timeZoneDatabase.locations
      ..clear()
      ..addAll(original);
  });
  Future<List<String>> contents() async => [
    for (final table in ['schedules', 'users', 'preparation_schedules'])
      for (final row
          in await db.customSelect('SELECT * FROM $table ORDER BY id').get())
        jsonEncode(row.data),
  ];
  Future<ScheduleTimeCorrectionCommand> command({
    int hour = 10,
    Set<String> acknowledge = const {},
  }) async => ScheduleTimeCorrectionCommand(
    review: await repository.review('target'),
    civil: CivilDateTime.fromFields(DateTime.utc(2030, 1, 2, hour)),
    timeZoneId: zone,
    offsetSeconds: 3600,
    mutationId: 'correct-target',
    acknowledgedUncertainIds: acknowledge,
  );

  testWidgets(
    'actual commit with lost response replays the identical UI intent',
    (tester) async {
      final proxy = _LostResponse(repository);
      final effects = _Effects();
      var saved = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ScheduleTimeCorrectionScreen(
              scheduleId: 'target',
              workflow: ScheduleTimeCorrectionWorkflow(proxy, effects),
              onSaved: () => saved++,
            ),
          ),
        ),
      );
      await tester.runAsync(() => proxy.pending);
      await tester.pumpAndSettle();
      Future<void> submit() async {
        final review = find.byKey(const Key('review-time-correction'));
        await tester.scrollUntilVisible(review, 300);
        await tester.tap(review);
        await tester.runAsync(() => proxy.pending);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('confirm-time-correction')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('confirm-time-correction')));
        await tester.runAsync(() => proxy.pending);
        await tester.pumpAndSettle();
      }

      await submit();
      expect(saved, 0);
      expect(proxy.commands, hasLength(1));
      final committed = await tester.runAsync(contents);
      expect(proxy.choiceReviews, 1);
      await submit();
      expect(saved, 1);
      expect(proxy.commands, hasLength(2));
      expect(identical(proxy.commands.first, proxy.commands.last), isTrue);
      expect(proxy.choiceReviews, 1);
      expect(await tester.runAsync(contents), committed);
      expect(effects.calls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'same instant with a different civil date/zone blocks atomically until time is reselected',
    () async {
      await db.scheduleDao.createSchedule(
        row(
          'other',
          DateTime.utc(2030, 1, 2, 18),
          inZone: 'Asia/Seoul',
          offset: 32400,
        ).toScheduleWithPlaceRow(),
      );
      final choice = await command();
      final before = await contents();
      final proof = await repository.reviewChoice(choice);
      expect(proof.conflicts, hasLength(1));
      expect(proof.conflicts.single.other.schedule.id, 'other');
      expect(
        proof.conflicts.single.slot.instantUtc,
        DateTime.utc(2030, 1, 2, 9),
      );
      expect(await contents(), before);
      await expectLater(
        repository.confirm(choice),
        throwsA(isA<ScheduleTimeCorrectionConflict>()),
      );
      expect(await contents(), before);
      final selected = await command(hour: 12);
      expect((await repository.reviewChoice(selected)).conflicts, isEmpty);
      expect((await repository.confirm(selected)).changed, isTrue);
    },
  );
  test(
    'possible future uncertainty requires exact acknowledgement and preserves the other record',
    () async {
      await db.scheduleDao.createSchedule(
        row(
          'uncertain',
          DateTime.utc(2030, 1, 2, 10),
          inZone: otherZone,
        ).toScheduleWithPlaceRow(),
      );
      tz.timeZoneDatabase.locations.remove(otherZone);
      final choice = await command();
      final before = await contents();
      final proof = await repository.reviewChoice(choice);
      expect(proof.conflicts, isEmpty);
      expect(proof.possibleOverlaps.map((e) => e.id), ['uncertain']);
      await expectLater(
        repository.confirm(choice),
        throwsA(isA<ScheduleSaveRejected>()),
      );
      expect(await contents(), before);
      final otherBefore =
          (await db
                  .customSelect("SELECT * FROM schedules WHERE id='uncertain'")
                  .getSingle())
              .data;
      expect(
        (await repository.confirm(
          await command(acknowledge: {'uncertain'}),
        )).changed,
        isTrue,
      );
      expect(
        (await db
                .customSelect("SELECT * FROM schedules WHERE id='uncertain'")
                .getSingle())
            .data,
        otherBefore,
      );
    },
  );
  test(
    'a distant unresolved record does not become a blanket correction block',
    () async {
      await db.scheduleDao.createSchedule(
        row(
          'distant',
          DateTime.utc(2040, 1, 1),
          inZone: otherZone,
        ).toScheduleWithPlaceRow(),
      );
      tz.timeZoneDatabase.locations.remove(otherZone);
      final choice = await command();
      final proof = await repository.reviewChoice(choice);
      expect(proof.possibleOverlaps, isEmpty);
      expect((await repository.confirm(choice)).changed, isTrue);
    },
  );
}

class _LostResponse implements ScheduleTimeCorrectionRepository {
  _LostResponse(this.actual);
  final ScheduleTimeCorrectionRepository actual;
  Future<void> pending = Future.value();
  Future<T> track<T>(Future<T> value) {
    pending = value.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return value;
  }

  final commands = <ScheduleTimeCorrectionCommand>[];
  int choiceReviews = 0;
  @override
  Future<ScheduleTimeCorrectionReview> review(String id) async =>
      await track(actual.review(id));
  @override
  Future<TimeCorrectionConflictProof> reviewChoice(
    ScheduleTimeCorrectionCommand command,
  ) async {
    choiceReviews++;
    return await track(actual.reviewChoice(command));
  }

  @override
  Future<ScheduleSaveReceipt> confirm(
    ScheduleTimeCorrectionCommand command,
  ) async {
    commands.add(command);
    final receipt = await track(actual.confirm(command));
    if (commands.length == 1) {
      throw StateError('response lost after actual commit');
    }
    return receipt;
  }

  @override
  bool isCurrent(ScheduleSaveReceipt receipt) => actual.isCurrent(receipt);
}

class _Effects extends Fake implements ScheduleMutationAlarmEffectsCoordinator {
  int calls = 0;
  @override
  Future<bool> afterCommit() async {
    calls++;
    return true;
  }
}
