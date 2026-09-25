import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/services/navigation_service.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/data/repositories/nearest_schedule_query_repository_impl.dart';
import 'package:on_time_front/data/repositories/recurring_schedule_repository_impl.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/repositories/nearest_schedule_query_repository.dart';
import 'package:on_time_front/domain/use-cases/get_nearest_upcoming_schedule_use_case.dart';
import 'package:on_time_front/domain/use-cases/schedule_preparation_session_use_case.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';

class _ObservedRepository implements NearestScheduleQueryRepository {
  _ObservedRepository(this.delegate);
  final NearestScheduleQueryRepository delegate;
  int opens = 0;
  @override
  Stream<void> get changes => delegate.changes;
  @override
  Future<NearestScheduleQuerySession> open(NearestQueryKey key) {
    opens++;
    return delegate.open(key);
  }

  @override
  Future<ScheduleWithPreparationEntity?> readActive() => delegate.readActive();
}

// Hold no result and synthesize no query. This hook creates the exact queue
// ordering: a UI Cancel is enqueued immediately before an already completed
// production query reaches the Bloc listener. It fires only once.
class _CancelBeforeTerminal implements GetNearestUpcomingScheduleUseCase {
  _CancelBeforeTerminal(this.delegate, this.onTerminal);
  final GetNearestUpcomingScheduleUseCase delegate;
  final void Function(NearestQueryKey) onTerminal;
  bool intercepted = false;
  @override
  Future<ScheduleWithPreparationEntity?> readActive() => delegate.readActive();
  @override
  Stream<NearestScheduleQuery> call({required NearestQueryKey key}) =>
      delegate(key: key).map((result) {
        if (!intercepted &&
            (result is NearestQueryEmpty || result is NearestQueryReady)) {
          intercepted = true;
          onTerminal(result.key!);
        }
        return result;
      });
}

class _Session extends Fake implements SchedulePreparationSessionUseCase {}

ScheduleEntity _schedule(String id, DateTime instant) => ScheduleEntity(
  id: id,
  place: PlaceEntity(id: 'place-$id', placeName: 'Synthetic place'),
  scheduleName: id,
  scheduleTime: instant,
  timeZoneId: 'UTC',
  occurrenceOffsetSeconds: 0,
  moveTime: Duration.zero,
  isChanged: false,
  isStarted: false,
  scheduleSpareTime: Duration.zero,
  scheduleNote: '',
);
Future<void> _databaseTurns(AppDatabase db) async {
  for (var turn = 0; turn < 5; turn++) {
    await db.customSelect('SELECT 1').get();
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final changedWhilePaused in [false, true]) {
    test(
      'actual producer revalidates a terminal delivered beside Cancel with paused data change=$changedWhilePaused',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final now = DateTime.utc(2030, 1, 1, 12);
        await db.userDao.putUser(
          const UserEntity(
            id: 'local-profile',
            spareTime: Duration.zero,
            note: '',
          ),
        );
        if (changedWhilePaused) {
          await db.scheduleDao.createSchedule(
            _schedule(
              'old',
              now.add(const Duration(days: 3)),
            ).toScheduleWithPlaceRow(),
          );
        }
        final recurring = RecurringScheduleRepositoryImpl(db, now: () => now);
        final repository = _ObservedRepository(
          NearestScheduleQueryRepositoryImpl(db, recurring, now: () => now),
        );
        late ScheduleBloc bloc;
        final nearest = _CancelBeforeTerminal(
          GetNearestUpcomingScheduleUseCase(repository, now: () => now),
          (key) => bloc.add(ScheduleNearestQueryCancelRequested(key)),
        );
        bloc = ScheduleBloc.test(
          nearest,
          NavigationService(),
          _Session(),
          nowProvider: () => now,
        );
        final seen = <NearestScheduleQuery>[];
        final observed = bloc.stream.listen(
          (state) => seen.add(state.nearestQuery),
        );
        try {
          final cancelled = bloc.stream.firstWhere(
            (state) =>
                state.nearestQuery is NearestQueryLimited &&
                (state.nearestQuery as NearestQueryLimited).reason ==
                    NearestQueryLimitReason.cancelled,
          );
          bloc.add(const ScheduleSubscriptionRequested());
          final cancelledState = await cancelled.timeout(
            const Duration(seconds: 5),
          );
          await _databaseTurns(db);
          final pausedKey = cancelledState.nearestQuery.key!;
          final opensBeforeContinue = repository.opens;
          expect(nearest.intercepted, isTrue);
          expect(bloc.state.nearestQuery, isA<NearestQueryLimited>());
          if (changedWhilePaused) {
            await db.scheduleDao.createSchedule(
              _schedule(
                'new',
                now.add(const Duration(days: 1)),
              ).toScheduleWithPlaceRow(),
            );
            await _databaseTurns(db);
          }
          final settled = bloc.stream.firstWhere(
            (state) => changedWhilePaused
                ? state.nearestQuery is NearestQueryReady
                : state.nearestQuery is NearestQueryEmpty,
          );
          bloc.add(ScheduleNearestQueryContinueRequested(pausedKey));
          final result = (await settled.timeout(
            const Duration(seconds: 5),
          )).nearestQuery;
          if (changedWhilePaused) {
            expect((result as NearestQueryReady).value.schedule.id, 'new');
            expect(
              seen.whereType<NearestQueryReady>().where(
                (v) => v.value.schedule.id == 'old',
              ),
              isEmpty,
              reason:
                  'An old terminal DTO must not be replayed as fresh authority before current SQLite validation.',
            );
          } else {
            expect(result.key, pausedKey);
            expect(
              repository.opens,
              opensBeforeContinue,
              reason:
                  'An unchanged completed producer rechecks the same session; Continue must not reset its budget by opening again.',
            );
          }
        } finally {
          await observed.cancel();
          await bloc.close();
        }
      },
    );
  }
}
