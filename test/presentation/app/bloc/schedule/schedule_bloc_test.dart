import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/services/navigation_service.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_with_time_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/entities/timed_preparation_snapshot_entity.dart';
import 'package:on_time_front/domain/entities/early_start_session_entity.dart';
import 'package:on_time_front/domain/use-cases/cancel_schedule_alarm_use_case.dart';
import 'package:on_time_front/domain/use-cases/clear_early_start_session_use_case.dart';
import 'package:on_time_front/domain/use-cases/clear_timed_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/finish_schedule_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_nearest_upcoming_schedule_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_early_start_session_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_schedule_by_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_timed_preparation_snapshot_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/mark_early_start_session_use_case.dart';
import 'package:on_time_front/domain/use-cases/save_timed_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/start_schedule_use_case.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';

class StubGetNearestUpcomingScheduleUseCase
    implements GetNearestUpcomingScheduleUseCase {
  StubGetNearestUpcomingScheduleUseCase(this.streamFactory);

  final Stream<ScheduleWithPreparationEntity?> Function() streamFactory;

  @override
  Stream<ScheduleWithPreparationEntity?> call() => streamFactory();
}

class SpyNavigationService extends NavigationService {
  final List<String> pushedRoutes = [];
  final List<String> goRoutes = [];

  @override
  void push(String routeName, {Object? extra}) {
    pushedRoutes.add(routeName);
  }

  @override
  void go(String routeName, {Object? extra}) {
    goRoutes.add(routeName);
  }
}

class SpySaveTimedPreparationUseCase implements SaveTimedPreparationUseCase {
  final List<(String, PreparationWithTimeEntity, DateTime?)> calls = [];

  @override
  Future<void> call(
    ScheduleWithPreparationEntity schedule,
    PreparationWithTimeEntity preparation, {
    DateTime? savedAt,
  }) async {
    calls.add((schedule.id, preparation, savedAt));
  }
}

class SpyFinishScheduleUseCase implements FinishScheduleUseCase {
  final List<(String, int)> calls = [];
  bool throwOnCall = false;

  @override
  Future<void> call(String scheduleId, int latenessTime) async {
    calls.add((scheduleId, latenessTime));
    if (throwOnCall) {
      throw Exception('finish failed');
    }
  }
}

class SpyStartScheduleUseCase implements StartScheduleUseCase {
  final List<String> calls = [];

  @override
  Future<void> call(String scheduleId) async {
    calls.add(scheduleId);
  }
}

class SpyCancelScheduleAlarmUseCase implements CancelScheduleAlarmUseCase {
  final List<String> calls = [];

  @override
  Future<void> call(String scheduleId) async {
    calls.add(scheduleId);
  }
}

class StubGetScheduleByIdUseCase implements GetScheduleByIdUseCase {
  final Map<String, ScheduleEntity> schedules = {};
  final Set<String> throwingIds = {};

  @override
  Future<ScheduleEntity> call(String id) async {
    if (throwingIds.contains(id)) {
      throw Exception('schedule unavailable');
    }
    return schedules[id]!;
  }
}

class SpyLoadPreparationByScheduleIdUseCase
    implements LoadPreparationByScheduleIdUseCase {
  final List<String> calls = [];

  @override
  Future<void> call(String scheduleId) async {
    calls.add(scheduleId);
  }
}

class StubGetPreparationByScheduleIdUseCase
    implements GetPreparationByScheduleIdUseCase {
  final Map<String, PreparationEntity> preparations = {};

  @override
  Future<PreparationEntity> call(String scheduleId) async {
    return preparations[scheduleId]!;
  }
}

class StubGetTimedPreparationSnapshotUseCase
    implements GetTimedPreparationSnapshotUseCase {
  final Map<String, TimedPreparationSnapshotEntity> snapshots = {};

  @override
  Future<TimedPreparationSnapshotEntity?> call(String scheduleId) async {
    return snapshots[scheduleId];
  }
}

class SpyClearTimedPreparationUseCase implements ClearTimedPreparationUseCase {
  final List<String> calls = [];

  @override
  Future<void> call(String scheduleId) async {
    calls.add(scheduleId);
  }
}

class SpyMarkEarlyStartSessionUseCase implements MarkEarlyStartSessionUseCase {
  final Map<String, DateTime> sessions = {};

  @override
  Future<void> call({
    required String scheduleId,
    required DateTime startedAt,
  }) async {
    sessions[scheduleId] = startedAt;
  }
}

class StubGetEarlyStartSessionUseCase implements GetEarlyStartSessionUseCase {
  StubGetEarlyStartSessionUseCase(this.marker);

  final SpyMarkEarlyStartSessionUseCase marker;

  @override
  Future<EarlyStartSessionEntity?> call(String scheduleId) async {
    final startedAt = marker.sessions[scheduleId];
    if (startedAt == null) return null;
    return EarlyStartSessionEntity(
      scheduleId: scheduleId,
      startedAt: startedAt,
    );
  }
}

class SpyClearEarlyStartSessionUseCase
    implements ClearEarlyStartSessionUseCase {
  SpyClearEarlyStartSessionUseCase(this.marker);

  final SpyMarkEarlyStartSessionUseCase marker;
  final List<String> calls = [];

  @override
  Future<void> call(String scheduleId) async {
    calls.add(scheduleId);
    marker.sessions.remove(scheduleId);
  }
}

