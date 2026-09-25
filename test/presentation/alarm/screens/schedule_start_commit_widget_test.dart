import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/data/repositories/schedule_repository_impl.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/entities/early_start_session_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_with_time_entity.dart';
import 'package:on_time_front/domain/entities/timed_preparation_snapshot_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/repositories/early_start_session_repository.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';
import 'package:on_time_front/domain/repositories/timed_preparation_repository.dart';
import 'package:on_time_front/domain/use-cases/cancel_schedule_alarm_use_case.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';
import 'package:on_time_front/domain/use-cases/schedule_preparation_session_use_case.dart';
import 'package:on_time_front/presentation/alarm/screens/schedule_start_screen.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';
import 'preparation_flow_widget_test.dart'
    show
        buildSchedule,
        pumpWithRouter,
        StubGetNearestUpcomingScheduleUseCase,
        SpyNavigationService;

void main() {
  for (final leave in [false, true]) {
    testWidgets(
      'real button awaits durable commit; failure retries and stale route=$leave never navigates',
      (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        final db = (await tester.runAsync(
          () async => AppDatabase.forTesting(NativeDatabase.memory()),
        ))!;
        final snapshots = _Snapshots();
        final repository = (await tester.runAsync(
          () async => ScheduleRepositoryImpl(
            database: db,
            timedPreparationRepository: snapshots,
          ),
        ))!;
        final owner = AlarmOperationCoordinator(LocalDataOperationGate());
        final cancel = _Cancel();
        final session = _ObservedSession(repository, snapshots, cancel, owner);
        addTearDown(session.dispose);
        final now = DateTime.utc(2026, 10, 1);
        final schedule = buildSchedule(
          id: 'button',
          scheduleTime: now.add(const Duration(hours: 2)),
          steps: const [
            PreparationStepWithTimeEntity(
              id: 'one',
              preparationName: 'one',
              preparationTime: Duration(minutes: 10),
              nextPreparationId: 'two',
            ),
            PreparationStepWithTimeEntity(
              id: 'two',
              preparationName: 'two',
              preparationTime: Duration(minutes: 10),
              nextPreparationId: null,
            ),
          ],
        );
        await tester.runAsync(() async {
          await db.userDao.putUser(
            const UserEntity(
              id: 'local-profile',
              spareTime: Duration.zero,
              note: '',
              isOnboardingCompleted: true,
            ),
          );
          await repository.createSchedule(schedule);
          await db.customStatement(
            "CREATE TRIGGER reject_start BEFORE UPDATE OF is_started ON schedules BEGIN SELECT RAISE(ABORT, 'disk write failed'); END",
          );
        });
        final bloc = ScheduleBloc.test(
          StubGetNearestUpcomingScheduleUseCase(() => const Stream.empty()),
          SpyNavigationService(),
          session,
          nowProvider: () => now,
        );
        final promptOwner = Object();
        bloc.presentNotificationPrompt(schedule, promptOwner, () => true);
        var consumed = 0;
        final router = GoRouter(
          initialLocation: '/start',
          routes: [
            GoRoute(
              path: '/start',
              builder: (_, __) => ScheduleStartScreen(
                requiresExplicitStart: true,
                onExplicitStart: () {
                  consumed++;
                  bloc.confirmNotificationPrompt(promptOwner);
                },
              ),
            ),
            GoRoute(
              path: '/alarmScreen',
              builder: (_, __) => const Scaffold(body: Text('COMMITTED')),
            ),
            GoRoute(
              path: '/home',
              builder: (_, __) => const Scaffold(body: Text('HOME')),
            ),
          ],
        );
        addTearDown(() async {
          if (cancel.barrier != null && !cancel.barrier!.isCompleted) {
            cancel.barrier!.complete();
          }
          await bloc.close();
          router.dispose();
          await repository.dispose();
          await db.close();
          owner.dispose();
        });
        await pumpWithRouter(tester, bloc: bloc, router: router);
        await tester.tap(find.text('Start Preparing'));
        await tester.pump();
        await tester.runAsync(
          () => session.completed.future.timeout(const Duration(seconds: 5)),
        );
        await tester.pump();
        expect(
          find.byKey(const Key('preparation-start-error')),
          findsOneWidget,
        );
        expect(find.text('COMMITTED'), findsNothing);
        expect(consumed, 0);
        expect(bloc.ownsNotificationPrompt(promptOwner), isTrue);
        await tester.runAsync(() async {
          expect(
            (await repository.getScheduleById(schedule.id)).isStarted,
            isFalse,
          );
          await db.customStatement('DROP TRIGGER reject_start');
        });
        cancel.barrier = Completer<void>();
        await tester.tap(find.text('Start Preparing'));
        await tester.pump();
        await tester.runAsync(
          () => cancel.entered.future.timeout(const Duration(seconds: 5)),
        );
        await tester.pump();
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
          isNull,
        );
        expect(consumed, 0);
        if (leave) {
          router.go('/home');
          await tester.pumpAndSettle();
        }
        cancel.barrier!.complete();
        await tester.runAsync(
          () => session.completed.future.timeout(const Duration(seconds: 5)),
        );
        await tester.pumpAndSettle();
        expect(find.text(leave ? 'HOME' : 'COMMITTED'), findsOneWidget);
        expect(consumed, leave ? 0 : 1);
        await tester.runAsync(() async {
          final row = await repository.getScheduleById(schedule.id);
          expect(row.isStarted, isTrue);
          expect(row.preparationFrozen, isTrue);
          expect(row.startedAt!.toUtc(), now);
        });
        await tester.runAsync(() => bloc.close());
      },
    );
  }
}

