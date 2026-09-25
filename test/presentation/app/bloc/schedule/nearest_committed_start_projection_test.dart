import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/database/restore_runtime_identity.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/core/services/navigation_service.dart';
import 'package:on_time_front/data/data_sources/early_start_session_local_data_source.dart';
import 'package:on_time_front/data/data_sources/preparation_with_time_local_data_source.dart';
import 'package:on_time_front/data/repositories/early_start_session_repository_impl.dart';
import 'package:on_time_front/data/repositories/nearest_schedule_query_repository_impl.dart';
import 'package:on_time_front/data/repositories/recurring_schedule_repository_impl.dart';
import 'package:on_time_front/data/repositories/schedule_repository_impl.dart';
import 'package:on_time_front/data/repositories/timed_preparation_repository_impl.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/repositories/nearest_schedule_query_repository.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';
import 'package:on_time_front/domain/use-cases/cancel_schedule_alarm_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_nearest_upcoming_schedule_use_case.dart';
import 'package:on_time_front/domain/use-cases/schedule_preparation_session_use_case.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';
import 'package:on_time_front/presentation/home/utils/home_schedule_card_selection.dart';
import '../../../../helpers/fake_clock.dart';
import '../../../../helpers/noop_alarm_reconciliation.dart';

class _Preparation extends Fake implements PreparationRepository {}

class _Cancel extends Fake implements CancelScheduleAlarmUseCase {}

// Native database work can yield through zero-duration timers as well as
// microtasks. Drain those timers without advancing the observed wall clock or
// the owned automatic-start boundary, and report which operation was pending.
Future<T> _settle<T>(
  FakeClock tester,
  Future<T> operation,
  String stage,
) async {
  var completed = false;
  T? value;
  Object? failure;
  StackTrace? failureStack;
  operation.then(
    (result) {
      value = result;
      completed = true;
    },
    onError: (Object error, StackTrace stack) {
      failure = error;
      failureStack = stack;
      completed = true;
    },
  );
  for (var turn = 0; !completed && turn < 100; turn++) {
    await tester.pump();
  }
  if (failure != null) {
    Error.throwWithStackTrace(failure!, failureStack!);
  }
  if (!completed) {
    fail('Connected start stage did not settle: $stage');
  }
  return value as T;
}

class _Navigation extends NavigationService {
  final routes = <String>[];
  @override
  void push(String routeName, {Object? extra}) => routes.add(routeName);
}

