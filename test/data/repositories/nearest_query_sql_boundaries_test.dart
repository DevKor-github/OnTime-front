import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' hide isNull;
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
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'package:on_time_front/domain/repositories/nearest_schedule_query_repository.dart';
import 'package:on_time_front/domain/use-cases/get_nearest_upcoming_schedule_use_case.dart';

const _prep = PreparationEntity(
  preparationStepList: [
    PreparationStepEntity(
      id: 'prepare',
      preparationName: 'Pack',
      preparationTime: Duration(minutes: 5),
    ),
  ],
);
ScheduleEntity _schedule(String id, DateTime time) => ScheduleEntity(
  id: id,
  place: PlaceEntity(id: 'place-$id', placeName: 'Synthetic place'),
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
NearestQueryKey _key() => NearestQueryKey(
  generation: LocalDataOperationGate.shared.generation,
  epoch: 1,
  revision: 0,
);
Future<NearestScheduleQuery> _finish(
  NearestScheduleQuerySession session,
) async {
  while (true) {
    final result = await session.advance(candidateBudget: 1024);
    if (result is! NearestQueryLimited || !result.canContinue) {
      return result;
    }
  }
}

class _SelectedPreparationFailure extends QueryInterceptor {
  bool armed = false;
  int injected = 0;
  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    // Snapshot SELECT * is deliberately unaffected; fail only the selected
    // definition's real one-shot ordered preparation query after materialization.
    if (armed &&
        statement.contains('preparation_definition_steps') &&
        statement.contains('WHERE') &&
        statement.contains('ORDER BY')) {
      armed = false;
      injected++;
      throw StateError('Synthetic selected preparation SQL read failure');
    }
    return executor.runSelect(statement, args);
  }
}

// Transparent observation around real SQLite query sessions. It never replaces
// candidates, results, database writes, cancellation or the source change stream.
class _MeasuredRepository implements NearestScheduleQueryRepository {
  _MeasuredRepository(this.inner);
  final NearestScheduleQueryRepository inner;
  int heartbeat = 0;
  int opens = 0;
  final chunkMicros = <int>[];
  final chunkSynchronousMicros = <int>[];
  final heartbeatAtEntry = <int>[];
  @override
  Stream<void> get changes => inner.changes;
  @override
  Future<ScheduleWithPreparationEntity?> readActive() => inner.readActive();
  @override
  Future<NearestScheduleQuerySession> open(NearestQueryKey key) async {
    opens++;
    return _MeasuredSession(await inner.open(key), this);
  }
}

class _MeasuredSession implements NearestScheduleQuerySession {
  _MeasuredSession(this.inner, this.owner);
  final NearestScheduleQuerySession inner;
  final _MeasuredRepository owner;
  @override
  void cancel() => inner.cancel();
  @override
  Future<NearestScheduleQuery> advance({required int candidateBudget}) async {
    owner.heartbeatAtEntry.add(owner.heartbeat);
    final watch = Stopwatch()..start();
    try {
      final pending = inner.advance(candidateBudget: candidateBudget);
      owner.chunkSynchronousMicros.add(watch.elapsedMicroseconds);
      return await pending;
    } finally {
      owner.chunkMicros.add(watch.elapsedMicroseconds);
      Timer.run(() => owner.heartbeat++);
    }
  }
}