class _Preparation implements PreparationRepository {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Snapshots implements TimedPreparationRepository {
  final snapshots = <String, TimedPreparationSnapshotEntity>{};
  @override
  Future<void> clearTimedPreparation(String id) async {
    snapshots.remove(id);
  }

  @override
  Future<TimedPreparationSnapshotEntity?> getTimedPreparationSnapshot(
    String id,
  ) async => snapshots[id];
  @override
  Future<void> saveTimedPreparationSnapshot(
    String id,
    TimedPreparationSnapshotEntity value,
  ) async {
    snapshots[id] = value;
  }
}

class _Early implements EarlyStartSessionRepository {
  final sessions = <String, EarlyStartSessionEntity>{};
  @override
  Future<void> clear(String id) async {
    sessions.remove(id);
  }

  @override
  Future<EarlyStartSessionEntity?> getSession(String id) async => sessions[id];
  @override
  Future<void> markStarted({
    required String scheduleId,
    required DateTime startedAt,
  }) async {
    sessions[scheduleId] = EarlyStartSessionEntity(
      scheduleId: scheduleId,
      startedAt: startedAt,
    );
  }
}

class _Cancel implements CancelScheduleAlarmUseCase {
  Completer<void>? barrier;
  final entered = Completer<void>();
  @override
  Future<void> call(String id) async {
    if (!entered.isCompleted) entered.complete();
    await barrier?.future;
  }
}

class _Reconcile implements ReconcileAlarmsUseCase {
  @override
  Future<AlarmReconciliationResult> call() async => AlarmReconciliationResult(
    status: AlarmReconciliationStatus.armed,
    nativeAlarmProvider: AlarmProvider.none,
    fallbackProvider: AlarmProvider.localNotification,
    armedScheduleIds: [],
    skippedScheduleCount: 0,
    failures: [],
    scheduleWindowStart: DateTime.utc(2026),
    scheduleWindowEnd: DateTime.utc(2026),
    alarmCoverageStart: DateTime.utc(2026),
    alarmCoverageEnd: DateTime.utc(2026),
  );
}

class _ObservedSession extends SchedulePreparationSessionUseCase {
  _ObservedSession(
    ScheduleRepositoryImpl repository,
    _Snapshots snapshots,
    _Cancel cancel,
    AlarmOperationCoordinator owner,
  ) : super(
        repository,
        _Preparation(),
        snapshots,
        _Early(),
        cancel,
        _Reconcile(),
        operations: owner,
      );
  Completer<void> completed = Completer<void>();
  @override
  Future<PreparationStartReceipt> startEarlySession(
    schedule, {
    required DateTime startedAt,
    bool Function()? isCurrent,
  }) async {
    completed = Completer<void>();
    try {
      return await super.startEarlySession(
        schedule,
        startedAt: startedAt,
        isCurrent: isCurrent,
      );
    } finally {
      completed.complete();
    }
  }
}