// Delays only the real DAO signal. Query contents, active reads and writes all
// still come from the actual SQLite adapter and production use cases.
class _DelayedWatch implements NearestScheduleQueryRepository {
  _DelayedWatch(this.delegate);
  final NearestScheduleQueryRepository delegate;
  final released = Completer<void>();
  @override
  Stream<void> get changes => delegate.changes.asyncMap((_) => released.future);
  @override
  Future<NearestScheduleQuerySession> open(NearestQueryKey key) =>
      delegate.open(key);
  @override
  Future<ScheduleWithPreparationEntity?> readActive() => delegate.readActive();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final lateness in [Duration.zero, const Duration(seconds: 2)]) {
    fakeClockTest(
      'actual committed start at lateness $lateness owns Home before delayed watch and retains its runtime anchor',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        var wall = DateTime.utc(2030, 1, 1, 12);
        var mono = Duration.zero;
        final target = wall.add(const Duration(seconds: 10));
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        ScheduleRepositoryImpl? schedulesToDispose;
        SchedulePreparationSessionUseCase? sessionToDispose;
        AlarmOperationCoordinator? operationsToDispose;
        _DelayedWatch? watchToRelease;
        ScheduleBloc? blocToClose;
        StreamSubscription<ScheduleState>? observationToCancel;
        try {
          await _settle(
            tester,
            db.userDao.putUser(
              const UserEntity(
                id: 'local-profile',
                spareTime: Duration.zero,
                note: '',
              ),
            ),
            'seed profile',
          );
          await _settle(
            tester,
            RestoreRuntimeIdentity.shared.load(db),
            'runtime identity',
          );
          final runtime = TimedPreparationRepositoryImpl(
            localDataSource: PreparationWithTimeLocalDataSourceImpl(),
          );
          final early = EarlyStartSessionRepositoryImpl(
            localDataSource: EarlyStartSessionLocalDataSourceImpl(),
          );
          final recurring = RecurringScheduleRepositoryImpl(
            db,
            now: () => wall,
          );
          final schedules = ScheduleRepositoryImpl(
            database: db,
            timedPreparationRepository: runtime,
            recurringScheduleRepository: recurring,
            now: () => wall,
          );
          schedulesToDispose = schedules;
          await _settle(
            tester,
            schedules.createSchedule(
              ScheduleEntity(
                id: 'appointment',
                place: const PlaceEntity(id: 'p', placeName: 'Office'),
                scheduleName: 'Appointment',
                scheduleTime: target.add(const Duration(minutes: 10)),
                timeZoneId: 'UTC',
                occurrenceOffsetSeconds: 0,
                moveTime: Duration.zero,
                isChanged: true,
                isStarted: false,
                scheduleSpareTime: Duration.zero,
                scheduleNote: '',
              ),
            ),
            'seed schedule',
          );
          await _settle(
            tester,
            db.preparationScheduleDao.createPreparationSchedule(
              const PreparationEntity(
                preparationStepList: [
                  PreparationStepEntity(
                    id: 'step',
                    preparationName: 'Pack',
                    preparationTime: Duration(minutes: 10),
                  ),
                ],
              ),
              'appointment',
            ),
            'seed preparation',
          );
          final beforeRevision = (await _settle(
            tester,
            db.select(db.users).getSingle(),
            'baseline revision',
          )).dataRevision;
          final operations = AlarmOperationCoordinator(
            LocalDataOperationGate.shared,
          );
          operationsToDispose = operations;
          final session = SchedulePreparationSessionUseCase(
            schedules,
            _Preparation(),
            runtime,
            early,
            _Cancel(),
            NoopAlarmReconciliation(),
            operations: operations,
          );
          sessionToDispose = session;
          final delayed = _DelayedWatch(
            NearestScheduleQueryRepositoryImpl(db, recurring, now: () => wall),
          );
          watchToRelease = delayed;
          final navigation = _Navigation();
          final bloc = ScheduleBloc.test(
            GetNearestUpcomingScheduleUseCase(delayed, now: () => wall),
            navigation,
            session,
            nowProvider: () => wall,
            monotonicNow: () => mono,
          );
          blocToClose = bloc;
          final ready = Completer<void>();
          final started = Completer<void>();
          final restored = Completer<void>();
          final observed = bloc.stream.listen((state) {
            if (state.status == ScheduleStatus.upcoming &&
                state.freshNearest != null &&
                !ready.isCompleted) {
              ready.complete();
            }
            if (state.hasOwnedPreparationSurface &&
                state.status == ScheduleStatus.started &&
                !started.isCompleted) {
              started.complete();
            }
            if (state.isResumedPreparation && !restored.isCompleted) {
              restored.complete();
            }
          });
          observationToCancel = observed;
          bloc.add(const ScheduleSubscriptionRequested());
          await _settle(tester, ready.future, 'initial ready');
          wall = target.add(lateness);
          mono = const Duration(seconds: 10) + lateness;
          await tester.pump(const Duration(seconds: 10));
          await _settle(tester, started.future, 'committed start');
          expect(delayed.released.isCompleted, isFalse);
          final actual = await _settle(
            tester,
            schedules.getScheduleById('appointment'),
            'read committed row',
          );
          expect(actual.startedAt!.toUtc(), wall);
          expect(
            bloc.state.schedule!.startedAt!.toUtc(),
            actual.startedAt!.toUtc(),
          );
          expect(bloc.state.schedule!.preparationFrozen, isTrue);
          expect(
            HomeScheduleCardSelection.at(bloc.state, wall).kind,
            HomeScheduleCardKind.active,
          );
          expect(navigation.routes, ['/scheduleStart']);
          await tester.pump();
          await _settle(
            tester,
            operations.run(operations.capture(), () async {}),
            'flush runtime writer',
          );
          final snapshot = await _settle(
            tester,
            runtime.getTimedPreparationSnapshot('appointment'),
            'read runtime snapshot',
          );
          expect(snapshot, isNotNull);
          expect(snapshot!.startedAt!.toUtc(), actual.startedAt!.toUtc());
          expect(bloc.state.schedule!.preparation.elapsedTime, Duration.zero);
          wall = wall.add(const Duration(seconds: 5));
          mono += const Duration(seconds: 5);
          delayed.released.complete();
          await _settle(tester, restored.future, 'active watch recovery');
          await tester.pump();
          expect(
            HomeScheduleCardSelection.at(bloc.state, wall).kind,
            HomeScheduleCardKind.active,
          );
          expect(
            bloc.state.schedule!.preparation.elapsedTime,
            const Duration(seconds: 5),
          );
          expect(bloc.state.schedule!.requiresStartConfirmation, isFalse);
          expect(
            (await _settle(
              tester,
              schedules.getScheduleById('appointment'),
              'read retained anchor',
            )).startedAt!.toUtc(),
            actual.startedAt!.toUtc(),
          );
          expect(
            (await _settle(
              tester,
              db.select(db.users).getSingle(),
              'final revision',
            )).dataRevision,
            beforeRevision + 1,
          );
          expect(navigation.routes, ['/scheduleStart']);
        } finally {
          final watch = watchToRelease;
          if (watch != null && !watch.released.isCompleted) {
            watch.released.complete();
          }
          try {
            final observation = observationToCancel;
            if (observation != null) {
              await _settle(tester, observation.cancel(), 'cancel observation');
            }
            final bloc = blocToClose;
            if (bloc != null) {
              await _settle(tester, bloc.close(), 'close bloc');
            }
          } finally {
            sessionToDispose?.dispose();
            operationsToDispose?.dispose();
            try {
              final schedules = schedulesToDispose;
              if (schedules != null) {
                await _settle(
                  tester,
                  schedules.dispose(),
                  'close schedule repository',
                );
              }
            } finally {
              await _settle(tester, db.close(), 'close database');
            }
          }
        }
      },
    );
  }
}
