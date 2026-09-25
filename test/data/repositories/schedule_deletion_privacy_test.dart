import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import '../../helpers/schedule_deletion_fixture.dart';

void main() {
  late ScheduleDeletionFixture f;
  setUp(() async {
    f = ScheduleDeletionFixture();
    await f.initialize();
  });
  tearDown(() => f.close());

  for (final status in ScheduleDoneStatus.values) {
    test(
      '$status history deletion removes owned text and preserves score',
      () async {
        await f.create('remove');
        await f.create('keep');
        await f.outcome('remove', status);
        await f.outcome('keep', ScheduleDoneStatus.lateEnd);
        f.now = DateTime.utc(2031);
        final beforeScore = await f.score();
        final beforeRevision = await f.revision();
        final keep = (await f.db.scheduleDao.getScheduleById('keep')).schedule;
        final steps = await (f.db.select(
          f.db.preparationSchedules,
        )..where((t) => t.scheduleId.equals('remove'))).get();
        expect(steps, hasLength(2));
        expect(steps.where((s) => s.nextPreparationId != null), hasLength(1));
        expect(
          (await f.db.customSelect('PRAGMA foreign_keys').getSingle())
              .data
              .values
              .single,
          1,
        );

        final intent = await f.aggregate.readForDeletion('remove');
        final commit = await f.aggregate.delete(intent);

        expect(commit.removedIds, {'remove'});
        expect(commit.changed, isTrue);
        expect(await f.revision(), beforeRevision + 1);
        expect(await f.score(), beforeScore);
        expect(
          await (f.db.select(
            f.db.schedules,
          )..where((t) => t.id.equals('remove'))).get(),
          isEmpty,
        );
        expect(
          await (f.db.select(
            f.db.preparationSchedules,
          )..where((t) => t.scheduleId.equals('remove'))).get(),
          isEmpty,
        );
        expect(
          await (f.db.select(
            f.db.places,
          )..where((t) => t.id.equals('place-remove'))).get(),
          isEmpty,
        );
        expect((await f.db.scheduleDao.getScheduleById('keep')).schedule, keep);
        expect(
          await f.db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      },
    );
  }

  test(
    'deletion after score reset cannot resurrect or decrement old contributions',
    () async {
      await f.create('old');
      await f.create('new');
      await f.create('retained-old');
      await f.create('after-deletion');
      await f.outcome('old', ScheduleDoneStatus.normalEnd);
      await f.outcome('retained-old', ScheduleDoneStatus.normalEnd);
      await f.db.userDao.resetScore('local-profile');
      await f.outcome('new', ScheduleDoneStatus.lateEnd);
      expect(await f.score(), (eligible: 1, onTime: 0));
      final retained = (await f.db.scheduleDao.getScheduleById(
        'retained-old',
      )).schedule;
      expect(retained.scoreContributionRecorded, isTrue);
      expect(
        (await f.db.scheduleDao.getScheduleById(
          'old',
        )).schedule.scoreContributionRecorded,
        isTrue,
      );
      expect(
        (await f.db.scheduleDao.getScheduleById(
          'new',
        )).schedule.scoreContributionRecorded,
        isTrue,
      );
      f.now = DateTime.utc(2031);

      await f.aggregate.delete(await f.aggregate.readForDeletion('old'));
      expect(await f.score(), (eligible: 1, onTime: 0));
      await f.aggregate.delete(await f.aggregate.readForDeletion('new'));
      expect(await f.score(), (eligible: 1, onTime: 0));
      expect(
        (await f.db.scheduleDao.getScheduleById('retained-old')).schedule,
        retained,
      );
      // Reset has no timestamp column: preserved completion/contribution markers
      // prevent old outcomes from re-entering the new aggregation period.
      await f.schedules.finishSchedule('retained-old', 0);
      expect(await f.score(), (eligible: 1, onTime: 0));
      await f.outcome('after-deletion', ScheduleDoneStatus.normalEnd);
      expect(await f.score(), (eligible: 2, onTime: 1));
    },
  );

  test(
    'shared Place uses actual references; same-name orphan is never swept',
    () async {
      const shared = PlaceEntity(id: 'shared-place', placeName: 'Same name');
      await f.create('remove', place: shared);
      await f.create('keep', place: shared);
      await f.db
          .into(f.db.places)
          .insert(
            PlacesCompanion.insert(
              id: const Value('unrelated-orphan'),
              placeName: 'Same name',
            ),
          );
      f.now = DateTime.utc(2031);

      await f.aggregate.delete(await f.aggregate.readForDeletion('remove'));
      expect((await f.db.select(f.db.places).get()).map((p) => p.id).toSet(), {
        'shared-place',
        'unrelated-orphan',
      });
      expect(
        (await f.db.scheduleDao.getScheduleById('keep')).place.id,
        'shared-place',
      );
      await f.aggregate.delete(await f.aggregate.readForDeletion('keep'));
      expect((await f.db.select(f.db.places).get()).map((p) => p.id), [
        'unrelated-orphan',
      ]);
    },
  );

  test(
    'last materialized occurrence retains Place referenced only by segment JSON',
    () async {
      final at = DateTime.utc(2030, 1, 2, 10);
      await f.recurring.create(
        f.schedule('series', at: at),
        f.preparation('shared-series'),
        RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          start: at,
          timeZoneId: 'UTC',
          count: 1,
        ),
      );
      final row = (await f.db.scheduleDao.getScheduleList()).single
          .toScheduleEntity();
      final segments = await f.db.select(f.db.recurringScheduleSegments).get();
      final definitions = await f.db.select(f.db.preparationDefinitions).get();
      f.now = DateTime.utc(2031);
      final before = await f.revision();

      await f.aggregate.delete(await f.aggregate.readForDeletion(row.id));

      expect(await f.db.select(f.db.schedules).get(), isEmpty);
      expect(await f.revision(), before + 1);
      final currentSegments = await f.db
          .select(f.db.recurringScheduleSegments)
          .get();
      expect(currentSegments, hasLength(1));
      final current = currentSegments.single;
      final beforeSegment = segments.single;
      // Exclusion updates local concurrency metadata, not the reusable rule.
      expect(current.id, beforeSegment.id);
      expect(current.seriesId, beforeSegment.seriesId);
      expect(current.ruleJson, beforeSegment.ruleJson);
      expect(current.scheduleJson, beforeSegment.scheduleJson);
      expect(current.preparationId, beforeSegment.preparationId);
      expect(current.fromSlot, beforeSegment.fromSlot);
      expect(current.beforeSlot, beforeSegment.beforeSlot);
      expect(current.preparationNotBefore, beforeSegment.preparationNotBefore);
      expect(await f.db.select(f.db.preparationDefinitions).get(), definitions);
      expect((await f.db.select(f.db.places).get()).map((p) => p.id), [
        row.place.id,
      ]);
      await f.recurring.materialize(at, DateTime.utc(2032));
      expect(await f.db.select(f.db.schedules).get(), isEmpty);
      final exclusion =
          (await f.db.select(f.db.recurringScheduleExclusions).get()).single;
      expect(exclusion.segmentId, row.recurringSegmentId);
      expect(exclusion.slotKey, row.recurringSlotKey);
      expect(exclusion.ordinal, row.recurringOrdinal);
    },
  );

  test(
    'occurrence override definition is erased while shared series survives',
    () async {
      final at = DateTime.utc(2030, 1, 2, 10);
      await f.recurring.create(
        f.schedule('series', at: at),
        f.preparation('shared-series'),
        RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          start: at,
          timeZoneId: 'UTC',
          count: 2,
        ),
      );
      final initial = await f.db.scheduleDao.getScheduleList();
      final target = initial.first.toScheduleEntity();
      final other = initial.last.toScheduleEntity();
      final sharedDefinition = target.preparationDefinitionId!;
      await f.recurring.updateOccurrence(
        target,
        target.copyWith(scheduleName: 'Private override'),
        f.preparation('private-override'),
        preparationChanged: true,
      );
      final edited = (await f.db.scheduleDao.getScheduleById(
        target.id,
      )).toScheduleEntity();
      final ownedDefinition = edited.preparationDefinitionId!;
      expect(ownedDefinition, isNot(sharedDefinition));
      // Deliberately collide human-readable names across distinct live IDs.
      await f.db
          .update(f.db.preparationDefinitions)
          .write(
            const PreparationDefinitionsCompanion(
              name: Value('Identical definition'),
            ),
          );
      await f.db
          .update(f.db.preparationDefinitionSteps)
          .write(
            const PreparationDefinitionStepsCompanion(
              name: Value('Identical step'),
            ),
          );
      final sharedBefore = await (f.db.select(
        f.db.preparationDefinitions,
      )..where((t) => t.id.equals(sharedDefinition))).get();
      final sharedStepsBefore = await (f.db.select(
        f.db.preparationDefinitionSteps,
      )..where((t) => t.definitionId.equals(sharedDefinition))).get();
      await f.outcome(edited.id, ScheduleDoneStatus.abnormalEnd);
      f.now = DateTime.utc(2031);

      await f.aggregate.delete(await f.aggregate.readForDeletion(edited.id));

      expect(
        await (f.db.select(
          f.db.preparationDefinitions,
        )..where((t) => t.id.equals(ownedDefinition))).get(),
        isEmpty,
      );
      expect(
        await (f.db.select(
          f.db.preparationDefinitionSteps,
        )..where((t) => t.definitionId.equals(ownedDefinition))).get(),
        isEmpty,
      );
      expect(
        await (f.db.select(
          f.db.preparationDefinitions,
        )..where((t) => t.id.equals(sharedDefinition))).get(),
        sharedBefore,
      );
      expect(
        await (f.db.select(
          f.db.preparationDefinitionSteps,
        )..where((t) => t.definitionId.equals(sharedDefinition))).get(),
        sharedStepsBefore,
      );
      expect(
        (await f.db.scheduleDao.getScheduleById(other.id)).toScheduleEntity(),
        other,
      );
      await f.recurring.materialize(at, DateTime.utc(2032));
      expect((await f.db.select(f.db.schedules).get()).map((s) => s.id), [
        other.id,
      ]);
      expect(
        await f.db.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );
}
