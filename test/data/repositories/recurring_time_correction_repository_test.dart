import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_export_snapshot.dart';
import 'package:on_time_front/core/backup/backup_ingestion_store.dart';
import 'package:on_time_front/core/backup/backup_json_reader.dart';
import 'package:on_time_front/core/backup/backup_limits.dart';
import 'package:on_time_front/core/backup/backup_validated_ingestion.dart';
import 'package:on_time_front/core/backup/restore_staging.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/data/repositories/recurring_schedule_repository_impl.dart';
import 'package:on_time_front/data/repositories/recurring_time_correction_repository_impl.dart';
import 'package:on_time_front/data/repositories/schedule_aggregate_repository_impl.dart';
import 'package:on_time_front/data/repositories/schedule_repository_impl.dart';
import 'package:on_time_front/domain/repositories/timed_preparation_repository.dart';
import 'package:on_time_front/data/repositories/schedule_time_correction_repository_impl.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'package:on_time_front/domain/entities/schedule_time_correction.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_save.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
import 'package:on_time_front/domain/recurrence/recurring_time_correction.dart';

void main() {
  late Directory directory;
  late AppDatabase db;
  late LocalDataOperationGate gate;
  late RecurringScheduleRepositoryImpl recurring;
  late ScheduleAggregateRepositoryImpl aggregates;
  late ScheduleTimeCorrectionRepositoryImpl single;
  late RecurringTimeCorrectionRepositoryImpl repository;
  late DateTime now;
  final start = DateTime.utc(2030, 1, 2, 10);
  const preparation = PreparationEntity(
    preparationStepList: [
      PreparationStepEntity(
        id: 'source-step',
        preparationName: 'Ready',
        preparationTime: Duration(minutes: 10),
      ),
    ],
  );
  Future<void> open() async {
    db = AppDatabase.forTesting(
      NativeDatabase(File('${directory.path}/app.sqlite')),
    );
    recurring = RecurringScheduleRepositoryImpl(db, now: () => now);
    aggregates = ScheduleAggregateRepositoryImpl(
      db,
      recurring,
      gate: gate,
      now: () => now,
    );
    single = ScheduleTimeCorrectionRepositoryImpl(
      db,
      aggregates,
      gate: gate,
      now: () => now,
    );
    repository = RecurringTimeCorrectionRepositoryImpl(
      db,
      aggregates,
      recurring,
      gate: gate,
      now: () => now,
    );
  }

  Future<List<ScheduleEntity>> rows() async =>
      (await db.scheduleDao.getScheduleList())
          .map((e) => e.toScheduleEntity())
          .toList()
        ..sort((a, b) => a.scheduleTime.compareTo(b.scheduleTime));
  setUp(() async {
    now = DateTime.utc(2030, 1, 1);
    directory = await Directory.systemTemp.createTemp(
      'ontime-bounded-time-plan-',
    );
    gate = LocalDataOperationGate();
    await open();
    await db.userDao.putUser(
      const UserEntity(
        id: 'local-profile',
        spareTime: Duration.zero,
        note: '',
        isOnboardingCompleted: true,
      ),
    );
    await recurring.create(
      ScheduleEntity(
        id: 'source',
        place: const PlaceEntity(id: 'office', placeName: 'Office'),
        scheduleName: 'Meeting',
        scheduleTime: start,
        timeZoneId: 'UTC',
        occurrenceOffsetSeconds: 0,
        moveTime: Duration.zero,
        scheduleSpareTime: Duration.zero,
        scheduleNote: 'Preserve',
        isChanged: false,
        isStarted: false,
      ),
      preparation,
      RecurrenceRule(
        frequency: RecurrenceFrequency.daily,
        start: start,
        timeZoneId: 'UTC',
        count: 3,
      ),
    );
  });
  tearDown(() async {
    await db.close();
    gate.dispose();
    await directory.delete(recursive: true);
  });

  Future<Map<String, List<String>>> contents() async {
    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
        )
        .get();
    return {
      for (final table in tables)
        table.read<String>(
          'name',
        ): (await db
                .customSelect('SELECT * FROM "${table.read<String>('name')}"')
                .get())
            .map((e) => jsonEncode(e.data))
            .toList()
          ..sort(),
    };
  }

  Future<RecurringTimeCorrectionReview> review({
    int count = 3,
    bool automatic = false,
  }) async {
    final anchor = (await rows()).first;
    return repository.review(
      RecurringTimeCorrectionRequest(
        anchorReview: await single.review(anchor.id),
        rule: RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          start: start.add(const Duration(hours: 1)),
          timeZoneId: 'UTC',
          count: count,
        ),
        endExplicitlyChosen: !automatic,
      ),
    );
  }

  RecurringTimeCorrectionCommand command(
    RecurringTimeCorrectionReview review, {
    String mutation = 'apply-plan',
    bool acknowledge = true,
  }) => RecurringTimeCorrectionCommand(
    review: review,
    mutationId: mutation,
    confirmedDetachedIds: acknowledge
        ? review.mapping.rows
              .where((e) => e.detached)
              .map((e) => e.original.id)
              .toSet()
        : {},
    confirmedUnmatchedExclusions: acknowledge
        ? review.mapping.exclusions
              .where((e) => e.slot == null)
              .map((e) => '${e.original.segmentId}\n${e.original.slot}')
              .toSet()
        : {},
  );

  test(
    'single correction excludes its old slot but still sees a sibling occurrence',
    () async {
      final existing = await rows();
      final anchor = existing.first;
      // A stored offset no longer matching the current UTC rule is a defensive
      // stale-time fixture; all recurrence graph/ownership comes from create().
      await db.customStatement(
        'UPDATE schedules SET occurrence_offset_seconds=3600 WHERE id=?',
        [anchor.id],
      );
      final viewed = await single.review(anchor.id);
      ScheduleTimeCorrectionCommand selection(DateTime civil) =>
          ScheduleTimeCorrectionCommand(
            review: viewed,
            civil: CivilDateTime.fromFields(civil),
            timeZoneId: 'UTC',
            offsetSeconds: 0,
            mutationId: 'single-recurring',
          );
      final before = await contents();
      final self = await single.reviewChoice(selection(start));
      expect(self.conflicts, isEmpty);
      final sibling = await single.reviewChoice(
        selection(existing[1].scheduleTime),
      );
      expect(
        sibling.conflicts.map((e) => e.other.schedule.id),
        contains(existing[1].id),
      );
      expect(await contents(), before);
      await expectLater(
        single.confirm(selection(existing[1].scheduleTime)),
        throwsA(isA<ScheduleTimeCorrectionConflict>()),
      );
      expect(await contents(), before);
      expect((await single.confirm(selection(start))).changed, isTrue);
      expect(
        (await rows()).first.recurringOverrides.split(','),
        contains('time'),
      );
    },
  );

  test(
    'unresolved materialized time override owns its original slot without a phantom base conflict',
    () async {
      final existing = await rows();
      final target = existing.first, uncertain = existing[1];
      await db.customStatement(
        'UPDATE schedules SET occurrence_offset_seconds=3600 WHERE id=?',
        [target.id],
      );
      // The recurrence/definition graph comes from the real create workflow;
      // this raw row models a previously valid override whose zone was removed.
      await db.customStatement(
        "UPDATE schedules SET schedule_time=?, time_zone_id='Missing/Override', recurring_overrides='time' WHERE id=?",
        ['2030-01-02T18:00:00.000', uncertain.id],
      );
      final correction = ScheduleTimeCorrectionCommand(
        review: await single.review(target.id),
        civil: CivilDateTime.fromFields(uncertain.scheduleTime),
        timeZoneId: 'UTC',
        offsetSeconds: 0,
        mutationId: 'resolve-target',
        acknowledgedUncertainIds: {uncertain.id},
      );
      final before = await contents();
      final proof = await single.reviewChoice(correction);
      expect(proof.conflicts, isEmpty);
      expect(proof.possibleOverlaps.map((e) => e.id), contains(uncertain.id));
      expect(await contents(), before);
      expect((await single.confirm(correction)).changed, isTrue);
      final preserved = (await rows()).singleWhere((e) => e.id == uncertain.id);
      expect(preserved.timeZoneId, 'Missing/Override');
      expect(preserved.scheduleTime, DateTime.utc(2030, 1, 2, 18));
      expect(preserved.recurringSlotKey, uncertain.recurringSlotKey);
    },
  );

  test(
    'following conflicts block, then explicit exclusion preserves the row and count budget',
    () async {
      final original = await rows();
      await db.scheduleDao.createSchedule(
        ScheduleEntity(
          id: 'other',
          place: const PlaceEntity(id: 'other-place', placeName: 'Other'),
          scheduleName: 'Other',
          scheduleNote: '',
          scheduleTime: start.add(const Duration(hours: 1)),
          timeZoneId: 'UTC',
          occurrenceOffsetSeconds: 0,
          moveTime: Duration.zero,
          scheduleSpareTime: Duration.zero,
          isChanged: false,
          isStarted: false,
        ).toScheduleWithPlaceRow(),
      );
      final initial = await review();
      expect(initial.conflictProof!.conflicts, hasLength(1));
      final before = await contents();
      await expectLater(
        repository.confirm(command(initial)),
        throwsA(isA<ScheduleTimeCorrectionConflict>()),
      );
      expect(await contents(), before);
      final excluded = initial.conflictProof!.conflicts.single.slot;
      final changed = await repository.review(
        RecurringTimeCorrectionRequest(
          anchorReview: initial.request.anchorReview,
          rule: initial.request.rule,
          endExplicitlyChosen: true,
          excludedConflictSlots: {excluded.key},
        ),
      );
      expect(changed.conflictProof!.conflicts, isEmpty);
      expect(
        changed.mapping.rows.where((e) => e.detached).single.original.id,
        original.first.id,
      );
      expect(changed.mapping.conflictExclusions.single.ordinal, 1);
      await expectLater(
        repository.confirm(command(changed, acknowledge: false)),
        throwsA(isA<ScheduleSaveRejected>()),
      );
      expect(await contents(), before);
      await repository.confirm(command(changed));
      final saved = await rows();
      final standalone = saved.singleWhere((e) => e.id == original.first.id);
      expect(standalone.isRecurring, isFalse);
      expect(standalone.scheduleTime, original.first.scheduleTime);
      expect(
        standalone.preparationDefinitionId,
        original.first.preparationDefinitionId,
      );
      final newId = saved.firstWhere((e) => e.isRecurring).recurringSegmentId!;
      final newSegment = await recurring.getSegment(newId);
      expect(newSegment.rule.count, 3);
      final tombstone = await db
          .customSelect(
            'SELECT * FROM recurring_schedule_exclusions WHERE segment_id=?',
            variables: [Variable(newId)],
          )
          .getSingle();
      expect(tombstone.read<int>('ordinal'), 1);
      await recurring.materialize(now, DateTime.utc(2030, 2));
      expect((await rows()).map((e) => e.id).toSet(), {
        ...original.map((e) => e.id),
        'other',
      });
      final snapshot = await BackupExportSnapshot.create(
        db,
        cutoff: now,
        sourceAppVersion: 'test',
        sourcePlatform: 'test',
        budget: BackupBudget(),
        stagingFactory: () async {
          final target = AppDatabase.forTesting(NativeDatabase.memory());
          return RestoreStaging(target, target.close);
        },
      );
      try {
        final bytes = await snapshot.plaintext().expand((e) => e).toList();
        final budget = BackupBudget();
        final ingestion = BackupIngestionStore.memoryForTesting(budget);
        try {
          final node = await BackupJsonReader(
            ingestion,
            budget,
          ).read(Stream.value(bytes));
          await BackupValidatedIngestion.validateTestStore(
            ingestion,
            node,
            nowUtc: now,
          );
        } finally {
          await ingestion.release();
        }
      } finally {
        await snapshot.release();
      }
    },
  );
  test(
    'arbitrary non-conflicting slots cannot be supplied as conflict exclusions',
    () async {
      final initial = await review();
      final before = await contents();
      await expectLater(
        repository.review(
          RecurringTimeCorrectionRequest(
            anchorReview: initial.request.anchorReview,
            rule: initial.request.rule,
            endExplicitlyChosen: true,
            excludedConflictSlots: {initial.mapping.firstSlot!.key},
          ),
        ),
        throwsA(isA<ScheduleSaveRejected>()),
      );
      expect(await contents(), before);
    },
  );
  test(
    'excluded materialized row is rechecked against the remaining new rule',
    () async {
      final anchor = (await rows()).first;
      final first = start.add(const Duration(hours: 1));
      // A long preparation makes the preserved original overlap a later slot.
      await db.customStatement(
        'UPDATE preparation_definition_steps SET minutes=1560',
      );
      await db.scheduleDao.createSchedule(
        ScheduleEntity(
          id: 'other',
          place: const PlaceEntity(id: 'other-place', placeName: 'Other'),
          scheduleName: 'Other',
          scheduleNote: '',
          scheduleTime: first,
          timeZoneId: 'UTC',
          occurrenceOffsetSeconds: 0,
          moveTime: Duration.zero,
          scheduleSpareTime: Duration.zero,
          isChanged: false,
          isStarted: false,
        ).toScheduleWithPlaceRow(),
      );
      final viewed = await single.review(anchor.id);
      final rule = RecurrenceRule(
        frequency: RecurrenceFrequency.daily,
        start: first,
        timeZoneId: 'UTC',
        count: 3,
      );
      final initial = await repository.review(
        RecurringTimeCorrectionRequest(
          anchorReview: viewed,
          rule: rule,
          endExplicitlyChosen: true,
        ),
      );
      expect(
        initial.conflictProof!.conflicts.any(
          (e) => e.slot.key == first.toIso8601String(),
        ),
        isTrue,
      );
      final changed = await repository.review(
        RecurringTimeCorrectionRequest(
          anchorReview: viewed,
          rule: rule,
          endExplicitlyChosen: true,
          excludedConflictSlots: {first.toIso8601String()},
        ),
      );
      expect(
        changed.conflictProof!.conflicts.any(
          (e) => e.other.schedule.id == anchor.id,
        ),
        isTrue,
      );
      final before = await contents();
      await expectLater(
        repository.confirm(command(changed)),
        throwsA(isA<ScheduleTimeCorrectionConflict>()),
      );
      expect(await contents(), before);
    },
  );

  test(
    'finite review is read-only and apply preserves IDs, preparation owners and one revision',
    () async {
      final original = await rows();
      final before = await contents();
      final planned = await review(automatic: true);
      expect(planned.mapping.automaticallyRetainedCount, isTrue);
      expect(planned.mapping.rule.count, 3);
      expect(planned.mapping.workUnits, lessThan(100));
      expect(await contents(), before);
      final receipt = await repository.confirm(command(planned));
      expect(receipt.changed, isTrue);
      final saved = await rows();
      expect(saved.map((e) => e.id), original.map((e) => e.id));
      expect(
        saved.map((e) => e.preparationDefinitionId),
        original.map((e) => e.preparationDefinitionId),
      );
      expect(saved.map((e) => e.scheduleTime.hour), everyElement(11));
      expect(saved.map((e) => e.recurringSegmentId).toSet(), hasLength(1));
      expect(
        saved.first.recurringSegmentId,
        isNot(original.first.recurringSegmentId),
      );
      expect((await db.select(db.users).getSingle()).dataRevision, 2);
      // Stable IDs differ from the generated UUID for the new segment. A later
      // normal materialization must recognize the occupied segment+slot.
      await recurring.materialize(start, DateTime.utc(2030, 2, 1));
      expect((await rows()).map((e) => e.id), original.map((e) => e.id));
    },
  );
  test(
    'exact retries including reopen reuse the same row and root receipt',
    () async {
      final plan = command(await review());
      expect((await repository.confirm(plan)).changed, isTrue);
      final saved = await contents();
      expect((await repository.confirm(plan)).changed, isFalse);
      await db.close();
      await open();
      expect((await repository.confirm(plan)).changed, isFalse);
      expect(await contents(), saved);
    },
  );
  test(
    'revision failure rolls back every close, insert, mapped row and receipt',
    () async {
      final plan = command(await review());
      await db.customStatement(
        "CREATE TRIGGER fail_plan BEFORE UPDATE OF data_revision ON users BEGIN SELECT RAISE(ABORT, 'a10-plan-revision'); END",
      );
      final before = await contents();
      await expectLater(
        repository.confirm(plan),
        throwsA(predicate((e) => e.toString().contains('a10-plan-revision'))),
      );
      expect(await contents(), before);
      await db.customStatement('DROP TRIGGER fail_plan');
      expect((await repository.confirm(plan)).changed, isTrue);
    },
  );
  test(
    'excess rows require exact detach acknowledgement and remain stable standalones',
    () async {
      final original = await rows();
      final planned = await review(count: 1);
      expect(planned.mapping.rows.where((e) => e.detached), hasLength(2));
      final before = await contents();
      await expectLater(
        repository.confirm(command(planned, acknowledge: false)),
        throwsA(isA<ScheduleSaveRejected>()),
      );
      expect(await contents(), before);
      await repository.confirm(command(planned));
      final saved = await rows();
      expect(saved.map((e) => e.id).toSet(), original.map((e) => e.id).toSet());
      expect(saved.where((e) => !e.isRecurring), hasLength(2));
      expect(
        saved.map((e) => e.preparationDefinitionId).toSet(),
        original.map((e) => e.preparationDefinitionId).toSet(),
      );
      // Actual ordinary SQLite export/ingestion/portable copy, not SQLCipher UI.
      final snapshot = await BackupExportSnapshot.create(
        db,
        cutoff: now,
        sourceAppVersion: 'test',
        sourcePlatform: 'test',
        budget: BackupBudget(),
        stagingFactory: () async {
          final target = AppDatabase.forTesting(NativeDatabase.memory());
          return RestoreStaging(target, target.close);
        },
      );
      try {
        final bytes = await snapshot.plaintext().expand((e) => e).toList();
        final budget = BackupBudget();
        final ingestion = BackupIngestionStore.memoryForTesting(budget);
        try {
          final node = await BackupJsonReader(
            ingestion,
            budget,
          ).read(Stream.value(bytes));
          final content = await BackupValidatedIngestion.validateTestStore(
            ingestion,
            node,
            nowUtc: now,
          );
          final target = AppDatabase.forTesting(NativeDatabase.memory());
          try {
            await content.materialize(target, pendingCleanup: false);
            await content.validateReadBack(target, pendingCleanup: false);
            expect(
              (await target.select(target.schedules).get())
                  .map((e) => e.id)
                  .toSet(),
              original.map((e) => e.id).toSet(),
            );
            expect(
              (await target.select(target.schedules).get())
                  .map((e) => e.preparationDefinitionId)
                  .toSet(),
              original.map((e) => e.preparationDefinitionId).toSet(),
            );
          } finally {
            await target.close();
          }
        } finally {
          await ingestion.release();
        }
      } finally {
        await snapshot.release();
      }
    },
  );
  test(
    'concurrent same intent commits once; same ID with another plan conflicts',
    () async {
      final plan = command(await review());
      final receipts = await Future.wait([
        repository.confirm(plan),
        repository.confirm(plan),
      ]);
      expect(receipts.where((e) => e.changed), hasLength(1));
      final changed = command(await review(count: 2));
      await expectLater(
        repository.confirm(changed),
        throwsA(isA<ScheduleSaveRejected>()),
      );
      expect((await db.select(db.users).getSingle()).dataRevision, 2);
    },
  );
  test('stale source edit cannot be hidden by a forged old mapping', () async {
    final plan = command(await review());
    await db.customStatement(
      "UPDATE schedules SET schedule_note = 'changed' WHERE id = ?",
      [(await rows()).last.id],
    );
    final before = await contents();
    await expectLater(
      repository.confirm(plan),
      throwsA(isA<ScheduleSaveRejected>()),
    );
    expect(await contents(), before);
  });
  test(
    'clock rewind and target preparation boundary reject before writing',
    () async {
      final plan = command(await review());
      final before = await contents();
      now = now.subtract(const Duration(seconds: 1));
      await expectLater(
        repository.confirm(plan),
        throwsA(isA<ScheduleSaveRejected>()),
      );
      expect(await contents(), before);
      now = start.add(const Duration(minutes: 55));
      await expectLater(
        repository.confirm(plan),
        throwsA(isA<ScheduleSaveRejected>()),
      );
      expect(await contents(), before);
    },
  );
  test(
    'unresolved time override is listed by ID and cannot acquire the base rule offset',
    () async {
      final override = (await rows())[1];
      await recurring.updateOccurrence(
        override,
        override.copyWith(timeZoneId: 'Africa/Abidjan'),
        preparation,
        preparationChanged: false,
      );
      // Model a once-valid persisted zone absent from this registry, not a new
      // user write bypassing form validation.
      await db.customStatement(
        "UPDATE schedules SET time_zone_id = 'Unknown/Retired' WHERE id = ?",
        [override.id],
      );
      final planned = await review();
      expect(planned.unresolvedOverrides.keys, [override.id]);
      final before = await contents();
      await expectLater(
        repository.confirm(command(planned)),
        throwsA(isA<ScheduleSaveRejected>()),
      );
      expect(await contents(), before);
    },
  );
  test(
    'an unmatched tombstone is retained and requires exact acknowledgement',
    () async {
      final old = (await rows())[1];
      await recurring.delete(old, RecurringEditScope.occurrence);
      final planned = await review(count: 1);
      expect(planned.mapping.exclusions.single.slot, isNull);
      await expectLater(
        repository.confirm(command(planned, acknowledge: false)),
        throwsA(isA<ScheduleSaveRejected>()),
      );
      await repository.confirm(command(planned));
      final exclusion = await db
          .select(db.recurringScheduleExclusions)
          .getSingle();
      expect(exclusion.segmentId, old.recurringSegmentId);
      expect(exclusion.slotKey, old.recurringSlotKey);
      await recurring.materialize(start, DateTime.utc(2030, 2, 1));
      expect((await rows()).where((e) => e.id == old.id), isEmpty);
    },
  );
  test(
    'actual started future occurrence remains in the closed source while its new slot is excluded',
    () async {
      final protected = (await rows())[1];
      final writer = ScheduleRepositoryImpl(
        database: db,
        timedPreparationRepository: _UnusedTimed(),
        now: () => now,
      );
      try {
        await writer.startSchedule(protected.id, startedAt: now);
      } finally {
        await writer.dispose();
      }
      final before =
          (await db
                  .customSelect(
                    'SELECT * FROM schedules WHERE id = ?',
                    variables: [Variable<String>(protected.id)],
                  )
                  .getSingle())
              .data;
      final planned = await review();
      expect(planned.mapping.protectedRows.map((e) => e.id), [protected.id]);
      expect(planned.mapping.protectedSlots.single.ordinal, 2);
      await repository.confirm(command(planned));
      final after =
          (await db
                  .customSelect(
                    'SELECT * FROM schedules WHERE id = ?',
                    variables: [Variable<String>(protected.id)],
                  )
                  .getSingle())
              .data;
      expect(after, before);
      final retained = (await rows()).singleWhere((e) => e.id == protected.id);
      expect(retained.retainedRecurringReference, isTrue);
      expect(retained.isStarted, isTrue);
      final excluded = await db
          .select(db.recurringScheduleExclusions)
          .getSingle();
      expect(excluded.ordinal, 2);
      expect(excluded.segmentId, isNot(protected.recurringSegmentId));
      await recurring.materialize(start, DateTime.utc(2030, 2, 1));
      expect(await rows(), hasLength(3));
    },
  );

  test(
    'a later same-series edit invalidates an old exact retry receipt',
    () async {
      final plan = command(await review());
      await repository.confirm(plan);
      final other = (await rows()).last;
      await db.customStatement(
        "UPDATE schedules SET schedule_note = 'later edit' WHERE id = ?",
        [other.id],
      );
      final before = await contents();
      await expectLater(
        repository.confirm(plan),
        throwsA(isA<ScheduleSaveRejected>()),
      );
      expect(await contents(), before);
    },
  );
}

class _UnusedTimed extends Fake implements TimedPreparationRepository {}
