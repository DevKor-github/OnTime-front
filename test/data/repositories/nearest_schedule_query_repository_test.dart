import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
import 'dart:async';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/data/repositories/nearest_schedule_query_repository_impl.dart';
import 'package:on_time_front/data/repositories/recurring_schedule_repository_impl.dart';
import 'package:on_time_front/domain/entities/nearest_schedule_query.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'package:on_time_front/domain/repositories/nearest_schedule_query_repository.dart';
import 'package:on_time_front/domain/use-cases/get_nearest_upcoming_schedule_use_case.dart';

// Transparent work counters; all answers still come from production SQLite.
class _ObservedQueryRepository implements NearestScheduleQueryRepository {
  _ObservedQueryRepository(this.delegate);
  final NearestScheduleQueryRepository delegate;
  int inFlight = 0;
  int opens = 0;
  int changesSeen = 0;
  @override
  Stream<void> get changes => delegate.changes.map((_) {
    changesSeen++;
  });
  @override
  Future<NearestScheduleQuerySession> open(NearestQueryKey key) async {
    opens++;
    inFlight++;
    try {
      return _ObservedQuerySession(await delegate.open(key), this);
    } finally {
      inFlight--;
    }
  }

  @override
  Future<ScheduleWithPreparationEntity?> readActive() => delegate.readActive();
}

class _ObservedQuerySession implements NearestScheduleQuerySession {
  _ObservedQuerySession(this.delegate, this.observer);
  final NearestScheduleQuerySession delegate;
  final _ObservedQueryRepository observer;
  @override
  Future<NearestScheduleQuery> advance({required int candidateBudget}) async {
    observer.inFlight++;
    try {
      return await delegate.advance(candidateBudget: candidateBudget);
    } finally {
      observer.inFlight--;
    }
  }

  @override
  void cancel() => delegate.cancel();
}