ScheduleWithPreparationEntity buildSchedule({
  required String id,
  required DateTime scheduleTime,
  required List<PreparationStepWithTimeEntity> steps,
  Duration moveTime = const Duration(minutes: 20),
  Duration scheduleSpareTime = const Duration(minutes: 10),
}) {
  return ScheduleWithPreparationEntity(
    id: id,
    place: PlaceEntity(id: 'p1', placeName: 'Office'),
    scheduleName: 'Meeting',
    scheduleTime: scheduleTime,
    moveTime: moveTime,
    isChanged: false,
    isStarted: false,
    scheduleSpareTime: scheduleSpareTime,
    scheduleNote: '',
    preparation: PreparationWithTimeEntity(preparationStepList: steps),
  );
}

TimedPreparationSnapshotEntity buildSnapshot({
  required PreparationWithTimeEntity preparation,
  required DateTime savedAt,
  required String fingerprint,
}) {
  return TimedPreparationSnapshotEntity(
    preparation: preparation,
    savedAt: savedAt,
    scheduleFingerprint: fingerprint,
  );
}

void main() {
  group('ScheduleBloc preparation runtime flow', () {
    late StreamController<ScheduleWithPreparationEntity?> controller;
    late SpyNavigationService navigationService;
    late SpySaveTimedPreparationUseCase saveUseCase;
    late SpyStartScheduleUseCase startUseCase;
    late SpyFinishScheduleUseCase finishUseCase;
    late StubGetTimedPreparationSnapshotUseCase getSnapshotUseCase;
    late SpyClearTimedPreparationUseCase clearTimedUseCase;
    late SpyMarkEarlyStartSessionUseCase markEarlySessionUseCase;
    late StubGetEarlyStartSessionUseCase getEarlySessionUseCase;
    late SpyClearEarlyStartSessionUseCase clearEarlySessionUseCase;
    late SpyCancelScheduleAlarmUseCase cancelScheduleAlarmUseCase;
    late StubGetScheduleByIdUseCase getScheduleByIdUseCase;
    late SpyLoadPreparationByScheduleIdUseCase
    loadPreparationByScheduleIdUseCase;
    late StubGetPreparationByScheduleIdUseCase
    getPreparationByScheduleIdUseCase;
    late DateTime now;
    late List<String> notifiedStepIds;

    late ScheduleBloc bloc;

    setUp(() {
      controller = StreamController<ScheduleWithPreparationEntity?>.broadcast();
      navigationService = SpyNavigationService();
      saveUseCase = SpySaveTimedPreparationUseCase();
      startUseCase = SpyStartScheduleUseCase();
      finishUseCase = SpyFinishScheduleUseCase();
      getSnapshotUseCase = StubGetTimedPreparationSnapshotUseCase();
      clearTimedUseCase = SpyClearTimedPreparationUseCase();
      markEarlySessionUseCase = SpyMarkEarlyStartSessionUseCase();
      getEarlySessionUseCase = StubGetEarlyStartSessionUseCase(
        markEarlySessionUseCase,
      );
      clearEarlySessionUseCase = SpyClearEarlyStartSessionUseCase(
        markEarlySessionUseCase,
      );
      cancelScheduleAlarmUseCase = SpyCancelScheduleAlarmUseCase();
      getScheduleByIdUseCase = StubGetScheduleByIdUseCase();
      loadPreparationByScheduleIdUseCase =
          SpyLoadPreparationByScheduleIdUseCase();
      getPreparationByScheduleIdUseCase =
          StubGetPreparationByScheduleIdUseCase();
      now = DateTime(2026, 3, 20, 9, 0, 0);
      notifiedStepIds = [];
      bloc = ScheduleBloc.test(
        StubGetNearestUpcomingScheduleUseCase(() => controller.stream),
        navigationService,
        saveUseCase,
        getSnapshotUseCase,
        clearTimedUseCase,
        startUseCase,
        finishUseCase,
        markEarlyStartSessionUseCase: markEarlySessionUseCase,
        getEarlyStartSessionUseCase: getEarlySessionUseCase,
        clearEarlyStartSessionUseCase: clearEarlySessionUseCase,
        cancelScheduleAlarmUseCase: cancelScheduleAlarmUseCase,
        getScheduleByIdUseCase: getScheduleByIdUseCase,
        loadPreparationByScheduleIdUseCase: loadPreparationByScheduleIdUseCase,
        getPreparationByScheduleIdUseCase: getPreparationByScheduleIdUseCase,
        nowProvider: () => now,
        notifyPreparationStep:
            ({
              required scheduleName,
              required preparationName,
              required scheduleId,
              required stepId,
            }) {
              notifiedStepIds.add(stepId);
            },
      );
    });

    tearDown(() async {
      await bloc.close();
      await controller.close();
    });

    test('emits notExists when there is no upcoming schedule', () async {
      bloc.add(const ScheduleUpcomingReceived(null));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.status, ScheduleStatus.notExists);
    });

    test(
      'alarm prompt is ignored when validation use cases are unavailable',
      () async {
        final minimalBloc = ScheduleBloc.test(
          StubGetNearestUpcomingScheduleUseCase(() => const Stream.empty()),
          navigationService,
          saveUseCase,
          getSnapshotUseCase,
          clearTimedUseCase,
          startUseCase,
          finishUseCase,
          markEarlyStartSessionUseCase: markEarlySessionUseCase,
          getEarlyStartSessionUseCase: getEarlySessionUseCase,
          clearEarlyStartSessionUseCase: clearEarlySessionUseCase,
          nowProvider: () => now,
        );
        addTearDown(minimalBloc.close);

        minimalBloc.add(
          const ScheduleAlarmPromptRequested(scheduleId: 'missing-validation'),
        );
        await Future<void>.delayed(Duration.zero);

        expect(minimalBloc.state.status, ScheduleStatus.initial);
        expect(navigationService.goRoutes, isEmpty);
      },
    );

    test(
      'default constructor registers handlers with injected dependencies',
      () async {
        final constructedBloc = ScheduleBloc(
          StubGetNearestUpcomingScheduleUseCase(() => const Stream.empty()),
          navigationService,
          saveUseCase,
          getSnapshotUseCase,
          clearTimedUseCase,
          startUseCase,
          finishUseCase,
          markEarlyStartSessionUseCase: markEarlySessionUseCase,
          getEarlyStartSessionUseCase: getEarlySessionUseCase,
          clearEarlyStartSessionUseCase: clearEarlySessionUseCase,
          cancelScheduleAlarmUseCase: cancelScheduleAlarmUseCase,
          getScheduleByIdUseCase: getScheduleByIdUseCase,
          loadPreparationByScheduleIdUseCase:
              loadPreparationByScheduleIdUseCase,
          getPreparationByScheduleIdUseCase: getPreparationByScheduleIdUseCase,
        );
        addTearDown(constructedBloc.close);

        constructedBloc.add(const ScheduleSubscriptionRequested());
        await Future<void>.delayed(Duration.zero);

        expect(constructedBloc.state.status, ScheduleStatus.initial);
      },
    );

    test(
      'emits notExists when upcoming schedule time is already passed',
      () async {
        final schedule = buildSchedule(
          id: 'past',
          scheduleTime: now.subtract(const Duration(minutes: 1)),
          steps: const [
            PreparationStepWithTimeEntity(
              id: 'a',
              preparationName: 'a',
              preparationTime: Duration(minutes: 5),
              nextPreparationId: null,
            ),
          ],
        );

        bloc.add(ScheduleUpcomingReceived(schedule));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.status, ScheduleStatus.notExists);
      },
    );

    test('emits upcoming when now is before preparationStartTime', () async {
      final schedule = buildSchedule(
        id: 'upcoming',
        scheduleTime: now.add(const Duration(hours: 1)),
        steps: const [
          PreparationStepWithTimeEntity(
            id: 'a',
            preparationName: 'a',
            preparationTime: Duration(minutes: 10),
            nextPreparationId: null,
          ),
        ],
      );

      bloc.add(ScheduleUpcomingReceived(schedule));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.status, ScheduleStatus.upcoming);
      expect(bloc.state.schedule?.id, 'upcoming');
    });

    test('emits ongoing when now is inside preparation window', () async {
      final schedule = buildSchedule(
        id: 'ongoing',
        scheduleTime: now.add(const Duration(minutes: 30)),
        steps: const [
          PreparationStepWithTimeEntity(
            id: 'a',
            preparationName: 'a',
            preparationTime: Duration(minutes: 10),
            nextPreparationId: null,
          ),
        ],
      );

      bloc.add(ScheduleUpcomingReceived(schedule));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.status, ScheduleStatus.ongoing);
      expect(bloc.state.schedule?.id, 'ongoing');
    });

    test(
      'at preparation start boundary it transitions to started and navigates once',
      () async {
        final schedule = buildSchedule(
          id: 'boundary',
          scheduleTime: now.add(const Duration(milliseconds: 200)),
          steps: const [
            PreparationStepWithTimeEntity(
              id: 'a',
              preparationName: 'a',
              preparationTime: Duration(milliseconds: 100),
              nextPreparationId: null,
            ),
          ],
          moveTime: Duration.zero,
          scheduleSpareTime: Duration.zero,
        );
        bloc.add(ScheduleUpcomingReceived(schedule));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.status, ScheduleStatus.upcoming);

        final started = await bloc.stream.firstWhere(
          (s) => s.status == ScheduleStatus.started,
        );
        expect(started.status, ScheduleStatus.started);
        expect(navigationService.pushedRoutes, ['/scheduleStart']);
      },
    );

    test(
      'when received exactly at preparationStartTime it starts and navigates once',
      () async {
        final schedule = buildSchedule(
          id: 'exact-boundary',
          scheduleTime: now.add(const Duration(minutes: 40)),
          steps: const [
            PreparationStepWithTimeEntity(
              id: 'a',
              preparationName: 'a',
              preparationTime: Duration(minutes: 10),
              nextPreparationId: null,
            ),
          ],
        );
        expect(schedule.preparationStartTime, now);

        bloc.add(ScheduleUpcomingReceived(schedule));
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.status, ScheduleStatus.started);
        expect(bloc.state.schedule?.id, 'exact-boundary');
        expect(bloc.state.isEarlyStarted, isFalse);
        expect(navigationService.pushedRoutes, ['/scheduleStart']);
      },
    );

    test(
      'when early-started schedule is received at boundary it does not navigate again',
      () async {
        final schedule = buildSchedule(
          id: 'early-boundary',
          scheduleTime: now.add(const Duration(minutes: 40)),
          steps: const [
            PreparationStepWithTimeEntity(
              id: 'a',
              preparationName: 'a',
              preparationTime: Duration(minutes: 10),
              nextPreparationId: null,
            ),
          ],
        );
        expect(schedule.preparationStartTime, now);
        markEarlySessionUseCase.sessions['early-boundary'] = now.subtract(
          const Duration(minutes: 1),
        );

        bloc.add(ScheduleUpcomingReceived(schedule));
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.status, ScheduleStatus.started);
        expect(bloc.state.schedule?.id, 'early-boundary');
        expect(bloc.state.isEarlyStarted, isTrue);
        expect(navigationService.pushedRoutes, isEmpty);
      },
    );

    test(
      'late entry fast-forwards elapsed preparation to current step',
      () async {
        final schedule = buildSchedule(
          id: 'late-entry',
          scheduleTime: now.add(const Duration(minutes: 35)),
          steps: const [
            PreparationStepWithTimeEntity(
              id: 's1',
              preparationName: 'wash',
              preparationTime: Duration(minutes: 10),
              nextPreparationId: 's2',
            ),
            PreparationStepWithTimeEntity(
              id: 's2',
              preparationName: 'dress',
              preparationTime: Duration(minutes: 10),
              nextPreparationId: null,
            ),
          ],
        );

        now = schedule.preparationStartTime.add(const Duration(minutes: 15));
        bloc.add(ScheduleUpcomingReceived(schedule));

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.status, ScheduleStatus.ongoing);
        expect(bloc.state.schedule!.preparation.currentStep?.id, 's2');
        expect(
          bloc.state.schedule!.preparation.preparationStepList[1].elapsedTime,
          const Duration(minutes: 5),
        );
        expect(notifiedStepIds, isEmpty);
      },
    );

    test(
      'entering ongoing applies catch-up tick and accepts later ticks',
      () async {
        final schedule = buildSchedule(
          id: 'tick',
          scheduleTime: now.add(const Duration(minutes: 30)),
          steps: const [
            PreparationStepWithTimeEntity(
              id: 's1',
              preparationName: 'wash',
              preparationTime: Duration(minutes: 10),
              nextPreparationId: null,
            ),
          ],
        );

        now = schedule.preparationStartTime.add(const Duration(seconds: 2));
        bloc.add(ScheduleUpcomingReceived(schedule));
        await bloc.stream.firstWhere((s) => s.status == ScheduleStatus.ongoing);
        await Future<void>.delayed(Duration.zero);

        final caughtUpElapsed = bloc.state.schedule!.preparation.elapsedTime;
        expect(caughtUpElapsed, const Duration(seconds: 2));

        bloc.add(const ScheduleTick(Duration(seconds: 1)));
        await Future<void>.delayed(Duration.zero);
        expect(
          bloc.state.schedule!.preparation.elapsedTime,
          const Duration(seconds: 3),
        );
      },
    );

    test(
      'skip current step advances to next and persists timed preparation',
      () async {
        final schedule = buildSchedule(
          id: 'skip',
          scheduleTime: now.add(const Duration(minutes: 35)),
          steps: const [
            PreparationStepWithTimeEntity(
              id: 's1',
              preparationName: 'wash',
              preparationTime: Duration(minutes: 10),
              nextPreparationId: 's2',
            ),
            PreparationStepWithTimeEntity(
              id: 's2',
              preparationName: 'dress',
              preparationTime: Duration(minutes: 10),
              nextPreparationId: null,
            ),
          ],
        );
        now = schedule.preparationStartTime.add(const Duration(minutes: 1));
        bloc.add(ScheduleUpcomingReceived(schedule));
        await bloc.stream.firstWhere((s) => s.status == ScheduleStatus.ongoing);

        bloc.add(const ScheduleStepSkipped());
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.schedule!.preparation.currentStep?.id, 's2');
        expect(saveUseCase.calls, isNotEmpty);
        expect(saveUseCase.calls.last.$1, 'skip');
      },
    );

    test('skip on last remaining step marks all steps done', () async {
      final schedule = buildSchedule(
        id: 'skip-last',
        scheduleTime: now.add(const Duration(minutes: 35)),
        steps: const [
          PreparationStepWithTimeEntity(
            id: 's1',
            preparationName: 'wash',
            preparationTime: Duration(minutes: 10),
            nextPreparationId: null,
          ),
        ],
      );
      now = schedule.preparationStartTime.add(const Duration(minutes: 1));
      bloc.add(ScheduleUpcomingReceived(schedule));
      await bloc.stream.firstWhere((s) => s.status == ScheduleStatus.ongoing);

      bloc.add(const ScheduleStepSkipped());
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.schedule!.preparation.isAllStepsDone, isTrue);
    });

    test('skip when already done is no-op and does not crash', () async {
      final schedule = buildSchedule(
        id: 'skip-noop',
        scheduleTime: now.add(const Duration(minutes: 35)),
        steps: const [
          PreparationStepWithTimeEntity(
            id: 's1',
            preparationName: 'wash',
            preparationTime: Duration(minutes: 10),
            nextPreparationId: null,
            isDone: true,
            elapsedTime: Duration(minutes: 10),
          ),
        ],
      );
      now = schedule.preparationStartTime.add(const Duration(minutes: 1));
      bloc.add(ScheduleUpcomingReceived(schedule));
      await bloc.stream.firstWhere((s) => s.status == ScheduleStatus.ongoing);

      final before = bloc.state.schedule!.preparation;
      bloc.add(const ScheduleStepSkipped());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.schedule!.preparation, before);
    });

    test('finish calls use case and emits notExists', () async {
      final schedule = buildSchedule(
        id: 'finish',
        scheduleTime: now.add(const Duration(minutes: 35)),
        steps: const [
          PreparationStepWithTimeEntity(
            id: 's1',
            preparationName: 'wash',
            preparationTime: Duration(minutes: 10),
            nextPreparationId: null,
          ),
        ],
      );
      now = schedule.preparationStartTime.add(const Duration(minutes: 1));
      bloc.add(ScheduleUpcomingReceived(schedule));
      await bloc.stream.firstWhere((s) => s.status == ScheduleStatus.ongoing);

      bloc.add(const ScheduleFinished(7));
      final finished = await bloc.stream.firstWhere(
        (s) => s.status == ScheduleStatus.notExists,
      );
      expect(finished.status, ScheduleStatus.notExists);
      expect(finishUseCase.calls.single, ('finish', 7));
    });

    test(
      'step change notification fires for non-first transitions only once',
      () async {
        final schedule = buildSchedule(
          id: 'notify',
          scheduleTime: now.add(const Duration(minutes: 50)),
          steps: const [
            PreparationStepWithTimeEntity(
              id: 's1',
              preparationName: 'step1',
              preparationTime: Duration(minutes: 10),
              nextPreparationId: 's2',
            ),
            PreparationStepWithTimeEntity(
              id: 's2',
              preparationName: 'step2',
              preparationTime: Duration(minutes: 10),
              nextPreparationId: null,
            ),
          ],
        );
        now = schedule.preparationStartTime.add(const Duration(minutes: 1));
        bloc.add(ScheduleUpcomingReceived(schedule));
        await bloc.stream.firstWhere((s) => s.status == ScheduleStatus.ongoing);

        expect(notifiedStepIds, isEmpty);
        bloc.add(const ScheduleTick(Duration(minutes: 10)));
        await Future<void>.delayed(Duration.zero);
        expect(notifiedStepIds, ['s2']);

        bloc.add(const ScheduleTick(Duration(minutes: 1)));
        await Future<void>.delayed(Duration.zero);
        expect(notifiedStepIds, ['s2']);
      },
    );

    test(
      'new upcoming schedule cancels old timer and tracks latest schedule',
      () async {
        final scheduleA = buildSchedule(
          id: 'A',
          scheduleTime: now.add(const Duration(milliseconds: 250)),
          steps: const [
            PreparationStepWithTimeEntity(
              id: 'a1',
              preparationName: 'a',
              preparationTime: Duration(milliseconds: 100),
              nextPreparationId: null,
            ),
          ],
          moveTime: Duration.zero,
          scheduleSpareTime: Duration.zero,
        );
        final scheduleB = buildSchedule(
          id: 'B',
          scheduleTime: now.add(const Duration(milliseconds: 500)),
          steps: const [
            PreparationStepWithTimeEntity(
              id: 'b1',
              preparationName: 'b',
              preparationTime: Duration(milliseconds: 100),
              nextPreparationId: null,
            ),
          ],
          moveTime: Duration.zero,
          scheduleSpareTime: Duration.zero,
        );

        bloc.add(ScheduleUpcomingReceived(scheduleA));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        bloc.add(ScheduleUpcomingReceived(scheduleB));
        await Future<void>.delayed(const Duration(milliseconds: 220));

        expect(bloc.state.schedule?.id, 'B');
        expect(bloc.state.status, ScheduleStatus.upcoming);

        final started = await bloc.stream.firstWhere(
          (s) => s.status == ScheduleStatus.started,
        );
        expect(started.schedule?.id, 'B');
        expect(navigationService.pushedRoutes, ['/scheduleStart']);
      },
    );

    test(
      'early start from upcoming emits started and marks early session',
      () async {
        final schedule = buildSchedule(
          id: 'early-start',
          scheduleTime: now.add(const Duration(hours: 1)),
          steps: const [
            PreparationStepWithTimeEntity(
              id: 'a',
              preparationName: 'a',
              preparationTime: Duration(minutes: 10),
              nextPreparationId: null,
            ),
          ],
        );

        bloc.add(ScheduleUpcomingReceived(schedule));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.status, ScheduleStatus.upcoming);

        bloc.add(const SchedulePreparationStarted());
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.status, ScheduleStatus.started);
        expect(bloc.state.isEarlyStarted, isTrue);
        expect(
          markEarlySessionUseCase.sessions.containsKey('early-start'),
          isTrue,
        );
      },
    );

    test(
      'alarm launch start action keeps cached schedule on start prompt',
      () async {
        final schedule = buildSchedule(
          id: 'alarm-start',
          scheduleTime: now.add(const Duration(hours: 1)),
          steps: const [
            PreparationStepWithTimeEntity(
              id: 'a',
              preparationName: 'a',
              preparationTime: Duration(minutes: 10),
              nextPreparationId: null,
            ),
          ],
        );

        bloc.add(ScheduleUpcomingReceived(schedule));
        await Future<void>.delayed(Duration.zero);

        bloc.add(
          ScheduleAlarmPromptRequested(
            scheduleId: 'alarm-start',
            scheduleFingerprint: schedule.cacheFingerprint,
            startPreparation: true,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.status, ScheduleStatus.upcoming);
        expect(bloc.state.schedule?.id, 'alarm-start');
        expect(bloc.state.isEarlyStarted, isFalse);
        expect(
          markEarlySessionUseCase.sessions.containsKey('alarm-start'),
          isFalse,
        );
        expect(navigationService.goRoutes, isEmpty);
      },
    );

    test(
      'alarm launch start action keeps stale-fingerprint cached schedule on start prompt',
      () async {
        final schedule = buildSchedule(
          id: 'alarm-stale-fingerprint',
          scheduleTime: now.add(const Duration(hours: 1)),
          steps: const [
            PreparationStepWithTimeEntity(
              id: 'a',
              preparationName: 'a',
              preparationTime: Duration(minutes: 10),
              nextPreparationId: null,
            ),
          ],
        );

        bloc.add(ScheduleUpcomingReceived(schedule));
        await Future<void>.delayed(Duration.zero);

        bloc.add(
          const ScheduleAlarmPromptRequested(
            scheduleId: 'alarm-stale-fingerprint',
            scheduleFingerprint: 'stale-fingerprint',
            startPreparation: true,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.status, ScheduleStatus.upcoming);
        expect(bloc.state.schedule?.id, 'alarm-stale-fingerprint');
        expect(bloc.state.isEarlyStarted, isFalse);
        expect(
          markEarlySessionUseCase.sessions.containsKey(
            'alarm-stale-fingerprint',
          ),
          isFalse,
        );
        expect(navigationService.goRoutes, isEmpty);
      },
    );

    test('future upcoming schedule stops active preparation timer', () async {
      final active = buildSchedule(
        id: 'active',
        scheduleTime: now.add(const Duration(hours: 1)),
        steps: const [
          PreparationStepWithTimeEntity(
            id: 'a',
            preparationName: 'a',
            preparationTime: Duration(minutes: 10),
            nextPreparationId: null,
          ),
        ],
      );
      final future = buildSchedule(
        id: 'future',
        scheduleTime: now.add(const Duration(hours: 2)),
        steps: const [
          PreparationStepWithTimeEntity(
            id: 'b',
            preparationName: 'b',
            preparationTime: Duration(minutes: 10),
            nextPreparationId: null,
          ),
        ],
      );

      bloc.add(ScheduleUpcomingReceived(active));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const SchedulePreparationStarted());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.status, ScheduleStatus.started);

      bloc.add(ScheduleUpcomingReceived(future));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.status, ScheduleStatus.upcoming);
      expect(bloc.state.schedule?.id, 'future');
      final elapsedBeforeWait = bloc.state.schedule!.preparation.elapsedTime;

      await Future<void>.delayed(const Duration(milliseconds: 1100));

      expect(bloc.state.status, ScheduleStatus.upcoming);
      expect(bloc.state.schedule?.id, 'future');
      expect(bloc.state.schedule!.preparation.elapsedTime, elapsedBeforeWait);
    });

    test(
      'official start timer does not push scheduleStart when already early-started',
      () async {
        final schedule = buildSchedule(
          id: 'early-no-push',
          scheduleTime: now.add(const Duration(milliseconds: 220)),
          steps: const [
            PreparationStepWithTimeEntity(
              id: 'a',
              preparationName: 'a',
              preparationTime: Duration(milliseconds: 100),
              nextPreparationId: null,
            ),
          ],
          moveTime: Duration.zero,
          scheduleSpareTime: Duration.zero,
        );

        bloc.add(ScheduleUpcomingReceived(schedule));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SchedulePreparationStarted());
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(const Duration(milliseconds: 300));

        expect(navigationService.pushedRoutes, isEmpty);
      },
    );

    test(
      'same schedule re-emission preserves started state when early-started',
      () async {
        final schedule = buildSchedule(
          id: 'same-reemit',
          scheduleTime: now.add(const Duration(hours: 1)),
          steps: const [
            PreparationStepWithTimeEntity(
              id: 'a',
              preparationName: 'a',
              preparationTime: Duration(minutes: 10),
              nextPreparationId: null,
            ),
          ],
        );

        bloc.add(ScheduleUpcomingReceived(schedule));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SchedulePreparationStarted());
        await Future<void>.delayed(Duration.zero);

        bloc.add(ScheduleUpcomingReceived(schedule));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.status, ScheduleStatus.started);
        expect(bloc.state.isEarlyStarted, isTrue);
      },
    );

    test('finish clears timed preparation and early session state', () async {
      final schedule = buildSchedule(
        id: 'finish-clear',
        scheduleTime: now.add(const Duration(hours: 1)),
        steps: const [
          PreparationStepWithTimeEntity(
            id: 'a',
            preparationName: 'a',
            preparationTime: Duration(minutes: 10),
            nextPreparationId: null,
          ),
        ],
      );

      bloc.add(ScheduleUpcomingReceived(schedule));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const SchedulePreparationStarted());
      await Future<void>.delayed(Duration.zero);

      bloc.add(const ScheduleFinished(0));
      await bloc.stream.firstWhere((s) => s.status == ScheduleStatus.notExists);

      expect(clearTimedUseCase.calls, contains('finish-clear'));
      expect(clearEarlySessionUseCase.calls, contains('finish-clear'));
    });

    test('mismatched fingerprint invalidates cached progress', () async {
      final schedule = buildSchedule(
        id: 'fingerprint',
        scheduleTime: now.add(const Duration(minutes: 30)),
        steps: const [
          PreparationStepWithTimeEntity(
            id: 'a',
            preparationName: 'a',
            preparationTime: Duration(minutes: 10),
            nextPreparationId: null,
          ),
        ],
      );
      getSnapshotUseCase.snapshots['fingerprint'] = buildSnapshot(
        preparation: const PreparationWithTimeEntity(
          preparationStepList: [
            PreparationStepWithTimeEntity(
              id: 'a',
              preparationName: 'a',
              preparationTime: Duration(minutes: 10),
              nextPreparationId: null,
              elapsedTime: Duration(minutes: 10),
              isDone: true,
            ),
          ],
        ),
        savedAt: now.subtract(const Duration(minutes: 1)),
        fingerprint: 'stale-fingerprint',
      );

      bloc.add(ScheduleUpcomingReceived(schedule));
      await Future<void>.delayed(Duration.zero);

      expect(clearTimedUseCase.calls, contains('fingerprint'));
      expect(
        bloc.state.schedule!.preparation.elapsedTime,
        const Duration(minutes: 10),
      );
    });

    test(
      'resume before official start when early session and snapshot exist',
      () async {
        final schedule = buildSchedule(
          id: 'resume-early',
          scheduleTime: now.add(const Duration(hours: 1)),
          steps: const [
            PreparationStepWithTimeEntity(
              id: 'a',
              preparationName: 'a',
              preparationTime: Duration(minutes: 20),
              nextPreparationId: null,
              elapsedTime: Duration(minutes: 2),
            ),
          ],
        );

        markEarlySessionUseCase.sessions['resume-early'] = now.subtract(
          const Duration(minutes: 3),
        );
        getSnapshotUseCase.snapshots['resume-early'] = buildSnapshot(
          preparation: schedule.preparation,
          savedAt: now.subtract(const Duration(minutes: 1)),
          fingerprint: schedule.cacheFingerprint,
        );

        bloc.add(ScheduleUpcomingReceived(schedule));
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.status, ScheduleStatus.started);
        expect(bloc.state.isEarlyStarted, isTrue);
        expect(
          bloc.state.schedule!.preparation.elapsedTime,
          greaterThan(const Duration(minutes: 2)),
        );
      },
    );

    test(
      'remote alarm prompt loads schedule details and arms the prompt',
      () async {
        final schedule = buildSchedule(
          id: 'remote-alarm',
          scheduleTime: now.add(const Duration(hours: 1)),
          steps: const [
            PreparationStepWithTimeEntity(
              id: 'stale-local',
              preparationName: 'stale',
              preparationTime: Duration(minutes: 1),
              nextPreparationId: null,
            ),
          ],
        );
        getScheduleByIdUseCase.schedules['remote-alarm'] = schedule;
        getPreparationByScheduleIdUseCase.preparations['remote-alarm'] =
            const PreparationEntity(
              preparationStepList: [
                PreparationStepEntity(
                  id: 'remote-step',
                  preparationName: 'remote prep',
                  preparationTime: Duration(minutes: 7),
                  nextPreparationId: null,
                ),
              ],
            );

        bloc.add(
          const ScheduleAlarmPromptRequested(scheduleId: 'remote-alarm'),
        );
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(loadPreparationByScheduleIdUseCase.calls, ['remote-alarm']);
        expect(bloc.state.status, ScheduleStatus.upcoming);
        expect(bloc.state.schedule?.id, 'remote-alarm');
        expect(
          bloc.state.schedule?.preparation.preparationStepList.single.id,
          'remote-step',
        );
        expect(cancelScheduleAlarmUseCase.calls, isEmpty);
        expect(navigationService.goRoutes, isEmpty);
      },
    );

    test(
      'remote alarm prompt rejects ended schedules and clears their alarm',
      () async {
        final schedule = buildSchedule(
          id: 'ended-alarm',
          scheduleTime: now.add(const Duration(hours: 1)),
          steps: const [
            PreparationStepWithTimeEntity(
              id: 'a',
              preparationName: 'a',
              preparationTime: Duration(minutes: 5),
              nextPreparationId: null,
            ),
          ],
        ).copyWith(doneStatus: ScheduleDoneStatus.normalEnd);
        getScheduleByIdUseCase.schedules['ended-alarm'] = schedule;

        bloc.add(const ScheduleAlarmPromptRequested(scheduleId: 'ended-alarm'));
        await Future<void>.delayed(Duration.zero);

        expect(cancelScheduleAlarmUseCase.calls, ['ended-alarm']);
        expect(navigationService.goRoutes, ['/home']);
        expect(bloc.state.status, ScheduleStatus.initial);
      },
    );

    test(
      'remote alarm prompt rejects stale fingerprint unless it starts prep',
      () async {
        final schedule = buildSchedule(
          id: 'remote-stale',
          scheduleTime: now.add(const Duration(hours: 1)),
          steps: const [
            PreparationStepWithTimeEntity(
              id: 'a',
              preparationName: 'a',
              preparationTime: Duration(minutes: 5),
              nextPreparationId: null,
            ),
          ],
        );
        getScheduleByIdUseCase.schedules['remote-stale'] = schedule;
        getPreparationByScheduleIdUseCase.preparations['remote-stale'] =
            const PreparationEntity(
              preparationStepList: [
                PreparationStepEntity(
                  id: 'a',
                  preparationName: 'a',
                  preparationTime: Duration(minutes: 5),
                  nextPreparationId: null,
                ),
              ],
            );

        bloc.add(
          const ScheduleAlarmPromptRequested(
            scheduleId: 'remote-stale',
            scheduleFingerprint: 'old-fingerprint',
          ),
        );
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(cancelScheduleAlarmUseCase.calls, ['remote-stale']);
        expect(navigationService.goRoutes, ['/home']);

        cancelScheduleAlarmUseCase.calls.clear();
        navigationService.goRoutes.clear();
        bloc.add(
          const ScheduleAlarmPromptRequested(
            scheduleId: 'remote-stale',
            scheduleFingerprint: 'old-fingerprint',
            startPreparation: true,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.status, ScheduleStatus.upcoming);
        expect(bloc.state.schedule?.id, 'remote-stale');
        expect(cancelScheduleAlarmUseCase.calls, isEmpty);
        expect(navigationService.goRoutes, isEmpty);
      },
    );

    test(
      'alarm prompt validation failure clears only non-start prompts',
      () async {
        getScheduleByIdUseCase.throwingIds.add('missing-alarm');

        bloc.add(
          const ScheduleAlarmPromptRequested(scheduleId: 'missing-alarm'),
        );
        await Future<void>.delayed(Duration.zero);

        expect(cancelScheduleAlarmUseCase.calls, ['missing-alarm']);
        expect(navigationService.goRoutes, ['/home']);

        cancelScheduleAlarmUseCase.calls.clear();
        navigationService.goRoutes.clear();
        bloc.add(
          const ScheduleAlarmPromptRequested(
            scheduleId: 'missing-alarm',
            startPreparation: true,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(cancelScheduleAlarmUseCase.calls, isEmpty);
        expect(navigationService.goRoutes, isEmpty);
      },
    );

    test('finish failure keeps the active schedule visible', () async {
      final schedule = buildSchedule(
        id: 'finish-fails',
        scheduleTime: now.add(const Duration(minutes: 35)),
        steps: const [
          PreparationStepWithTimeEntity(
            id: 'a',
            preparationName: 'a',
            preparationTime: Duration(minutes: 10),
            nextPreparationId: null,
          ),
        ],
      );
      finishUseCase.throwOnCall = true;
      now = schedule.preparationStartTime.add(const Duration(minutes: 1));
      bloc.add(ScheduleUpcomingReceived(schedule));
      await bloc.stream.firstWhere((s) => s.status == ScheduleStatus.ongoing);

      bloc.add(const ScheduleFinished(11));
      await Future<void>.delayed(Duration.zero);

      expect(finishUseCase.calls, [('finish-fails', 11)]);
      expect(bloc.state.status, ScheduleStatus.ongoing);
      expect(clearTimedUseCase.calls, isNot(contains('finish-fails')));
    });
  });

  test('schedule events expose equality props for bloc deduping', () {
    final schedule = buildSchedule(
      id: 'props',
      scheduleTime: DateTime(2026, 3, 20, 10),
      steps: const [
        PreparationStepWithTimeEntity(
          id: 'a',
          preparationName: 'a',
          preparationTime: Duration(minutes: 5),
          nextPreparationId: null,
        ),
      ],
    );

    expect(
      const ScheduleAlarmPromptRequested(
        scheduleId: 's1',
        scheduleFingerprint: 'fingerprint',
        startPreparation: true,
      ),
      const ScheduleAlarmPromptRequested(
        scheduleId: 's1',
        scheduleFingerprint: 'fingerprint',
        startPreparation: true,
      ),
    );
    expect(ScheduleUpcomingReceived(schedule).props, [schedule]);
    expect(
      const ScheduleAlarmPromptRequested(
        scheduleId: 's1',
        scheduleFingerprint: 'fingerprint',
        startPreparation: true,
      ).props,
      ['s1', 'fingerprint', true],
    );
    expect(const ScheduleTick(Duration(seconds: 3)).props, [
      const Duration(seconds: 3),
    ]);
    expect(const ScheduleFinished(4).props, [4]);
    expect(const ScheduleEvent().props, isEmpty);
    expect(const ScheduleSubscriptionRequested().props, isEmpty);
    expect(const ScheduleStarted().props, isEmpty);
    expect(const SchedulePreparationStarted().props, isEmpty);
    expect(const ScheduleStepSkipped().props, isEmpty);
  });
}
