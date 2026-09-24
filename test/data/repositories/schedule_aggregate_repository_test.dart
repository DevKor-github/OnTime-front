import 'package:on_time_front/data/tables/schedule_with_place_model.dart';
import 'dart:async';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/data/repositories/recurring_schedule_repository_impl.dart';
import 'package:on_time_front/data/repositories/schedule_aggregate_repository_impl.dart';
import 'package:on_time_front/data/repositories/schedule_repository_impl.dart';
import 'package:on_time_front/domain/repositories/timed_preparation_repository.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_preparation_mode.dart';
import 'package:on_time_front/domain/entities/schedule_save.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
import 'package:on_time_front/domain/use-cases/schedule_form_submission.dart';
import 'package:on_time_front/domain/use-cases/schedule_save_workflow.dart';
import 'package:on_time_front/domain/use-cases/schedule_mutation_alarm_effects_coordinator.dart';

class _Runtime extends Fake implements TimedPreparationRepository {}

class _Effects extends Fake implements ScheduleMutationAlarmEffectsCoordinator {
  int calls = 0;
  Future<bool> Function()? handler;
  @override
  Future<bool> afterCommit() {
    calls++;
    return handler?.call() ?? Future.value(true);
  }
}

PreparationEntity prep([int minutes = 10]) => PreparationEntity(
  preparationStepList: [
    PreparationStepEntity(
      id: 'draft-step',
      preparationName: 'Prepare',
      preparationTime: Duration(minutes: minutes),
    ),
  ],
);
ScheduleEntity schedule([String id = 'one']) => ScheduleEntity(
  id: id,
  place: PlaceEntity(id: 'place-$id', placeName: 'Office'),
  scheduleName: 'Meeting',
  scheduleTime: DateTime.utc(2030, 1, 1, 10),
  timeZoneId: 'UTC',
  occurrenceOffsetSeconds: 0,
  moveTime: Duration.zero,
  isChanged: true,
  isStarted: false,
  scheduleSpareTime: Duration.zero,
  scheduleNote: '',
  preparationMode: SchedulePreparationMode.custom,
);
void main() {
  late AppDatabase db;
  late LocalDataOperationGate gate;
  late ScheduleAggregateRepositoryImpl repository;
  late RecurringScheduleRepositoryImpl recurring;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    gate = LocalDataOperationGate();
    recurring = RecurringScheduleRepositoryImpl(
      db,
      now: () => DateTime.utc(2029),
    );
    repository = ScheduleAggregateRepositoryImpl(
      db,
      recurring,
      gate: gate,
      now: () => DateTime.utc(2029),
    );
    await db.userDao.putUser(
      const UserEntity(id: 'local-profile', spareTime: Duration.zero, note: ''),
    );
  });
  tearDown(() async {
    await db.close();
  });
  Future<int> revision() async =>
      (await db.select(db.users).getSingle()).dataRevision;
  Future<ScheduleFormSubmission> create({
    String id = 'one',
    String mutation = 'intent',
    PreparationEntity? preparation,
    ScheduleEntity? value,
    RecurrenceRule? rule,
  }) async => ScheduleFormSubmission(
    schedule: value ?? schedule(id),
    preparation: preparation ?? prep(),
    preparationChanged: true,
    baseline: await repository.newBaseline(),
    mutationId: mutation,
    recurrenceRule: rule,
  );
  Future<ScheduleFormSubmission> edit({
    String id = 'one',
    String mutation = 'edit',
    int minutes = 20,
    String? name,
    ScheduleEntity? value,
  }) async {
    final snapshot = await repository.readForEdit(id);
    return ScheduleFormSubmission(
      schedule:
          value ??
          snapshot.schedule.copyWith(
            scheduleName: name ?? snapshot.schedule.scheduleName,
          ),
      preparation: prep(minutes),
      preparationChanged: true,
      originalSchedule: snapshot.schedule,
      baseline: snapshot.baseline,
      mutationId: mutation,
    );
  }

  final conflict = throwsA(
    isA<ScheduleSaveRejected>().having(
      (e) => e.failure,
      'failure',
      ScheduleSaveFailure.conflict,
    ),
  );
  for (final fault in ['place', 'schedule', 'step', 'revision']) {
    test(
      '$fault fault rolls back the whole aggregate and same intent retries',
      () async {
        final draft = await create();
        final before = await revision();
        final target = {
          'place': 'INSERT ON places',
          'schedule': 'INSERT ON schedules',
          'step': 'INSERT ON preparation_schedules',
          'revision': 'UPDATE OF data_revision ON users',
        }[fault];
        await db.customStatement(
          "CREATE TRIGGER reject_write BEFORE $target BEGIN SELECT RAISE(ABORT, 'injected'); END",
        );
        await expectLater(
          repository.save(draft, editing: false),
          throwsA(anything),
        );
        expect(await db.select(db.schedules).get(), isEmpty);
        expect(await db.select(db.places).get(), isEmpty);
        expect(await db.select(db.preparationSchedules).get(), isEmpty);
        expect(await revision(), before);
        await db.customStatement('DROP TRIGGER reject_write');
        await repository.save(draft, editing: false);
        expect(await revision(), before + 1);
        expect(
          (await repository.readForEdit('one')).preparation.totalDuration,
          const Duration(minutes: 10),
        );
      },
    );
  }
  test(
    'edit failure after old preparation deletion preserves old aggregate and revision',
    () async {
      await repository.save(await create(), editing: false);
      final draft = await edit(name: 'Changed');
      final old = await repository.readForEdit('one');
      final before = await revision();
      await db.customStatement(
        "CREATE TRIGGER reject_step BEFORE INSERT ON preparation_schedules BEGIN SELECT RAISE(ABORT, 'injected'); END",
      );
      await expectLater(
        repository.save(draft, editing: true),
        throwsA(anything),
      );
      final after = await repository.readForEdit('one');
      expect(after.schedule, old.schedule);
      expect(after.preparation, old.preparation);
      expect(after.baseline, old.baseline);
      expect(await revision(), before);
    },
  );
  test(
    'concurrent and recreated repository lost receipt retry commit once',
    () async {
      final draft = await create();
      final before = await revision();
      final receipts = await Future.wait([
        repository.save(draft, editing: false),
        repository.save(draft, editing: false),
      ]);
      expect(receipts.where((r) => r.changed), hasLength(1));
      repository = ScheduleAggregateRepositoryImpl(
        db,
        recurring,
        gate: gate,
        now: () => DateTime.utc(2029),
      );
      expect((await repository.save(draft, editing: false)).changed, isFalse);
      expect(await revision(), before + 1);
      expect(await db.select(db.schedules).get(), hasLength(1));
    },
  );
  test('same id other input conflicts instead of upsert', () async {
    final draft = await create();
    await repository.save(draft, editing: false);
    await expectLater(
      repository.save(
        await create(value: schedule().copyWith(scheduleName: 'Different')),
        editing: false,
      ),
      conflict,
    );
  });
  test('semantic no-op preserves owned step IDs and revision', () async {
    await repository.save(await create(), editing: false);
    final before = await revision();
    final old = await repository.readForEdit('one');
    final result = await repository.save(
      await edit(minutes: 10),
      editing: true,
    );
    expect(result.changed, isFalse);
    expect(await revision(), before);
    expect((await repository.readForEdit('one')).preparation, old.preparation);
  });
  test(
    'two edit drafts and value ABA conflict without using global revision',
    () async {
      await repository.save(await create(), editing: false);
      final old = await edit();
      await repository.save(await edit(name: 'B'), editing: true);
      await repository.save(
        await edit(name: 'Meeting', mutation: 'back'),
        editing: true,
      );
      await expectLater(repository.save(old, editing: true), conflict);
      final current = await edit();
      await db.userDao.updateSpareTime(
        'local-profile',
        const Duration(minutes: 3),
      );
      await repository.save(current, editing: true);
      expect(
        (await repository.readForEdit('one')).preparation.totalDuration,
        const Duration(minutes: 20),
      );
    },
  );
  test(
    'deleted create retry and recreated same id reject old intent',
    () async {
      final old = await create();
      await repository.save(old, editing: false);
      await (db.delete(
        db.preparationSchedules,
      )..where((t) => t.scheduleId.equals('one'))).go();
      await (db.delete(db.schedules)..where((t) => t.id.equals('one'))).go();
      await db.userDao.markDurableDataChanged('local-profile');
      await expectLater(repository.save(old, editing: false), conflict);
      await repository.save(await create(mutation: 'new'), editing: false);
      await expectLater(repository.save(old, editing: false), conflict);
    },
  );
  test(
    'new store same revision and fresh memory generation rejects old draft',
    () async {
      final old = await create();
      final revisionBefore = await revision();
      await db.deleteAllDurableData();
      await db.userDao.putUser(
        const UserEntity(
          id: 'local-profile',
          spareTime: Duration.zero,
          note: '',
        ),
      );
      expect(await revision(), revisionBefore);
      repository = ScheduleAggregateRepositoryImpl(
        db,
        recurring,
        gate: LocalDataOperationGate(),
        now: () => DateTime.utc(2029),
      );
      await expectLater(repository.save(old, editing: false), conflict);
    },
  );
  test(
    'unrelated durable create conflict is explicit; reviewed new intent succeeds',
    () async {
      final old = await create();
      await db.userDao.markDurableDataChanged('local-profile');
      await expectLater(repository.save(old, editing: false), conflict);
      await repository.save(await create(mutation: 'reviewed'), editing: false);
    },
  );
  test(
    'start between draft and commit conflicts and preserves protected fields',
    () async {
      await repository.save(await create(), editing: false);
      final old = await edit();
      final writer = ScheduleRepositoryImpl(
        database: db,
        timedPreparationRepository: _Runtime(),
      );
      await writer.startSchedule('one', startedAt: DateTime.utc(2029));
      await expectLater(repository.save(old, editing: true), conflict);
      final row = await db.select(db.schedules).getSingle();
      expect(row.isStarted, isTrue);
      expect(row.preparationFrozen, isTrue);
      expect(row.startedAt?.toUtc(), DateTime.utc(2029));
      await writer.dispose();
    },
  );
  test('same shared place label edit copies ownership', () async {
    await repository.save(await create(), editing: false);
    await repository.save(
      await create(
        id: 'two',
        mutation: 'two',
        value: schedule('two').copyWith(place: schedule().place),
      ),
      editing: false,
    );
    final current = await repository.readForEdit('one');
    await repository.save(
      await edit(
        value: current.schedule.copyWith(
          place: PlaceEntity(
            id: current.schedule.place.id,
            placeName: 'Changed',
          ),
        ),
      ),
      editing: true,
    );
    expect(
      (await repository.readForEdit('two')).schedule.place.placeName,
      'Office',
    );
  });
  for (final invalid in [
    PreparationEntity(preparationStepList: []),
    PreparationEntity(
      preparationStepList: const [
        PreparationStepEntity(
          id: 's',
          preparationName: 'Step',
          preparationTime: Duration(seconds: 119),
        ),
      ],
    ),
  ]) {
    test(
      'invalid custom input is rejected atomically ${invalid.totalDuration}',
      () async {
        await expectLater(
          repository.save(await create(preparation: invalid), editing: false),
          throwsA(isA<ScheduleSaveRejected>()),
        );
        expect(await db.select(db.schedules).get(), isEmpty);
      },
    );
  }
  test('create cannot inject outcome or frozen metadata', () async {
    await expectLater(
      repository.save(
        await create(
          value: schedule().copyWith(
            isStarted: true,
            scoreContributionRecorded: true,
          ),
        ),
        editing: false,
      ),
      throwsA(isA<ScheduleSaveRejected>()),
    );
    expect(await db.select(db.schedules).get(), isEmpty);
  });
  test(
    'recurring duplicate create has durable receipt and rejects changed input',
    () async {
      final rule = RecurrenceRule(
        frequency: RecurrenceFrequency.daily,
        start: DateTime.utc(2030, 1, 1, 10),
        timeZoneId: 'UTC',
        count: 65,
      );
      final draft = await create(rule: rule);
      final before = await revision();
      await repository.save(draft, editing: false);
      expect(await db.select(db.schedules).get(), hasLength(60));
      final root = await db.select(db.recurringScheduleSegments).getSingle();
      await recurring.materialize(DateTime.utc(2030), DateTime.utc(2031));
      expect(await db.select(db.schedules).get(), hasLength(65));
      final expanded = await db
          .select(db.recurringScheduleSegments)
          .getSingle();
      expect(expanded.aggregateVersion, root.aggregateVersion);
      expect(expanded.lastMutationVersion, root.lastMutationVersion);
      expect((await repository.save(draft, editing: false)).changed, isFalse);
      expect(await revision(), before + 1);
      await expectLater(
        repository.save(
          await create(
            rule: rule,
            value: schedule().copyWith(scheduleName: 'Other'),
          ),
          editing: false,
        ),
        conflict,
      );
    },
  );
  test(
    'workflow failed delivery retry does not re-save and coalesces pending intent',
    () async {
      final effects = _Effects();
      final barrier = Completer<bool>();
      effects.handler = () => barrier.future;
      final flow = ScheduleSaveWorkflow(repository, effects);
      final draft = await create();
      final one = flow.save(draft, editing: false),
          two = flow.save(draft, editing: false);
      expect(identical(one, two), isTrue);
      await Future<void>.delayed(Duration.zero);
      barrier.complete(false);
      final receipt = await one;
      expect(receipt.deliveryPending, isTrue);
      final before = await revision();
      effects.handler = () => Future.value(true);
      expect((await flow.retryDelivery(receipt)).deliveryPending, isFalse);
      expect(await revision(), before);
      expect(await db.select(db.schedules).get(), hasLength(1));
    },
  );
  test(
    'late delivery after replacement retains commit but never current success',
    () async {
      final effects = _Effects();
      final barrier = Completer<bool>(), entered = Completer<void>();
      effects.handler = () {
        entered.complete();
        return barrier.future;
      };
      final flow = ScheduleSaveWorkflow(repository, effects);
      final pending = flow.save(await create(), editing: false);
      await entered.future;
      await gate.run(() async {}, replacesData: true);
      barrier.complete(true);
      final receipt = await pending;
      expect(receipt.deliveryPending, isTrue);
      expect(repository.isCurrent(receipt), isFalse);
      expect(await db.select(db.schedules).get(), hasLength(1));
    },
  );
  test(
    'custom to default to template preserves reference sources and owned cleanup',
    () async {
      await db.preparationUserDao.createPreparationUser(
        prep(7),
        'local-profile',
      );
      await db.preparationTemplateDao.put(
        id: 'template',
        name: 'Template',
        preparation: prep(8),
        now: DateTime.utc(2029),
      );
      await repository.save(await create(), editing: false);
      var snap = await repository.readForEdit('one');
      await repository.save(
        ScheduleFormSubmission(
          schedule: snap.schedule.copyWith(
            preparationMode: SchedulePreparationMode.defaultPreparation,
            isChanged: false,
          ),
          preparation: prep(7),
          preparationChanged: false,
          mutationId: 'default',
          baseline: snap.baseline,
          originalSchedule: snap.schedule,
        ),
        editing: true,
      );
      expect(await db.select(db.preparationSchedules).get(), isEmpty);
      expect(
        (await repository.readForEdit('one')).preparation.totalDuration,
        const Duration(minutes: 7),
      );
      snap = await repository.readForEdit('one');
      await repository.save(
        ScheduleFormSubmission(
          schedule: snap.schedule.copyWith(
            preparationMode: SchedulePreparationMode.template,
            preparationTemplateId: 'template',
            preparationTemplateName: 'Template',
          ),
          preparation: prep(8),
          preparationChanged: false,
          mutationId: 'template',
          baseline: snap.baseline,
          originalSchedule: snap.schedule,
        ),
        editing: true,
      );
      final stale = await edit();
      await db.preparationTemplateDao.put(
        id: 'template',
        name: 'Template',
        preparation: prep(9),
        now: DateTime.utc(2029),
      );
      await expectLater(repository.save(stale, editing: true), conflict);
      expect(
        (await db.preparationUserDao.getPreparationUsersByUserId(
          'local-profile',
        )).totalDuration,
        const Duration(minutes: 7),
      );
      expect(
        (await repository.readForEdit('one')).preparation.totalDuration,
        const Duration(minutes: 9),
      );
    },
  );
  test('default fallback dependency ABA invalidates stale edit', () async {
    await db.preparationUserDao.createPreparationUser(prep(7), 'local-profile');
    await repository.save(
      await create(
        value: schedule().copyWith(
          preparationMode: SchedulePreparationMode.defaultPreparation,
          isChanged: false,
        ),
      ),
      editing: false,
    );
    final stale = await edit();
    await db.preparationUserDao.createPreparationUser(prep(9), 'local-profile');
    await db.preparationUserDao.createPreparationUser(prep(7), 'local-profile');
    await expectLater(repository.save(stale, editing: true), conflict);
  });
  for (final table in [
    'preparation_definition_steps',
    'recurring_schedule_segments',
    'schedules',
    'users',
  ]) {
    test(
      'recurring $table fault rolls back definitions series materialization and revision',
      () async {
        final rule = RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          start: DateTime.utc(2030, 1, 1, 10),
          timeZoneId: 'UTC',
          count: 3,
        );
        final draft = await create(rule: rule);
        final before = await revision();
        final event = table == 'users' ? 'UPDATE OF data_revision' : 'INSERT';
        await db.customStatement(
          "CREATE TRIGGER fault BEFORE $event ON $table BEGIN SELECT RAISE(ABORT,'failure'); END",
        );
        await expectLater(
          repository.save(draft, editing: false),
          throwsA(anything),
        );
        expect(await db.select(db.schedules).get(), isEmpty);
        expect(await db.select(db.recurringScheduleSegments).get(), isEmpty);
        expect(await db.select(db.preparationDefinitions).get(), isEmpty);
        expect(await revision(), before);
        await db.customStatement('DROP TRIGGER fault');
        await repository.save(draft, editing: false);
        expect(await revision(), before + 1);
      },
    );
  }
  test(
    'following split keeps stable root through clock reversal and recovers lost receipt',
    () async {
      var clock = DateTime.utc(2029);
      recurring = RecurringScheduleRepositoryImpl(db, now: () => clock);
      repository = ScheduleAggregateRepositoryImpl(
        db,
        recurring,
        gate: gate,
        now: () => clock,
      );
      final rule = RecurrenceRule(
        frequency: RecurrenceFrequency.daily,
        start: DateTime.utc(2030, 1, 1, 10),
        timeZoneId: 'UTC',
        count: 3,
      );
      await repository.save(await create(rule: rule), editing: false);
      final rows = await db.scheduleDao.getScheduleList();
      final snapshot = await repository.readForEdit(rows[1].schedule.id);
      final root = snapshot.baseline.rootId;
      final draft = ScheduleFormSubmission(
        schedule: snapshot.schedule.copyWith(scheduleName: 'New series'),
        preparation: snapshot.preparation,
        preparationChanged: false,
        originalSchedule: snapshot.schedule,
        baseline: snapshot.baseline,
        mutationId: 'following',
        recurringScope: RecurringEditScope.following,
        recurrenceRule: rule.withStartAndEnd(
          start: snapshot.schedule.scheduleTime,
          count: rule.count,
          until: rule.until,
        ),
      );
      clock = DateTime.utc(2028);
      final before = await revision();
      await repository.save(draft, editing: true);
      expect(
        (await db.select(db.recurringScheduleSegments).get())
            .map((s) => s.rootSegmentId)
            .toSet(),
        {root},
      );
      repository = ScheduleAggregateRepositoryImpl(
        db,
        recurring,
        gate: LocalDataOperationGate(),
        now: () => clock,
      );
      expect((await repository.save(draft, editing: true)).changed, isFalse);
      expect(await revision(), before + 1);
      expect(
        (await db.scheduleDao.getScheduleList()).where(
          (s) => s.schedule.scheduleName == 'New series',
        ),
        hasLength(2),
      );
    },
  );
  test(
    'semantic same following save does not split or increase revision',
    () async {
      final rule = RecurrenceRule(
        frequency: RecurrenceFrequency.daily,
        start: DateTime.utc(2030, 1, 1, 10),
        timeZoneId: 'UTC',
        count: 3,
      );
      await repository.save(await create(rule: rule), editing: false);
      final snapshot = await repository.readForEdit(
        (await db.scheduleDao.getScheduleList())[1].schedule.id,
      );
      final before = await revision();
      final result = await repository.save(
        ScheduleFormSubmission(
          schedule: snapshot.schedule,
          preparation: snapshot.preparation,
          preparationChanged: false,
          originalSchedule: snapshot.schedule,
          baseline: snapshot.baseline,
          mutationId: 'same-following',
          recurringScope: RecurringEditScope.following,
          recurrenceRule: rule.withStartAndEnd(
            start: snapshot.schedule.scheduleTime,
            count: rule.count,
            until: rule.until,
          ),
        ),
        editing: true,
      );
      expect(result.changed, isFalse);
      expect(await revision(), before);
      expect(await db.select(db.recurringScheduleSegments).get(), hasLength(1));
    },
  );

  test(
    'root receipt rejects dependency place mutation after following commit',
    () async {
      final rule = RecurrenceRule(
        frequency: RecurrenceFrequency.daily,
        start: DateTime.utc(2030, 1, 1, 10),
        timeZoneId: 'UTC',
        count: 3,
      );
      await repository.save(await create(rule: rule), editing: false);
      final original = await repository.readForEdit(
        (await db.scheduleDao.getScheduleList())[1].schedule.id,
      );
      final intent = ScheduleFormSubmission(
        schedule: original.schedule.copyWith(scheduleName: 'Changed'),
        preparation: original.preparation,
        preparationChanged: false,
        originalSchedule: original.schedule,
        baseline: original.baseline,
        mutationId: 'following',
        recurringScope: RecurringEditScope.following,
        recurrenceRule: rule.withStartAndEnd(
          start: original.schedule.scheduleTime,
          count: rule.count,
          until: rule.until,
        ),
      );
      await repository.save(intent, editing: true);
      final rootBefore = await (db.select(
        db.recurringScheduleSegments,
      )..where((t) => t.id.equals(original.baseline.rootId!))).getSingle();
      expect(rootBefore.lastMutationVersion, rootBefore.aggregateVersion);
      await (db.update(db.places)
            ..where((t) => t.id.equals(original.schedule.place.id)))
          .write(const PlacesCompanion(placeName: Value('Renamed')));
      final rootAfter = await (db.select(
        db.recurringScheduleSegments,
      )..where((t) => t.id.equals(rootBefore.id))).getSingle();
      expect(rootAfter.aggregateVersion, isNot(rootBefore.aggregateVersion));
      await expectLater(repository.save(intent, editing: true), conflict);
    },
  );
  for (final position in [0, 1, 2]) {
    test(
      'custom step $position insertion failure has no partial aggregate',
      () async {
        final steps = PreparationEntity(
          preparationStepList: List.generate(
            3,
            (i) => PreparationStepEntity(
              id: 'draft-$i',
              preparationName: 'Step $i',
              preparationTime: const Duration(minutes: 2),
              nextPreparationId: i == 2 ? null : 'draft-${i + 1}',
            ),
          ),
        );
        final intent = await create(preparation: steps);
        final before = await revision();
        await db.customStatement(
          "CREATE TRIGGER fail_position BEFORE INSERT ON preparation_schedules WHEN NEW.preparation_name='Step $position' BEGIN SELECT RAISE(ABORT,'step failure'); END",
        );
        await expectLater(
          repository.save(intent, editing: false),
          throwsA(anything),
        );
        expect(await db.select(db.schedules).get(), isEmpty);
        expect(await db.select(db.places).get(), isEmpty);
        expect(await db.select(db.preparationSchedules).get(), isEmpty);
        expect(await revision(), before);
        await db.customStatement('DROP TRIGGER fail_position');
        await repository.save(intent, editing: false);
        expect(await db.select(db.preparationSchedules).get(), hasLength(3));
        expect(await revision(), before + 1);
      },
    );
  }
  test(
    'clock reaching preparation start protects unchanged database baseline',
    () async {
      await repository.save(await create(), editing: false);
      final intent = await edit();
      repository = ScheduleAggregateRepositoryImpl(
        db,
        recurring,
        gate: gate,
        now: () => DateTime.utc(2030, 1, 1, 9, 50),
      );
      await expectLater(
        repository.save(intent, editing: true),
        throwsA(
          isA<ScheduleSaveRejected>().having(
            (e) => e.failure,
            'failure',
            ScheduleSaveFailure.protected,
          ),
        ),
      );
    },
  );
  for (final scope in [
    RecurringEditScope.occurrence,
    RecurringEditScope.following,
  ]) {
    for (final target in ['preparation_definition_steps', 'users']) {
      test(
        'recurring $scope $target failure preserves prior complete series',
        () async {
          final rule = RecurrenceRule(
            frequency: RecurrenceFrequency.daily,
            start: DateTime.utc(2030, 1, 1, 10),
            timeZoneId: 'UTC',
            count: 3,
          );
          await repository.save(await create(rule: rule), editing: false);
          final before = await repository.readForEdit(
            (await db.scheduleDao.getScheduleList())[1].schedule.id,
          );
          final revisionBefore = await revision();
          Future<List<List<Map<String, Object?>>>> rows() async => [
            for (final table in [
              'schedules',
              'places',
              'preparation_definitions',
              'preparation_definition_steps',
              'recurring_schedule_segments',
              'recurring_schedule_exclusions',
            ])
              (await db
                      .customSelect('SELECT * FROM $table ORDER BY rowid')
                      .get())
                  .map((r) => r.data)
                  .toList(),
          ];
          final original = await rows();
          final intent = ScheduleFormSubmission(
            schedule: before.schedule.copyWith(scheduleName: 'Changed'),
            preparation: prep(30),
            preparationChanged: true,
            originalSchedule: before.schedule,
            baseline: before.baseline,
            mutationId: 'edit',
            recurringScope: scope,
            recurrenceRule: scope == RecurringEditScope.following
                ? rule.withStartAndEnd(
                    start: before.schedule.scheduleTime,
                    count: rule.count,
                    until: rule.until,
                  )
                : null,
          );
          final operation = target == 'users'
              ? 'UPDATE OF data_revision'
              : 'INSERT';
          await db.customStatement(
            "CREATE TRIGGER fail_edit BEFORE $operation ON $target BEGIN SELECT RAISE(ABORT,'failure'); END",
          );
          await expectLater(
            repository.save(intent, editing: true),
            throwsA(anything),
          );
          expect(await rows(), original);
          expect(await revision(), revisionBefore);
          await db.customStatement('DROP TRIGGER fail_edit');
          await repository.save(intent, editing: true);
          expect(await revision(), revisionBefore + 1);
          if (scope == RecurringEditScope.following) {
            final latest = await repository.readForEdit(
              (await db.scheduleDao.getScheduleList())[1].schedule.id,
            );
            final segment = await recurring.getSegment(
              latest.schedule.recurringSegmentId!,
            );
            final same = ScheduleFormSubmission(
              schedule: latest.schedule,
              preparation: latest.preparation,
              preparationChanged: false,
              originalSchedule: latest.schedule,
              baseline: latest.baseline,
              mutationId: 'same',
              recurringScope: scope,
              recurrenceRule: segment.rule,
            );
            expect(
              (await repository.save(same, editing: true)).changed,
              isFalse,
            );
            expect(await revision(), revisionBefore + 1);
          }
        },
      );
    }
  }

  test(
    'recreated create receipt cannot validate old baseline even with reused mutation identity',
    () async {
      final old = await create();
      await repository.save(old, editing: false);
      await (db.delete(
        db.preparationSchedules,
      )..where((t) => t.scheduleId.equals('one'))).go();
      await (db.delete(db.schedules)..where((t) => t.id.equals('one'))).go();
      await db.userDao.markDurableDataChanged('local-profile');
      final replacement = await create();
      await repository.save(replacement, editing: false);
      await expectLater(repository.save(old, editing: false), conflict);
    },
  );
  test(
    'occurrence owned definition invalidates series root receipt dependency',
    () async {
      final rule = RecurrenceRule(
        frequency: RecurrenceFrequency.daily,
        start: DateTime.utc(2030, 1, 1, 10),
        timeZoneId: 'UTC',
        count: 3,
      );
      await repository.save(await create(rule: rule), editing: false);
      final rows = await db.scheduleDao.getScheduleList();
      final second = await repository.readForEdit(rows[1].schedule.id);
      await repository.save(
        ScheduleFormSubmission(
          schedule: second.schedule,
          preparation: prep(30),
          preparationChanged: true,
          originalSchedule: second.schedule,
          baseline: second.baseline,
          mutationId: 'occurrence',
        ),
        editing: true,
      );
      final first = await repository.readForEdit(rows.first.schedule.id);
      final intent = ScheduleFormSubmission(
        schedule: first.schedule,
        preparation: first.preparation,
        preparationChanged: false,
        originalSchedule: first.schedule,
        baseline: first.baseline,
        mutationId: 'following-no-op',
        recurringScope: RecurringEditScope.following,
        recurrenceRule: rule,
      );
      await repository.save(intent, editing: true);
      final changed = await repository.readForEdit(second.schedule.id);
      await (db.update(db.preparationDefinitionSteps)..where(
            (t) => t.definitionId.equals(
              changed.schedule.preparationDefinitionId!,
            ),
          ))
          .write(const PreparationDefinitionStepsCompanion(minutes: Value(31)));
      await expectLater(repository.save(intent, editing: true), conflict);
    },
  );
  for (final withPlace in [false, true]) {
    test(
      'legacy persisted row withPlace=$withPlace cannot rewind identity version or receipt',
      () async {
        await repository.save(await create(), editing: false);
        final old = await db.scheduleDao.getScheduleById('one');
        final intent = await edit(name: 'Changed');
        await repository.save(intent, editing: true);
        final committed = await db.scheduleDao.getScheduleById('one');
        final replay = old.schedule.copyWith(scheduleName: 'Legacy change');
        if (withPlace) {
          await db.scheduleDao.updateScheduleWithPlace(
            ScheduleWithPlace(schedule: replay, place: old.place),
          );
        } else {
          await db.scheduleDao.updateSchedule(replay);
        }
        final after = await db.scheduleDao.getScheduleById('one');
        expect(
          after.schedule.aggregateIncarnation,
          committed.schedule.aggregateIncarnation,
        );
        expect(
          after.schedule.aggregateVersion,
          greaterThan(committed.schedule.aggregateVersion!),
        );
        expect(
          after.schedule.lastMutationId,
          committed.schedule.lastMutationId,
        );
        await db.scheduleDao.updateSchedule(old.schedule);
        final aba = await db.scheduleDao.getScheduleById('one');
        expect(
          aba.schedule.aggregateVersion,
          greaterThan(after.schedule.aggregateVersion!),
        );
        await expectLater(repository.save(intent, editing: true), conflict);
      },
    );
  }
}
