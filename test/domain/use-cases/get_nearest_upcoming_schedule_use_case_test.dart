import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/domain/entities/nearest_schedule_query.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/repositories/nearest_schedule_query_repository.dart';
import 'package:on_time_front/domain/use-cases/get_nearest_upcoming_schedule_use_case.dart';

class QueryRepositoryFixture implements NearestScheduleQueryRepository {
  final source = StreamController<void>.broadcast();
  late Future<NearestScheduleQuerySession> Function(NearestQueryKey)
  openHandler;
  final keys = <NearestQueryKey>[];
  @override
  Stream<void> get changes => source.stream;
  @override
  Future<NearestScheduleQuerySession> open(NearestQueryKey key) {
    keys.add(key);
    return openHandler(key);
  }

  @override
  Future<ScheduleWithPreparationEntity?> readActive() async => null;
}

class QuerySessionFixture implements NearestScheduleQuerySession {
  QuerySessionFixture(this.handler);
  final Future<NearestScheduleQuery> Function(int) handler;
  bool cancelled = false;
  int calls = 0;
  @override
  Future<NearestScheduleQuery> advance({required int candidateBudget}) {
    calls++;
    return handler(candidateBudget);
  }

  @override
  void cancel() {
    cancelled = true;
  }
}

NearestQueryKey queryKey() => NearestQueryKey(
  generation: LocalDataOperationGate.shared.generation,
  epoch: 1,
  revision: 0,
);
NearestQueryEmpty emptyQuery(NearestQueryKey key) => NearestQueryEmpty(
  authority: NearestQueryAuthority(
    key: key,
    storeIncarnation: 'store',
    dataRevision: 0,
    ruleDataIdentity: 'rules',
    evaluatedAtUtc: DateTime.utc(2030),
    verifiedAtUtc: DateTime.utc(2030),
  ),
);

