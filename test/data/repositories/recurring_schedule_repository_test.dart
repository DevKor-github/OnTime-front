import 'package:on_time_front/domain/entities/schedule_save.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/data/repositories/recurring_schedule_repository_impl.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';

void main() {
  late AppDatabase db;
  late RecurringScheduleRepositoryImpl repository;
  var now = DateTime.utc(2026, 1, 1);
  final start = DateTime.utc(2026, 1, 2, 10);
  RecurrenceRule daily({int count = 10, DateTime? at}) => RecurrenceRule(
    frequency: RecurrenceFrequency.daily,
    start: at ?? start,
    timeZoneId: 'UTC',
    count: count,
  );
  Future<List<ScheduleEntity>> rows() async =>
      (await db.scheduleDao.getScheduleList())
          .map((r) => r.toScheduleEntity())
          .toList()
        ..sort((a, b) => a.scheduleTime.compareTo(b.scheduleTime));

  setUp(() async {
    now = DateTime.utc(2026, 1, 1);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = RecurringScheduleRepositoryImpl(db, now: () => now);
    await db.userDao.putUser(
      const UserEntity(
        id: 'local-profile',
        spareTime: Duration.zero,
        note: '',
        isOnboardingCompleted: true,
      ),
    );
  });
  tearDown(() => db.close());

  test(
    'series owns reusable preparation and direct duplicate create rejects missing intent receipt',
    () async {
      await repository.create(_schedule('a', start), _prep(), daily(count: 3));
      await expectLater(
        repository.create(_schedule('a', start), _prep(), daily(count: 3)),
        throwsA(isA<ScheduleSaveRejected>()),
      );
      await repository.create(
        _schedule('b', start.add(const Duration(hours: 2))),
        _prep(),
        daily(count: 2, at: start.add(const Duration(hours: 2))),
      );
      final segments = await repository.getSegments();
      expect(segments, hasLength(2));
      expect(segments.map((s) => s.preparationId).toSet(), hasLength(2));
      expect(await rows(), hasLength(5));
      expect(
        (await rows())
            .where((s) => s.recurringSegmentId == segments.first.id)
            .map((s) => s.preparationDefinitionId)
            .toSet(),
        {segments.first.preparationId},
      );
      expect(
        segments.first.preparation.preparationStepList.single.id,
        isNot('source-step'),
      );
    },
  );

  test(
    'deleting one occurrence never refills the count after rematerialization',
    () async {
      await repository.create(_schedule('a', start), _prep(), daily());
      final deleted = (await rows())[3];
      await repository.delete(deleted, RecurringEditScope.occurrence);
      await repository.materialize(start, DateTime.utc(2028));
      final remaining = await rows();
      expect(remaining, hasLength(9));
      expect(remaining.any((s) => s.id == deleted.id), isFalse);
      expect(
        remaining.last.occurrenceInstantUtc,
        DateTime.utc(2026, 1, 11, 10),
      );
    },
  );

  test(
    'after three elapsed slots, two detached overrides leave five recurring and two standalone',
    () async {
      await repository.create(_schedule('a', start), _prep(), daily());
      final initial = await rows();
      for (final s in initial.where(
        (s) => [6, 8].contains(s.scheduleTime.day),
      )) {
        await repository.updateOccurrence(
          s,
          s.copyWith(scheduleName: 'special ${s.scheduleTime.day}'),
          _prep('special'),
          preparationChanged: true,
        );
      }
      now = DateTime.utc(2026, 1, 5);
      final anchor = (await rows()).firstWhere((s) => s.scheduleTime.day == 5);
      final rule = RecurrenceRule(
        frequency: RecurrenceFrequency.weekly,
        start: anchor.scheduleTime,
        timeZoneId: 'UTC',
        weekdays: {1, 3, 5},
        count: 10,
      );
      final review = await repository.reviewFollowing(
        anchor,
        anchor.copyWith(scheduleName: 'new'),
        _prep('new'),
        rule,
      );
      expect(review.detached, hasLength(2));
      expect(review.totalOccurrences, 5);
      await expectLater(
        repository.updateFollowing(anchor, anchor, _prep('new'), rule),
        throwsA(isA<RecurrenceNeedsReview>()),
      );
      expect((await repository.getSegments()), hasLength(1));
      await repository.updateFollowing(
        anchor,
        anchor.copyWith(scheduleName: 'new'),
        _prep('new'),
        rule,
        confirmDetached: true,
      );
      await repository.materialize(start, DateTime.utc(2028));
      final all = await rows();
      final future = all
          .where((s) => !s.occurrenceInstantUtc.isBefore(now))
          .toList();
      expect(future, hasLength(7));
      expect(future.where((s) => s.isRecurring), hasLength(5));
      expect(future.where((s) => !s.isRecurring), hasLength(2));
      expect(
        all.where((s) => s.occurrenceInstantUtc.isBefore(now)).map((s) => s.id),
        initial.take(3).map((s) => s.id),
      );
      for (final s in future.where((s) => !s.isRecurring)) {
        expect(
          (await repository.getPreparation(
            s.preparationDefinitionId!,
          )).preparationStepList.single.preparationName,
          'special',
        );
      }
      expect(
        (await db.userDao.getUserById('local-profile'))!.eligibleOutcomeCount,
        0,
      );
    },
  );

  test(
    'a detached occurrence and a later new slot on its original date remain distinct',
    () async {
      await repository.create(_schedule('a', start), _prep(), daily(count: 4));
      final original = await rows();
      await repository.updateOccurrence(
        original[1],
        original[1].copyWith(
          scheduleTime: original[1].scheduleTime.add(const Duration(hours: 5)),
        ),
        _prep(),
        preparationChanged: false,
      );
      final weekly = RecurrenceRule(
        frequency: RecurrenceFrequency.weekly,
        start: start,
        timeZoneId: 'UTC',
        weekdays: {start.weekday},
        count: 4,
      );
      await repository.updateFollowing(
        original.first,
        original.first,
        _prep(),
        weekly,
        confirmDetached: true,
      );
      final before = await rows();
      final detached = before.singleWhere((s) => !s.isRecurring);
      final anchor = before.firstWhere((s) => s.isRecurring);
      await repository.updateFollowing(
        anchor,
        anchor,
        _prep(),
        daily(count: 3),
        confirmDetached: true,
      );
      await repository.materialize(start, DateTime.utc(2027));
      final after = await rows();
      expect(after, hasLength(4));
      expect(after.where((s) => s.isRecurring), hasLength(3));
      expect(after.singleWhere((s) => !s.isRecurring).id, detached.id);
      expect(after.map((s) => s.id).toSet(), hasLength(4));
      expect(
        after
            .where((s) => s.scheduleTime.day == 3)
            .map((s) => s.scheduleTime.hour),
        [10, 15],
      );
    },
  );

  test(
    'bulk changes preserve only overridden fields and preparation',
    () async {
      await repository.create(_schedule('a', start), _prep(), daily(count: 3));
      final initial = await rows();
      await repository.updateOccurrence(
        initial[1],
        initial[1].copyWith(
          scheduleName: 'personal',
          place: const PlaceEntity(
            id: 'draft-personal-place',
            placeName: 'Personal place',
          ),
        ),
        _prep('personal prep'),
        preparationChanged: true,
      );
      final personalBefore = (await rows())[1];
      final definitionBefore = await repository.getPreparation(
        personalBefore.preparationDefinitionId!,
      );
      await repository.updateFollowing(
        initial.first,
        initial.first.copyWith(
          scheduleName: 'shared',
          scheduleTime: start.add(const Duration(hours: 1)),
        ),
        _prep('shared prep'),
        daily(count: 3, at: start.add(const Duration(hours: 1))),
      );
      final all = await rows();
      expect(all.map((s) => s.scheduleTime.hour), everyElement(11));
      expect(all.map((s) => s.scheduleName), ['shared', 'personal', 'shared']);
      expect(all[1].place, personalBefore.place);
      expect(
        all[1].preparationDefinitionId,
        personalBefore.preparationDefinitionId,
      );
      expect(
        await repository.getPreparation(all[1].preparationDefinitionId!),
        definitionBefore,
      );
      expect(
        (await db.select(db.places).get()).any(
          (p) => p.id == personalBefore.place.id,
        ),
        isTrue,
      );
      expect(
        (await repository.getPreparation(
          all[1].preparationDefinitionId!,
        )).preparationStepList.single.preparationName,
        'personal prep',
      );
      expect(
        (await repository.getPreparation(
          all.first.preparationDefinitionId!,
        )).preparationStepList.single.preparationName,
        'shared prep',
      );
    },
  );

  test(
    'ending following leaves active and historical rows and their preparations intact',
    () async {
      await repository.create(_schedule('a', start), _prep(), daily(count: 4));
      final initial = await rows();
      now = DateTime.utc(2026, 1, 3, 9, 55);
      await db.scheduleDao.updateSchedule(
        initial[1].toScheduleRow().copyWith(
          isStarted: true,
          preparationFrozen: true,
          startedAt: Value(now),
        ),
      );
      await repository.delete(initial[1], RecurringEditScope.following);
      await repository.materialize(start, DateTime.utc(2028));
      final all = await rows();
      expect(all.map((s) => s.id), initial.take(2).map((s) => s.id));
      expect(all.last.isStarted, isTrue);
      expect(
        all.last.preparationDefinitionId,
        initial[1].preparationDefinitionId,
      );
    },
  );

  test(
    'finite conflicts require explicit exclusion and excluded slots consume count',
    () async {
      await db.scheduleDao.createSchedule(
        _schedule(
          'single',
          start.add(const Duration(days: 1)),
        ).toScheduleWithPlaceRow(),
      );
      final rule = daily(count: 3);
      final review = await repository.review(
        _schedule('a', start),
        _prep(),
        rule,
      );
      expect(review.conflicts, hasLength(1));
      await expectLater(
        repository.create(_schedule('a', start), _prep(), rule),
        throwsA(isA<RecurrenceNeedsReview>()),
      );
      expect(await repository.getSegments(), isEmpty);
      await repository.create(
        _schedule('a', start),
        _prep(),
        rule,
        excludedSlots: {review.conflicts.single.slot.key},
      );
      expect((await rows()).where((s) => s.isRecurring), hasLength(2));
    },
  );

  test(
    'place edits never rename another occurrence or historical place',
    () async {
      await repository.create(_schedule('a', start), _prep(), daily(count: 3));
      final original = await rows();
      await repository.updateOccurrence(
        original[1],
        original[1].copyWith(
          place: PlaceEntity(id: original[1].place.id, placeName: 'Cafe'),
        ),
        _prep(),
        preparationChanged: false,
      );
      expect((await rows()).map((s) => s.place.placeName), [
        'Office',
        'Cafe',
        'Office',
      ]);
      now = DateTime.utc(2026, 1, 3);
      final anchor = (await rows())[1];
      await repository.updateFollowing(
        anchor,
        anchor.copyWith(
          place: PlaceEntity(id: anchor.place.id, placeName: 'Library'),
        ),
        _prep(),
        daily(at: DateTime.utc(2026, 1, 3, 10)),
      );
      expect((await rows()).map((s) => s.place.placeName), [
        'Office',
        'Cafe',
        'Library',
      ]);
    },
  );

  test(
    'bulk edit preserves active preparation and consumes its original count',
    () async {
      await repository.create(_schedule('a', start), _prep(), daily(count: 4));
      final initial = await rows();
      now = DateTime.utc(2026, 1, 3, 9, 55);
      await db.scheduleDao.updateSchedule(
        initial[1].toScheduleRow().copyWith(
          isStarted: true,
          preparationFrozen: true,
          startedAt: Value(now),
        ),
      );
      final changed = initial[1].copyWith(
        scheduleTime: DateTime.utc(2026, 1, 3, 11),
      );
      await repository.updateFollowing(
        initial[1],
        changed,
        _prep('new prep'),
        daily(at: changed.scheduleTime),
      );
      await repository.materialize(start, DateTime.utc(2027));
      final all = await rows();
      expect(all, hasLength(4));
      expect(all[1].isStarted, isTrue);
      expect(all[1].scheduleTime.hour, 10);
      expect(
        all[1].preparationDefinitionId,
        initial[1].preparationDefinitionId,
      );
      expect(all.skip(2).map((s) => s.scheduleTime.hour), [11, 11]);
    },
  );

  test(
    'stale first occurrence approval asks for review without changing durable data',
    () async {
      final check = await repository.review(
        _schedule('a', start),
        _prep(),
        daily(count: 3),
      );
      now = DateTime.utc(2026, 1, 2, 9, 51);
      await expectLater(
        repository.create(
          _schedule('a', start),
          _prep(),
          daily(count: 3),
          reviewedFirstSlotKey: check.slots.first.key,
        ),
        throwsA(isA<RecurrenceNeedsReview>()),
      );
      expect(await repository.getSegments(), isEmpty);
      expect(await rows(), isEmpty);
    },
  );

  test('explicit count edit replaces the remaining budget', () async {
    await repository.create(_schedule('a', start), _prep(), daily());
    now = DateTime.utc(2026, 1, 5);
    final anchor = (await rows()).firstWhere((s) => s.scheduleTime.day == 5);
    await repository.updateFollowing(
      anchor,
      anchor,
      _prep(),
      daily(at: DateTime.utc(2026, 1, 5, 10), count: 2),
      countChanged: true,
    );
    expect(
      (await rows()).where((s) => !s.occurrenceInstantUtc.isBefore(now)),
      hasLength(2),
    );
  });

  test(
    'a deleted slot remains consumed when the new weekdays omit that date',
    () async {
      await repository.create(_schedule('a', start), _prep(), daily());
      final all = await rows();
      await repository.delete(
        all.firstWhere((s) => s.scheduleTime.day == 6),
        RecurringEditScope.occurrence,
      );
      now = DateTime.utc(2026, 1, 5);
      final anchor = all.firstWhere((s) => s.scheduleTime.day == 5);
      await repository.updateFollowing(
        anchor,
        anchor,
        _prep(),
        RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          start: DateTime.utc(2026, 1, 5, 10),
          timeZoneId: 'UTC',
          weekdays: {1, 3, 5},
          count: 10,
        ),
      );
      expect(
        (await rows()).where((s) => !s.occurrenceInstantUtc.isBefore(now)),
        hasLength(6),
      );
    },
  );

  test(
    'unbounded series detects persistent rule collisions and stores only nearby occurrences',
    () async {
      final rule = RecurrenceRule(
        frequency: RecurrenceFrequency.weekly,
        start: start,
        timeZoneId: 'UTC',
        weekdays: {1, 3, 5},
      );
      await repository.create(_schedule('a', start), _prep(), rule);
      expect(await rows(), hasLength(60));
      final check = await repository.review(
        _schedule('b', start),
        _prep(),
        rule,
      );
      expect(check.persistentConflict, isTrue);
      await expectLater(
        repository.create(_schedule('b', start), _prep(), rule),
        throwsA(isA<RecurrenceNeedsReview>()),
      );
      expect(await repository.getSegments(), hasLength(1));
    },
  );

  test(
    'unbounded daily intervals prove conflicts beyond deleted occurrences',
    () async {
      final first = RecurrenceRule(
        frequency: RecurrenceFrequency.daily,
        start: start,
        timeZoneId: 'UTC',
      );
      await repository.create(_schedule('every-day', start), _prep(), first);
      for (final occurrence in await rows()) {
        await repository.delete(occurrence, RecurringEditScope.occurrence);
      }
      final everyOtherDay = RecurrenceRule(
        frequency: RecurrenceFrequency.daily,
        interval: 2,
        start: start,
        timeZoneId: 'UTC',
      );
      final conflict = await repository.review(
        _schedule('alternate', start),
        _prep(),
        everyOtherDay,
      );
      expect(conflict.persistentConflict, isTrue);
      expect(
        conflict.conflicts.first.slot.civilTime.isAfter(
          start.add(const Duration(days: 59)),
        ),
        isTrue,
      );
      final clearRule = RecurrenceRule(
        frequency: RecurrenceFrequency.daily,
        interval: 2,
        start: start.add(const Duration(hours: 3)),
        timeZoneId: 'UTC',
      );
      await repository.create(
        _schedule('later', clearRule.start),
        _prep(),
        clearRule,
      );
      expect(await repository.getSegments(), hasLength(2));
    },
  );

  test(
    'an override cannot be moved into another occurrence preparation window',
    () async {
      await repository.create(_schedule('a', start), _prep(), daily(count: 3));
      final all = await rows();
      await expectLater(
        repository.updateOccurrence(
          all.first,
          all.first.copyWith(
            scheduleTime: all[1].scheduleTime.subtract(
              const Duration(minutes: 5),
            ),
          ),
          _prep(),
          preparationChanged: false,
        ),
        throwsA(isA<RecurrenceNeedsReview>()),
      );
      expect((await rows()).first.occurrenceInstantUtc, start);
    },
  );
}

ScheduleEntity _schedule(String id, DateTime time) => ScheduleEntity(
  id: id,
  place: const PlaceEntity(id: 'place', placeName: 'Office'),
  scheduleName: id,
  scheduleTime: time,
  timeZoneId: 'UTC',
  occurrenceOffsetSeconds: 0,
  moveTime: Duration.zero,
  isChanged: false,
  isStarted: false,
  scheduleSpareTime: Duration.zero,
  scheduleNote: '',
);
PreparationEntity _prep([String name = 'get ready']) => PreparationEntity(
  preparationStepList: [
    PreparationStepEntity(
      id: 'source-step',
      preparationName: name,
      preparationTime: const Duration(minutes: 10),
      nextPreparationId: null,
    ),
  ],
);