void main() {
  late AppDatabase db;
  late RecurringScheduleRepositoryImpl recurring;
  late NearestScheduleQueryRepositoryImpl repository;
  late DateTime now;
  ScheduleEntity schedule(String id, DateTime time) => ScheduleEntity(
    id: id,
    place: PlaceEntity(id: 'place-$id', placeName: 'Office'),
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
  const prep = PreparationEntity(
    preparationStepList: [
      PreparationStepEntity(
        id: 'step',
        preparationName: 'Pack',
        preparationTime: Duration(minutes: 5),
      ),
    ],
  );
  NearestQueryKey key() => NearestQueryKey(
    generation: LocalDataOperationGate.shared.generation,
    epoch: 1,
    revision: 0,
  );
  Future<NearestScheduleQuery> finish(
    NearestScheduleQuerySession session, {
    int chunk = 16,
  }) async {
    while (true) {
      final result = await session.advance(candidateBudget: chunk);
      if (result is! NearestQueryLimited || !result.canContinue) return result;
    }
  }

  Future<void> insert(ScheduleEntity value) => db.scheduleDao
      .createSchedule(value.toScheduleWithPlaceRow())
      .then((_) {});
  setUp(() async {
    now = DateTime.utc(2030, 1, 1, 12);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    recurring = RecurringScheduleRepositoryImpl(db, now: () => now);
    repository = NearestScheduleQueryRepositoryImpl(
      db,
      recurring,
      now: () => now,
    );
    await db.userDao.putUser(
      const UserEntity(id: 'local-profile', spareTime: Duration.zero, note: ''),
    );
  });
  tearDown(() => db.close());

  test(
    'global future selection has no 48-hour cutoff, skips ended, ties by stable ID',
    () async {
      final time = now.add(const Duration(days: 30));
      await insert(schedule('z', time));
      await insert(schedule('a', time));
      await insert(
        schedule(
          'ended',
          now.add(const Duration(hours: 1)),
        ).copyWith(doneStatus: ScheduleDoneStatus.normalEnd),
      );
      await insert(schedule('past', now.subtract(const Duration(hours: 1))));
      final result =
          await finish(await repository.open(key())) as NearestQueryReady;
      expect(result.value.schedule.id, 'a');
      expect(result.value.schedule.preparation.preparationStepList, isEmpty);
      expect((await db.scheduleDao.getScheduleList()), hasLength(4));
    },
  );

  test(
    'unmaterialized nearer recurrence beats stored next week and only winner is materialized',
    () async {
      final first = now.add(const Duration(days: 1));
      await recurring.create(
        schedule('series', first),
        prep,
        RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          start: first,
          timeZoneId: 'UTC',
          count: 10,
        ),
      );
      // Remove cache rows only, retaining canonical rule/count/exclusions.
      await db.delete(db.schedules).go();
      await insert(schedule('next-week', now.add(const Duration(days: 7))));
      final session = await repository.open(key());
      final partial = await session.advance(candidateBudget: 1);
      expect(
        partial,
        isA<NearestQueryLimited>(),
        reason: 'The next unvisited civil frontier still needs proof.',
      );
      final result = await finish(session) as NearestQueryReady;
      expect(result.value.resolution.instantUtc, first);
      expect(
        result
            .value
            .schedule
            .preparation
            .preparationStepList
            .single
            .preparationName,
        'Pack',
      );
      expect(await db.scheduleDao.getScheduleList(), hasLength(2));
    },
  );

  test(
    'small total budget stays terminal limited despite stored candidate',
    () async {
      final first = now.add(const Duration(days: 1));
      await recurring.create(
        schedule('series', first),
        prep,
        RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          start: first,
          timeZoneId: 'UTC',
          count: 5,
        ),
      );
      await db.delete(db.schedules).go();
      await insert(schedule('stored', now.add(const Duration(days: 20))));
      final bounded = NearestScheduleQueryRepositoryImpl(
        db,
        recurring,
        now: () => now,
        totalBudget: 1,
      );
      final session = await bounded.open(key());
      final result =
          await session.advance(candidateBudget: 1024) as NearestQueryLimited;
      expect(result.reason, NearestQueryLimitReason.searchBudgetExhausted);
      expect(result.canContinue, isFalse);
      expect(result.canRetry, isFalse);
      expect(
        (await session.advance(candidateBudget: 1024) as NearestQueryLimited)
            .progress
            .visitedCandidates,
        1,
      );
      expect(await db.scheduleDao.getScheduleList(), hasLength(1));
    },
  );

  test(
    'snapshot change invalidates old search authority before publishing',
    () async {
      await insert(schedule('later', now.add(const Duration(days: 8))));
      final session = await repository.open(key());
      await insert(schedule('earlier', now.add(const Duration(days: 3))));
      await expectLater(
        session.advance(candidateBudget: 16),
        throwsA(isA<NearestQueryInvalidated>()),
      );
      final latest =
          await finish(await repository.open(key())) as NearestQueryReady;
      expect(latest.value.schedule.id, 'earlier');
    },
  );

  test(
    'durable active is read separately and future recommendation cannot replace it',
    () async {
      final active =
          schedule('active', now.subtract(const Duration(minutes: 1))).copyWith(
            isStarted: true,
            startedAt: now.subtract(const Duration(minutes: 5)),
            preparationFrozen: true,
          );
      await insert(active);
      await insert(schedule('future', now.add(const Duration(days: 3))));
      expect((await repository.readActive())!.id, 'active');
      expect(
        (await finish(await repository.open(key())) as NearestQueryReady)
            .value
            .schedule
            .id,
        'future',
      );
      expect(
        (await db.scheduleDao.getScheduleById(
          'active',
        )).toScheduleEntity().doneStatus,
        ScheduleDoneStatus.notEnded,
      );
    },
  );

  test(
    'preparation-only SQLite change refreshes the selected preparation',
    () async {
      final first = now.add(const Duration(days: 1));
      await recurring.create(
        schedule('series', first),
        prep,
        RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          start: first,
          timeZoneId: 'UTC',
          count: 1,
        ),
      );
      final seen = <NearestScheduleQuery>[];
      final firstReady = Completer<void>();
      final updatedReady = Completer<void>();
      final subscription =
          GetNearestUpcomingScheduleUseCase(repository, now: () => now)(
            key: key(),
          ).listen((query) {
            seen.add(query);
            if (query is NearestQueryReady) {
              final name = query
                  .value
                  .schedule
                  .preparation
                  .preparationStepList
                  .single
                  .preparationName;
              if (!firstReady.isCompleted) firstReady.complete();
              if (name == 'Updated' && !updatedReady.isCompleted) {
                updatedReady.complete();
              }
            }
          });
      try {
        await firstReady.future.timeout(const Duration(seconds: 5));
        await db
            .update(db.preparationDefinitionSteps)
            .write(
              const PreparationDefinitionStepsCompanion(name: Value('Updated')),
            );
        await updatedReady.future.timeout(const Duration(seconds: 5));
        expect(
          seen
              .whereType<NearestQueryReady>()
              .last
              .value
              .schedule
              .preparation
              .preparationStepList
              .single
              .preparationName,
          'Updated',
        );
      } finally {
        await subscription.cancel();
      }
    },
  );
  test(
    'different civil zones are ranked by instant, while unknown-only is a typed safe result',
    () async {
      await insert(
        schedule(
          'tokyo',
          DateTime.utc(2030, 1, 2, 9),
        ).copyWith(timeZoneId: 'Asia/Tokyo', occurrenceOffsetSeconds: 9 * 3600),
      );
      await insert(schedule('utc', DateTime.utc(2030, 1, 2, 1)));
      await insert(
        schedule(
          'unknown',
          DateTime.utc(2030, 1, 2),
        ).copyWith(timeZoneId: 'Unknown/Zone'),
      );
      final result =
          await finish(await repository.open(key())) as NearestQueryReady;
      expect(result.value.schedule.id, 'tokyo');
      expect(result.value.resolution.instantUtc, DateTime.utc(2030, 1, 2));
      expect(result.issues.single.scheduleId, 'unknown');
      await (db.delete(
        db.schedules,
      )..where((row) => row.id.isNotValue('unknown'))).go();
      final unresolved = await finish(await repository.open(key()));
      expect(unresolved, isA<NearestQueryError>());
      expect(
        (unresolved as NearestQueryError).issues.single.reason,
        NearestQueryIssueReason.unknownTimeZone,
      );
    },
  );

  test(
    'missing selected preparation rolls back winner materialization and never chooses later row',
    () async {
      final first = now.add(const Duration(days: 1));
      await recurring.create(
        schedule('series', first),
        prep,
        RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          start: first,
          timeZoneId: 'UTC',
          count: 1,
        ),
      );
      await db.delete(db.schedules).go();
      // Explicit corrupt-store fixture: preserve the dangling segment reference.
      await db.customStatement('PRAGMA foreign_keys = OFF');
      await db.delete(db.preparationDefinitionSteps).go();
      await db.delete(db.preparationDefinitions).go();
      await db.customStatement('PRAGMA foreign_keys = ON');
      await insert(schedule('later', now.add(const Duration(days: 20))));
      final result = await finish(await repository.open(key()));
      expect(
        result,
        isA<NearestQueryError>().having(
          (v) => v.reason,
          'missing is not empty/fallback',
          NearestQueryFailureReason.preparationMissing,
        ),
      );
      expect(
        (await db.scheduleDao.getScheduleList()).map((row) => row.schedule.id),
        ['later'],
      );
    },
  );
  test(
    'store generation replacement invalidates a suspended snapshot even when rows are unchanged',
    () async {
      await insert(schedule('future', now.add(const Duration(days: 8))));
      final session = await repository.open(key());
      await LocalDataOperationGate.shared.run(() async {}, replacesData: true);
      await expectLater(
        session.advance(candidateBudget: 16),
        throwsA(isA<NearestQueryInvalidated>()),
      );
      final current =
          await finish(await repository.open(key())) as NearestQueryReady;
      expect(
        current.value.authority.key.generation,
        LocalDataOperationGate.shared.generation,
      );
    },
  );
  test(
    'winner materialization and its actual SQLite watch converge without repeated materialization',
    () async {
      final first = now.add(const Duration(days: 1));
      await recurring.create(
        schedule('series', first),
        prep,
        RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          start: first,
          timeZoneId: 'UTC',
          count: 3,
        ),
      );
      await db.delete(db.schedules).go();
      final observer = _ObservedQueryRepository(repository);
      final seen = <NearestScheduleQuery>[];
      final ready = Completer<NearestQueryReady>();
      final subscription =
          GetNearestUpcomingScheduleUseCase(
            observer,
            now: () => now,
            chunkSize: 1,
          )(key: key()).listen((value) {
            seen.add(value);
            if (value is NearestQueryReady && !ready.isCompleted) {
              ready.complete(value);
            }
          });
      try {
        final selected = await ready.future.timeout(const Duration(seconds: 5));
        expect(selected.value.resolution.instantUtc, first);
        // Initial DAO delivery and the owned insertion may each produce a fresh
        // verified receipt. Require bounded quiescence, not exactly one receipt.
        var quietTurns = 0;
        var before = (observer.opens, seen.length, observer.changesSeen);
        for (var turn = 0; turn < 200 && quietTurns < 10; turn++) {
          await db.customSelect('SELECT 1').get();
          await Future<void>.delayed(Duration.zero);
          final after = (observer.opens, seen.length, observer.changesSeen);
          quietTurns = observer.inFlight == 0 && after == before
              ? quietTurns + 1
              : 0;
          before = after;
        }
        expect(
          quietTurns,
          10,
          reason:
              'Known initial/self-write signals must reach quiescence under a finite bound.',
        );
        expect(
          seen.whereType<NearestQueryReady>().length,
          inInclusiveRange(1, 2),
        );
        expect(
          observer.changesSeen,
          2,
          reason:
              'Only initial SQLite delivery and the one owned insert are expected.',
        );
        expect(observer.opens, lessThanOrEqualTo(observer.changesSeen + 1));
        expect(seen.whereType<NearestQueryError>(), isEmpty);
        final rows = await db.scheduleDao.getScheduleList();
        expect(rows, hasLength(1));
        expect(rows.single.schedule.id, selected.value.schedule.id);
        expect(
          selected.value.authority.dataRevision,
          (await db.select(db.users).getSingle()).dataRevision,
        );
      } finally {
        await subscription.cancel();
      }
    },
  );

  test(
    'excluded, moved override, completed and frozen slots cannot be recreated over a nearer unmaterialized winner',
    () async {
      final first = now.add(const Duration(days: 1));
      await recurring.create(
        schedule('series', first),
        prep,
        RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          start: first,
          timeZoneId: 'UTC',
          count: 6,
        ),
      );
      final initial =
          (await db.scheduleDao.getScheduleList())
              .map((v) => v.toScheduleEntity())
              .toList()
            ..sort((a, b) => a.scheduleTime.compareTo(b.scheduleTime));
      await recurring.delete(initial[0], RecurringEditScope.occurrence);
      await recurring.updateOccurrence(
        initial[1],
        initial[1].copyWith(scheduleTime: first.add(const Duration(days: 10))),
        prep,
        preparationChanged: false,
      );
      await db.scheduleDao.updateSchedule(
        initial[2]
            .copyWith(doneStatus: ScheduleDoneStatus.normalEnd)
            .toScheduleRow(),
      );
      await db.scheduleDao.updateSchedule(
        initial[3]
            .copyWith(isStarted: true, startedAt: now, preparationFrozen: true)
            .toScheduleRow(),
      );
      await (db.delete(
        db.schedules,
      )..where((row) => row.id.equals(initial[4].id))).go();
      final preserved = {
        for (final index in [1, 2, 3])
          initial[index].id: (await db.scheduleDao.getScheduleById(
            initial[index].id,
          )).schedule,
      };
      final result =
          await finish(await repository.open(key()), chunk: 1)
              as NearestQueryReady;
      expect(result.value.schedule.id, initial[4].id);
      expect(result.value.schedule.recurringOrdinal, 5);
      expect((await repository.readActive())!.id, initial[3].id);
      final rows = await db.scheduleDao.getScheduleList();
      expect(rows, hasLength(5));
      expect(rows.any((row) => row.schedule.id == initial[0].id), isFalse);
      for (final entry in preserved.entries) {
        expect(
          (await db.scheduleDao.getScheduleById(entry.key)).schedule,
          entry.value,
        );
      }
      expect(
        await db.select(db.recurringScheduleExclusions).get(),
        hasLength(1),
      );
    },
  );
}