void main() {
  test(
    'resuming a caught open error opens a current zero-budget retry',
    () async {
      final repository = QueryRepositoryFixture();
      repository.openHandler = (key) async {
        if (repository.keys.length == 1) throw StateError('open failed');
        return QuerySessionFixture((_) async => emptyQuery(key));
      };
      final failed = Completer<void>();
      final recovered = Completer<void>();
      final subscription =
          GetNearestUpcomingScheduleUseCase(repository)(key: queryKey()).listen(
            (query) {
              if (query is NearestQueryError && !failed.isCompleted) {
                failed.complete();
              }
              if (query is NearestQueryEmpty && !recovered.isCompleted) {
                recovered.complete();
              }
            },
          );
      try {
        await failed.future;
        subscription.pause();
        await Future<void>.delayed(Duration.zero);
        subscription.resume();
        await recovered.future.timeout(const Duration(seconds: 2));
        expect(repository.keys, hasLength(2));
      } finally {
        await subscription.cancel();
        await repository.source.close();
      }
    },
  );

  test(
    'resume after a watch error retires a pending cursor before fresh read',
    () async {
      final repository = QueryRepositoryFixture();
      final entered = Completer<void>();
      final pending = Completer<NearestScheduleQuery>();
      repository.openHandler = (key) async => QuerySessionFixture((_) {
        if (repository.keys.length == 1) {
          entered.complete();
          return pending.future;
        }
        return Future.value(emptyQuery(key));
      });
      final failed = Completer<void>();
      final recovered = Completer<void>();
      final seen = <NearestScheduleQuery>[];
      final subscription =
          GetNearestUpcomingScheduleUseCase(repository)(key: queryKey()).listen(
            (query) {
              seen.add(query);
              if (query is NearestQueryError && !failed.isCompleted) {
                failed.complete();
              }
              if (query is NearestQueryEmpty && !recovered.isCompleted) {
                recovered.complete();
              }
            },
          );
      try {
        await entered.future;
        repository.source.addError(StateError('watch failed'));
        await failed.future;
        subscription.pause();
        await Future<void>.delayed(Duration.zero);
        subscription.resume();
        pending.complete(emptyQuery(repository.keys.first));
        await recovered.future.timeout(const Duration(seconds: 2));
        expect(repository.keys, hasLength(2));
        expect(
          seen.whereType<NearestQueryEmpty>().single.key,
          repository.keys.last,
        );
      } finally {
        await subscription.cancel();
        await repository.source.close();
      }
    },
  );

  test(
    'resuming a completed search revalidates its existing cursor and key',
    () async {
      final repository = QueryRepositoryFixture();
      late QuerySessionFixture session;
      repository.openHandler = (key) async =>
          session = QuerySessionFixture((_) async => emptyQuery(key));
      final seen = <NearestScheduleQuery>[];
      final first = Completer<void>();
      final revalidated = Completer<void>();
      final subscription =
          GetNearestUpcomingScheduleUseCase(repository)(key: queryKey()).listen(
            (query) {
              seen.add(query);
              if (query is NearestQueryEmpty) {
                if (!first.isCompleted) {
                  first.complete();
                } else if (!revalidated.isCompleted) {
                  revalidated.complete();
                }
              }
            },
          );
      try {
        await first.future;
        subscription.pause();
        await Future<void>.delayed(Duration.zero);
        expect(session.calls, 1);
        subscription.resume();
        await revalidated.future.timeout(const Duration(seconds: 2));
        expect(session.calls, 2);
        expect(repository.keys, hasLength(1));
        expect(session.cancelled, isFalse);
        expect(seen.whereType<NearestQueryEmpty>().map((query) => query.key), [
          repository.keys.single,
          repository.keys.single,
        ]);
      } finally {
        await subscription.cancel();
        await repository.source.close();
      }
    },
  );

  for (final phase in ['open', 'advance']) {
    for (final pauseBeforeFailure in [false, true]) {
      test(
        'known data change discards a thrown retired $phase error (paused=$pauseBeforeFailure)',
        () async {
          final repository = QueryRepositoryFixture();
          final pending = Completer<void>();
          final entered = Completer<void>();
          repository.openHandler = (key) async {
            final first = repository.keys.length == 1;
            if (first && phase == 'open') {
              entered.complete();
              await pending.future;
            }
            return QuerySessionFixture((_) async {
              if (first && phase == 'advance') {
                entered.complete();
                await pending.future;
              }
              return emptyQuery(key);
            });
          };
          final seen = <NearestScheduleQuery>[];
          final settled = Completer<void>();
          final subscription =
              GetNearestUpcomingScheduleUseCase(repository)(
                key: queryKey(),
              ).listen((query) {
                seen.add(query);
                if (query is NearestQueryEmpty && !settled.isCompleted) {
                  settled.complete();
                }
              });
          try {
            await entered.future;
            if (pauseBeforeFailure) {
              subscription.pause();
            }
            repository.source.add(null);
            await Future<void>.delayed(Duration.zero);
            pending.completeError(StateError('obsolete $phase read failed'));
            if (pauseBeforeFailure) {
              await Future<void>.delayed(Duration.zero);
              subscription.resume();
            }
            await settled.future.timeout(const Duration(seconds: 2));
            expect(seen.whereType<NearestQueryError>(), isEmpty);
            expect(repository.keys, hasLength(2));
            expect(
              seen.whereType<NearestQueryEmpty>().single.key,
              repository.keys.last,
            );
          } finally {
            await subscription.cancel();
            await repository.source.close();
          }
        },
      );
    }
  }

  test(
    'a repository failure emits typed recoverable error, never empty',
    () async {
      final repository = QueryRepositoryFixture()
        ..openHandler = (_) async => throw StateError('read failed');
      final useCase = GetNearestUpcomingScheduleUseCase(repository);
      final seen = await useCase(key: queryKey()).take(2).toList();
      expect(seen.first, isA<NearestQueryLoading>());
      expect(
        seen.last,
        isA<NearestQueryError>().having(
          (v) => v.reason,
          'reason',
          NearestQueryFailureReason.storeReadFailed,
        ),
      );
      expect(seen.whereType<NearestQueryEmpty>(), isEmpty);
      await repository.source.close();
    },
  );

  test(
    'bounded chunks auto-progress, yield, and stop at terminal budget',
    () async {
      final repository = QueryRepositoryFixture();
      late QuerySessionFixture session;
      repository.openHandler = (key) async =>
          session = QuerySessionFixture((budget) async {
            expect(budget, 2);
            final terminal = session.calls == 3;
            return NearestQueryLimited(
              key: key,
              reason: terminal
                  ? NearestQueryLimitReason.searchBudgetExhausted
                  : NearestQueryLimitReason.interrupted,
              progress: NearestQueryProgress(
                visitedCandidates: session.calls * 2,
                candidateBudget: 6,
                provenSegments: 0,
                totalSegments: 1,
              ),
              canContinue: !terminal,
              canRetry: false,
            );
          });
      final seen = await GetNearestUpcomingScheduleUseCase(
        repository,
        chunkSize: 2,
      )(key: queryKey()).take(4).toList();
      expect(seen.whereType<NearestQueryLoading>(), hasLength(3));
      expect(
        seen.last,
        isA<NearestQueryLimited>().having(
          (v) => v.canRetry,
          'no budget reset',
          false,
        ),
      );
      expect(session.calls, 3);
      expect(session.cancelled, isTrue);
      await repository.source.close();
    },
  );

  test('cancelled subscription drops an old open receipt', () async {
    final repository = QueryRepositoryFixture();
    final pending = Completer<NearestScheduleQuerySession>();
    repository.openHandler = (_) => pending.future;
    final seen = <NearestScheduleQuery>[];
    final subscription = GetNearestUpcomingScheduleUseCase(repository)(
      key: queryKey(),
    ).listen(seen.add);
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();
    final session = QuerySessionFixture((_) async => emptyQuery(queryKey()));
    pending.complete(session);
    await Future<void>.delayed(Duration.zero);
    expect(seen, hasLength(1));
    expect(session.calls, 0);
    expect(session.cancelled, isTrue);
    await repository.source.close();
  });
  for (final failOld in [false, true]) {
    test(
      'known data change rejects retired ${failOld ? "error" : "value"} before publish',
      () async {
        final repository = QueryRepositoryFixture();
        final pending = Completer<NearestScheduleQuery>();
        final entered = Completer<void>();
        repository.openHandler = (key) async => QuerySessionFixture((_) {
          if (repository.keys.length == 1) {
            if (!entered.isCompleted) entered.complete();
            return pending.future;
          }
          return Future.value(emptyQuery(key));
        });
        final seen = <NearestScheduleQuery>[];
        final ready = Completer<void>();
        final subscription =
            GetNearestUpcomingScheduleUseCase(repository)(
              key: queryKey(),
            ).listen((v) {
              seen.add(v);
              if (v is NearestQueryEmpty && !ready.isCompleted) {
                ready.complete();
              }
            });
        await entered.future;
        repository.source.add(null);
        await Future<void>.delayed(Duration.zero);
        if (failOld) {
          pending.complete(
            NearestQueryError(
              key: repository.keys.first,
              reason: NearestQueryFailureReason.preparationReadFailed,
            ),
          );
        } else {
          pending.complete(emptyQuery(repository.keys.first));
        }
        await ready.future.timeout(const Duration(seconds: 2));
        expect(seen.whereType<NearestQueryError>(), isEmpty);
        expect(
          seen.whereType<NearestQueryEmpty>().single.key,
          repository.keys.last,
        );
        expect(repository.keys, hasLength(2));
        await subscription.cancel();
        await repository.source.close();
      },
    );
  }
}
