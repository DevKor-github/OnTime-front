import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/core/services/notification_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/services/navigation_service.dart';
import 'package:on_time_front/domain/entities/early_start_session_entity.dart';
import 'package:on_time_front/domain/entities/preparation_action_event_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/use-cases/get_nearest_upcoming_schedule_use_case.dart';
import 'package:on_time_front/domain/use-cases/schedule_preparation_session_use_case.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';
import 'schedule_bloc_test.dart' show buildSchedule;

class _Session implements SchedulePreparationSessionUseCase {
  @override
  Future<EarlyStartSessionEntity?> getEarlyStartSession(String id) async =>
      null;
  @override
  Future<ScheduleWithPreparationEntity> restoreTimedPreparationIfValid(
    ScheduleWithPreparationEntity schedule, {
    required DateTime now,
    RestoredSessionCallback? onRestoredSession,
    void Function()? onInvalidated,
  }) async => schedule;
  @override
  Future<void> saveTimedPreparationSnapshot(
    ScheduleWithPreparationEntity schedule, {
    DateTime? savedAt,
    DateTime? startedAt,
    List<PreparationActionEventEntity> actionEvents = const [],
    bool persist = true,
  }) async {}
  @override
  Future<void> clearPersistedState(String id) async {}
  @override
  Future<void> finishSchedulePreparation(
    String id, {
    required int latenessTime,
  }) async {}
  @override
  Future<void> startSchedulePreparation(String id) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Nearest implements GetNearestUpcomingScheduleUseCase {
  @override
  Stream<ScheduleWithPreparationEntity?> call() => const Stream.empty();
}

class _Navigation extends NavigationService {
  @override
  void push(String routeName, {Object? extra}) {}
}

class _Harness {
  _Harness(
    this.tester, {
    this.phase = AppLifecycleState.paused,
    FutureOr<void> Function(bool Function())? submit,
    NotifyPreparationStep? delivery,
  }) {
    bloc = ScheduleBloc.test(
      _Nearest(),
      _Navigation(),
      _Session(),
      nowProvider: () => wall,
      monotonicNow: () => mono,
      lifecycleState: () => phase,
      notifyPreparationStep:
          ({
            required scheduleName,
            required preparationName,
            required scheduleId,
            required stepId,
            required isCurrent,
          }) {
            attempts.add((scheduleId, stepId));
            if (delivery != null) {
              return delivery(
                scheduleName: scheduleName,
                preparationName: preparationName,
                scheduleId: scheduleId,
                stepId: stepId,
                isCurrent: isCurrent,
              );
            }
            return submit?.call(isCurrent);
          },
    );
  }
  final WidgetTester tester;
  DateTime wall = DateTime(2026, 9, 24, 10);
  Duration mono = Duration.zero;
  AppLifecycleState? phase;
  late final ScheduleBloc bloc;
  final attempts = <(String, String)>[];
  Future<void> start({
    String id = 'occurrence',
    int elapsed = 1,
    int count = 4,
  }) async {
    final steps = [
      for (var i = 1; i <= count; i++)
        PreparationStepWithTimeEntity(
          id: 's$i',
          preparationName: 'private $i',
          preparationTime: const Duration(seconds: 3),
          nextPreparationId: i == count ? null : 's${i + 1}',
        ),
    ];
    bloc.add(
      ScheduleUpcomingReceived(
        buildSchedule(
          id: id,
          scheduleTime: wall.add(Duration(seconds: count * 3 - elapsed)),
          moveTime: Duration.zero,
          scheduleSpareTime: Duration.zero,
          steps: steps,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> tick({
    Duration wallDelta = const Duration(seconds: 1),
    Duration monoDelta = const Duration(seconds: 1),
  }) async {
    wall = wall.add(wallDelta);
    mono += monoDelta;
    // This fires the real production Timer.periodic, never a synthetic Tick.
    await tester.pump(const Duration(seconds: 1));
  }

  void changePhase(AppLifecycleState next) {
    phase = next;
    bloc.observeLifecycleState(next);
  }

  Future<void> close() async {
    await tester.runAsync(() => bloc.close());
  }
}

void main() {
  testWidgets('actual periodic refresh submits a fresh paused step once', (
    tester,
  ) async {
    final h = _Harness(tester);
    await h.start();
    await h.tick();
    await h.tick();
    await h.tick();
    expect(h.bloc.state.schedule!.preparation.currentStep!.id, 's2');
    expect(h.attempts, [('occurrence', 's2')]);
    await h.close();
  });
  testWidgets(
    'actual periodic timer reaches plugin show once with private content',
    (tester) async {
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      const permissionChannel = MethodChannel(
        'flutter.baseflow.com/permissions/methods',
      );
      final submissions = <Map>[];
      final permissionMethods = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'show') submissions.add(call.arguments as Map);
        return null;
      });
      messenger.setMockMethodCallHandler(permissionChannel, (call) async {
        permissionMethods.add(call.method);
        return 1;
      });
      final owner = AlarmOperationCoordinator(LocalDataOperationGate());
      final service = NotificationService.test(
        localNotifications: FlutterLocalNotificationsPlugin(),
        isAndroidOverride: true,
        isIOSOverride: false,
        isFlutterLocalNotificationsInitialized: true,
        alarmOwner: owner,
        localeProvider: () => 'ko',
      );
      final h = _Harness(
        tester,
        delivery: service.showPreparationStepNotification,
      );
      try {
        await h.start();
        await h.tick();
        await h.tick();
        await h.tick();
        await tester.pump();
        expect(submissions, hasLength(1));
        expect(submissions.single['title'], '준비 단계가 바뀌었어요');
        expect(jsonDecode(submissions.single['payload'] as String), {
          'type': 'preparation_step',
          'scheduleId': 'occurrence',
          'stepId': 's2',
        });
        expect(submissions.single.toString(), isNot(contains('private')));
        expect(permissionMethods, ['checkPermissionStatus']);
      } finally {
        await h.close();
        owner.dispose();
        messenger.setMockMethodCallHandler(channel, null);
        messenger.setMockMethodCallHandler(permissionChannel, null);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
  for (final phase in [
    AppLifecycleState.resumed,
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.detached,
    null,
  ]) {
    testWidgets('$phase updates UI silently without later replay', (
      tester,
    ) async {
      final h = _Harness(tester, phase: phase);
      await h.start();
      await h.tick();
      await h.tick();
      expect(h.bloc.state.schedule!.preparation.currentStep!.id, 's2');
      expect(h.attempts, isEmpty);
      h.changePhase(AppLifecycleState.paused);
      await h.tick();
      expect(h.attempts, isEmpty);
      await h.tick();
      await h.tick();
      expect(h.attempts, [('occurrence', 's3')]);
      await h.close();
    });
  }
  for (final delta in [
    const Duration(seconds: 2),
    const Duration(microseconds: 2000001),
  ]) {
    testWidgets('freshness boundary $delta', (tester) async {
      final h = _Harness(tester);
      await h.start();
      await h.tick(wallDelta: delta, monoDelta: delta);
      expect(h.attempts.length, delta == const Duration(seconds: 2) ? 1 : 0);
      await h.tick();
      expect(h.attempts.length, delta == const Duration(seconds: 2) ? 1 : 0);
      await h.close();
    });
  }
  for (final jitter in [
    const Duration(milliseconds: 250),
    const Duration(microseconds: 250001),
  ]) {
    testWidgets('wall/monotonic tolerance boundary $jitter', (tester) async {
      final h = _Harness(tester);
      await h.start(elapsed: 2);
      await h.tick(wallDelta: const Duration(seconds: 1) + jitter);
      expect(
        h.attempts.length,
        jitter == const Duration(milliseconds: 250) ? 1 : 0,
      );
      await h.close();
    });
  }
  testWidgets('phase roundtrip between observations resets continuity', (
    tester,
  ) async {
    final h = _Harness(tester);
    await h.start();
    await h.tick();
    h.changePhase(AppLifecycleState.inactive);
    h.changePhase(AppLifecycleState.paused);
    await h.tick();
    expect(h.attempts, isEmpty);
    await h.tick();
    expect(h.attempts, isEmpty);
    await h.close();
  });
  for (final wallDelta in [
    const Duration(seconds: 3),
    const Duration(seconds: -1),
    const Duration(seconds: 7),
  ]) {
    testWidgets('clock jump $wallDelta does not submit stale step', (
      tester,
    ) async {
      final h = _Harness(tester);
      await h.start();
      await h.tick();
      await h.tick(wallDelta: wallDelta);
      expect(h.attempts, isEmpty);
      await h.close();
    });
  }
  testWidgets('resume catch-up and legacy Tick cannot replay or double count', (
    tester,
  ) async {
    final h = _Harness(tester);
    await h.start();
    await h.tick();
    h.wall = h.wall.add(const Duration(seconds: 4));
    h.mono += const Duration(seconds: 4);
    h.bloc.add(
      const SchedulePreparationTimeRefreshRequested(
        origin: PreparationRefreshOrigin.resume,
      ),
    );
    h.bloc.add(const ScheduleTick(Duration(hours: 1)));
    await tester.pump();
    expect(h.bloc.state.schedule!.preparation.currentStep!.id, 's3');
    expect(
      h.bloc.state.schedule!.preparation.elapsedTime,
      const Duration(seconds: 6),
    );
    expect(h.attempts, isEmpty);
    await h.tick();
    expect(h.attempts, isEmpty);
    await h.close();
  });
  testWidgets(
    'restore is silent then future adjacent boundary remains eligible',
    (tester) async {
      final h = _Harness(tester);
      await h.start(elapsed: 4);
      expect(h.bloc.state.schedule!.preparation.currentStep!.id, 's2');
      expect(h.attempts, isEmpty);
      await h.tick();
      await h.tick();
      expect(h.attempts, [('occurrence', 's3')]);
      await h.close();
    },
  );
  testWidgets('skip is silent, next automatic transition is independent', (
    tester,
  ) async {
    final h = _Harness(tester);
    await h.start();
    await h.tick();
    h.bloc.add(const ScheduleStepSkipped());
    await tester.pump();
    expect(h.attempts, isEmpty);
    await h.tick();
    await h.tick();
    await h.tick();
    expect(h.attempts, [('occurrence', 's3')]);
    await h.close();
  });
  testWidgets('first and final transitions produce no notification', (
    tester,
  ) async {
    final h = _Harness(tester);
    await h.start(count: 1);
    await h.tick();
    await h.tick();
    await h.tick();
    expect(h.bloc.state.schedule!.preparation.isAllStepsDone, isTrue);
    expect(h.attempts, isEmpty);
    await h.close();
  });
  for (final asyncError in [false, true]) {
    testWidgets(
      'delivery ${asyncError ? 'Future error' : 'sync throw'} consumes candidate but next step proceeds',
      (tester) async {
        var count = 0;
        final h = _Harness(
          tester,
          submit: (_) {
            if (++count == 1) {
              if (asyncError) {
                return Future<void>.error(StateError('synthetic'));
              }
              throw StateError('synthetic');
            }
          },
        );
        await h.start();
        for (var i = 0; i < 5; i++) {
          await h.tick();
        }
        expect(h.attempts, [('occurrence', 's2'), ('occurrence', 's3')]);
        expect(tester.takeException(), isNull);
        await h.close();
      },
    );
  }
  for (final interruption in [
    'resume',
    'prompt',
    'delete',
    'finish',
    'generation',
    'stale',
  ]) {
    testWidgets('await validity rejects $interruption', (tester) async {
      final barrier = Completer<void>();
      final submitted = <bool>[];
      final h = _Harness(
        tester,
        submit: (current) async {
          await barrier.future;
          submitted.add(current());
        },
      );
      await h.start();
      await h.tick();
      await h.tick();
      expect(h.attempts, hasLength(1));
      switch (interruption) {
        case 'resume':
          h.changePhase(AppLifecycleState.resumed);
        case 'prompt':
          h.bloc.presentNotificationPrompt(
            h.bloc.state.schedule!,
            Object(),
            () => true,
          );
        case 'delete':
          h.bloc.add(const ScheduleUpcomingReceived(null));
        case 'finish':
          h.bloc.add(const ScheduleFinished(0));
        case 'generation':
          await LocalDataOperationGate.shared.run(
            () async {},
            replacesData: true,
          );
        case 'stale':
          h.mono += const Duration(seconds: 3);
          h.wall = h.wall.add(const Duration(seconds: 3));
      }
      await tester.pump();
      barrier.complete();
      await tester.pump();
      expect(submitted, [false]);
      await h.close();
    });
  }
  testWidgets(
    'same occurrence new run resets dedupe, restore does not replay',
    (tester) async {
      final h = _Harness(tester);
      await h.start();
      await h.tick();
      await h.tick();
      await h.start(elapsed: 3);
      await h.tick();
      expect(h.attempts, [('occurrence', 's2')]);
      h.bloc.add(const ScheduleFinished(0));
      await tester.pump();
      await h.start();
      await h.tick();
      await h.tick();
      expect(h.attempts, [('occurrence', 's2'), ('occurrence', 's2')]);
      await h.close();
    },
  );
  testWidgets(
    'replacement generation with reused run and step IDs has independent attempts',
    (tester) async {
      final h = _Harness(tester);
      await h.start();
      await h.tick();
      await h.tick();
      await LocalDataOperationGate.shared.run(() async {}, replacesData: true);
      h.wall = h.wall.subtract(const Duration(seconds: 2));
      await h.start();
      expect(h.attempts, hasLength(1));
      await h.tick();
      await h.tick();
      expect(h.attempts, [('occurrence', 's2'), ('occurrence', 's2')]);
      await h.close();
    },
  );
  testWidgets('occurrences sharing step IDs have independent attempts', (
    tester,
  ) async {
    final h = _Harness(tester);
    await h.start();
    await h.tick();
    await h.tick();
    await h.start(id: 'next-occurrence');
    await h.tick();
    await h.tick();
    expect(h.attempts, [('occurrence', 's2'), ('next-occurrence', 's2')]);
    await h.close();
  });
}