void main() {
  test(
    'selected preparation SQL exception rolls back materialization instead of publishing later appointment or Empty',
    () async {
      final fault = _SelectedPreparationFailure();
      final db = AppDatabase.forTesting(
        NativeDatabase.memory().interceptWith(fault),
      );
      addTearDown(db.close);
      final now = DateTime.utc(2030, 1, 1, 12);
      await db.userDao.putUser(
        const UserEntity(
          id: 'local-profile',
          spareTime: Duration.zero,
          note: '',
        ),
      );
      final recurring = RecurringScheduleRepositoryImpl(db, now: () => now);
      final first = now.add(const Duration(days: 1));
      await recurring.create(
        _schedule('series', first),
        _prep,
        RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          start: first,
          timeZoneId: 'UTC',
          count: 2,
        ),
      );
      await db.delete(db.schedules).go();
      await db.scheduleDao.createSchedule(
        _schedule(
          'later',
          now.add(const Duration(days: 20)),
        ).toScheduleWithPlaceRow(),
      );
      final before = (await db.select(db.users).getSingle()).dataRevision;
      final repository = NearestScheduleQueryRepositoryImpl(
        db,
        recurring,
        now: () => now,
      );
      final session = await repository.open(_key());
      fault.armed = true;
      final result = await _finish(session);
      expect(
        fault.injected,
        1,
        reason:
            'The real selected preparation query must reach the injected SQL boundary.',
      );
      expect(
        result,
        isA<NearestQueryError>().having(
          (v) => v.reason,
          'selected SQL read failure',
          NearestQueryFailureReason.preparationReadFailed,
        ),
      );
      expect(
        (await db.scheduleDao.getScheduleList()).map((r) => r.schedule.id),
        ['later'],
      );
      expect((await db.select(db.users).getSingle()).dataRevision, before);
      final retry =
          await _finish(await repository.open(_key())) as NearestQueryReady;
      expect(retry.value.resolution.instantUtc, first);
      expect(
        retry
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

  for (final workload in [(1, false), (8, false), (32, true)]) {
    final segments = workload.$1;
    final monthly = workload.$2;
    test(
      'three-year ${monthly ? "monthly day-31 skips" : "daily history"} with $segments segments automatically yields bounded chunks before a real ready result',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        var now = DateTime.utc(2027, 1, 1, 0);
        await db.userDao.putUser(
          const UserEntity(
            id: 'local-profile',
            spareTime: Duration.zero,
            note: '',
          ),
        );
        final recurring = RecurringScheduleRepositoryImpl(db, now: () => now);
        for (var index = 0; index < segments; index++) {
          final first = DateTime.utc(2027, 1, monthly ? 31 : 1, 12, index * 10);
          await recurring.create(
            _schedule('series-$index', first),
            _prep,
            RecurrenceRule(
              frequency: monthly
                  ? RecurrenceFrequency.monthly
                  : RecurrenceFrequency.daily,
              start: first,
              timeZoneId: 'UTC',
              count: 2000,
            ),
          );
        }
        await db.delete(db.schedules).go();
        now = DateTime.utc(2030, 1, 1, 11);
        final measured = _MeasuredRepository(
          NearestScheduleQueryRepositoryImpl(db, recurring, now: () => now),
        );
        final ready = Completer<NearestQueryReady>();
        final seen = <NearestScheduleQuery>[];
        final initialRss = ProcessInfo.currentRss;
        final watch = Stopwatch()..start();
        final sub =
            GetNearestUpcomingScheduleUseCase(measured, now: () => now)(
              key: _key(),
            ).listen((event) {
              seen.add(event);
              if (event is NearestQueryReady && !ready.isCompleted) {
                ready.complete(event);
              }
            }, onError: ready.completeError);
        try {
          final result = await ready.future.timeout(
            const Duration(seconds: 20),
          );
          final firstReadyMicros = watch.elapsedMicroseconds;
          expect(
            result.value.resolution.instantUtc,
            DateTime.utc(2030, 1, monthly ? 31 : 1, 12),
          );
          expect(
            seen.whereType<NearestQueryLimited>(),
            isEmpty,
            reason:
                'Ordinary chunks automatically progress without user Continue clicks.',
          );
          expect(
            seen.whereType<NearestQueryLoading>().any(
              (v) => v.progress.visitedCandidates >= 1024,
            ),
            isTrue,
          );
          expect(measured.chunkMicros.length, greaterThan(1));
          expect(
            measured.heartbeatAtEntry.skip(1).any((v) => v > 0),
            isTrue,
            reason:
                'An event-loop task must run between automatic real query chunks.',
          );
          expect(
            await db.scheduleDao.getScheduleList(),
            hasLength(1),
            reason: 'Only the global winner is materialized.',
          );
          // Host characterization only. No arbitrary timing threshold or native
          // frame-rate guarantee is inferred from these measurements.
          // ignore: avoid_print
          print(
            'C08_QUERY_CHARACTERIZATION ${jsonEncode({'segments': segments, 'historyYears': 3, 'monthlyDay31': monthly, 'chunkBudget': 1024, 'queryOpens': measured.opens, 'chunkMicroseconds': measured.chunkMicros, 'synchronousCallMicroseconds': measured.chunkSynchronousMicros, 'firstReadyMicroseconds': firstReadyMicros, 'eventLoopHeartbeats': measured.heartbeat, 'initialRssBytes': initialRss, 'finalRssBytes': ProcessInfo.currentRss})}',
          );
        } finally {
          await sub.cancel();
        }
      },
      timeout: monthly && segments == 32
          ? const Timeout(Duration(minutes: 2))
          : null,
    );
  }
}
