import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/core/services/navigation_service.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_with_time_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/entities/timed_preparation_snapshot_entity.dart';
import 'package:on_time_front/domain/entities/early_start_session_entity.dart';
import 'package:on_time_front/domain/use-cases/clear_early_start_session_use_case.dart';
import 'package:on_time_front/domain/use-cases/clear_timed_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/finish_schedule_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_nearest_upcoming_schedule_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_early_start_session_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_timed_preparation_snapshot_use_case.dart';
import 'package:on_time_front/domain/use-cases/mark_early_start_session_use_case.dart';
import 'package:on_time_front/domain/use-cases/save_timed_preparation_use_case.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/alarm/screens/alarm_screen.dart';
import 'package:on_time_front/presentation/alarm/screens/schedule_start_screen.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';
import 'package:on_time_front/presentation/shared/components/modal_wide_button.dart';
import 'package:on_time_front/presentation/shared/components/two_action_dialog.dart';

class StubGetNearestUpcomingScheduleUseCase
    implements GetNearestUpcomingScheduleUseCase {
  StubGetNearestUpcomingScheduleUseCase(this.streamFactory);
  final Stream<ScheduleWithPreparationEntity?> Function() streamFactory;

  @override
  Stream<ScheduleWithPreparationEntity?> call() => streamFactory();
}

class SpyNavigationService extends NavigationService {
  final List<String> pushedRoutes = [];

  @override
  void push(String routeName, {Object? extra}) {
    pushedRoutes.add(routeName);
  }
}

class NoopSaveTimedPreparationUseCase implements SaveTimedPreparationUseCase {
  @override
  Future<void> call(
    ScheduleWithPreparationEntity schedule,
    PreparationWithTimeEntity preparation, {
    DateTime? savedAt,
  }) async {}
}

class SpyFinishScheduleUseCase implements FinishScheduleUseCase {
  final List<(String, int)> calls = [];

  @override
  Future<void> call(String scheduleId, int latenessTime) async {
    calls.add((scheduleId, latenessTime));
  }
}

class StubGetTimedPreparationSnapshotUseCase
    implements GetTimedPreparationSnapshotUseCase {
  StubGetTimedPreparationSnapshotUseCase(this.snapshotById);

  final Map<String, TimedPreparationSnapshotEntity> snapshotById;

  @override
  Future<TimedPreparationSnapshotEntity?> call(String scheduleId) async {
    return snapshotById[scheduleId];
  }
}

class NoopClearTimedPreparationUseCase implements ClearTimedPreparationUseCase {
  @override
  Future<void> call(String scheduleId) async {}
}

class EarlyStartSessionStore {
  final Map<String, DateTime> sessions = {};
}

class InMemoryMarkEarlyStartSessionUseCase
    implements MarkEarlyStartSessionUseCase {
  InMemoryMarkEarlyStartSessionUseCase(this.store);

  final EarlyStartSessionStore store;

  @override
  Future<void> call({
    required String scheduleId,
    required DateTime startedAt,
  }) async {
    store.sessions[scheduleId] = startedAt;
  }
}

class InMemoryGetEarlyStartSessionUseCase
    implements GetEarlyStartSessionUseCase {
  InMemoryGetEarlyStartSessionUseCase(this.store);

  final EarlyStartSessionStore store;

  @override
  Future<EarlyStartSessionEntity?> call(String scheduleId) async {
    final startedAt = store.sessions[scheduleId];
    if (startedAt == null) return null;
    return EarlyStartSessionEntity(
        scheduleId: scheduleId, startedAt: startedAt);
  }
}

class InMemoryClearEarlyStartSessionUseCase
    implements ClearEarlyStartSessionUseCase {
  InMemoryClearEarlyStartSessionUseCase(this.store);

  final EarlyStartSessionStore store;

  @override
  Future<void> call(String scheduleId) async {
    store.sessions.remove(scheduleId);
  }
}

class EarlyStartUseCaseBundle {
  EarlyStartUseCaseBundle._(
    this.markUseCase,
    this.getUseCase,
    this.clearUseCase,
  );

  final InMemoryMarkEarlyStartSessionUseCase markUseCase;
  final InMemoryGetEarlyStartSessionUseCase getUseCase;
  final InMemoryClearEarlyStartSessionUseCase clearUseCase;
}

EarlyStartUseCaseBundle createEarlyStartUseCaseBundle() {
  final store = EarlyStartSessionStore();
  return EarlyStartUseCaseBundle._(
    InMemoryMarkEarlyStartSessionUseCase(store),
    InMemoryGetEarlyStartSessionUseCase(store),
    InMemoryClearEarlyStartSessionUseCase(store),
  );
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

Future<void> pumpWithRouter(
  WidgetTester tester, {
  required ScheduleBloc bloc,
  required GoRouter router,
}) async {
  await tester.pumpWidget(
    BlocProvider.value(
      value: bloc,
      child: DefaultAssetBundle(
        bundle: _TestAssetBundle(),
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    ),
  );
  await tester.pump();
}

class _TestAssetBundle extends CachingAssetBundle {
  static const _minimalSvg =
      '<svg viewBox="0 0 1 1" xmlns="http://www.w3.org/2000/svg"><rect width="1" height="1"/></svg>';

  @override
  Future<ByteData> load(String key) async {
    final bytes = Uint8List.fromList(utf8.encode(_minimalSvg));
    return ByteData.view(bytes.buffer);
  }
}

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int stepMs = 20,
  int maxMs = 2000,
}) async {
  var elapsed = 0;
  while (elapsed <= maxMs) {
    await tester.pump(Duration(milliseconds: stepMs));
    if (finder.evaluate().isNotEmpty) return;
    elapsed += stepMs;
  }
  throw TestFailure('Timed out waiting for finder: $finder');
}

Future<void> tapAndPump(
  WidgetTester tester,
  Finder finder, {
  int stepMs = 20,
  int maxMs = 2000,
}) async {
  await pumpUntilFound(tester, finder, stepMs: stepMs, maxMs: maxMs);
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(Duration(milliseconds: stepMs));
}

Future<void> pumpUntilRouteText(
  WidgetTester tester,
  String routeText, {
  int stepMs = 20,
  int maxMs = 2000,
}) async {
  await pumpUntilFound(
    tester,
    find.text(routeText),
    stepMs: stepMs,
    maxMs: maxMs,
  );
}

Future<void> setLargeTestViewport(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1200, 2200);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  group('Preparation flow widgets', () {
    late StreamController<ScheduleWithPreparationEntity?> controller;
    late SpyNavigationService navigationService;
    late SpyFinishScheduleUseCase finishUseCase;
    late StubGetTimedPreparationSnapshotUseCase getSnapshotUseCase;
    late NoopClearTimedPreparationUseCase clearTimedUseCase;
    late EarlyStartSessionStore earlySessionStore;
    late InMemoryMarkEarlyStartSessionUseCase markEarlyStartUseCase;
    late InMemoryGetEarlyStartSessionUseCase getEarlyStartUseCase;
    late InMemoryClearEarlyStartSessionUseCase clearEarlyStartUseCase;
    late DateTime now;
    late ScheduleBloc bloc;

    setUp(() {
      controller = StreamController<ScheduleWithPreparationEntity?>.broadcast();
      navigationService = SpyNavigationService();
      finishUseCase = SpyFinishScheduleUseCase();
      getSnapshotUseCase = StubGetTimedPreparationSnapshotUseCase({});
      clearTimedUseCase = NoopClearTimedPreparationUseCase();
      earlySessionStore = EarlyStartSessionStore();
      markEarlyStartUseCase =
          InMemoryMarkEarlyStartSessionUseCase(earlySessionStore);
      getEarlyStartUseCase =
          InMemoryGetEarlyStartSessionUseCase(earlySessionStore);
      clearEarlyStartUseCase =
          InMemoryClearEarlyStartSessionUseCase(earlySessionStore);
      now = DateTime(2026, 3, 20, 9, 0, 0);
      bloc = ScheduleBloc.test(
        StubGetNearestUpcomingScheduleUseCase(() => controller.stream),
        navigationService,
        NoopSaveTimedPreparationUseCase(),
        getSnapshotUseCase,
        clearTimedUseCase,
        finishUseCase,
        markEarlyStartSessionUseCase: markEarlyStartUseCase,
        getEarlyStartSessionUseCase: getEarlyStartUseCase,
        clearEarlyStartSessionUseCase: clearEarlyStartUseCase,
        nowProvider: () => now,
      );
    });

    tearDown(() async {
      await bloc.close();
      await controller.close();
    });

    testWidgets('five-minute start screen variant is shown with route extra',
        (tester) async {
      await setLargeTestViewport(tester);

      final router = GoRouter(
        initialLocation: '/scheduleStart',
        routes: [
          GoRoute(
            path: '/scheduleStart',
            builder: (_, __) => const ScheduleStartScreen(
              isFiveMinutesBefore: true,
            ),
          ),
          GoRoute(
              path: '/alarmScreen', builder: (_, __) => const Text('ALARM')),
          GoRoute(path: '/home', builder: (_, __) => const Text('HOME')),
        ],
      );

      await pumpWithRouter(tester, bloc: bloc, router: router);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ScheduleStartScreen), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNWidgets(2));
    }, timeout: const Timeout(Duration(seconds: 15)));

    testWidgets('schedule start button navigates to alarm', (tester) async {
      await setLargeTestViewport(tester);

      final schedule = buildSchedule(
        id: 's2',
        scheduleTime: now.add(const Duration(minutes: 40)),
        steps: const [
          PreparationStepWithTimeEntity(
            id: 'p1',
            preparationName: 'Prep',
            preparationTime: Duration(minutes: 10),
            nextPreparationId: null,
          ),
        ],
      );
      bloc.add(ScheduleUpcomingReceived(schedule));

      final router = GoRouter(
        initialLocation: '/scheduleStart',
        routes: [
          GoRoute(
            path: '/scheduleStart',
            builder: (_, __) =>
                const ScheduleStartScreen(isFiveMinutesBefore: true),
          ),
          GoRoute(
              path: '/alarmScreen',
              builder: (_, __) => const Text('ALARM_ROUTE')),
          GoRoute(path: '/home', builder: (_, __) => const Text('HOME_ROUTE')),
        ],
      );

      await pumpWithRouter(tester, bloc: bloc, router: router);
      await tapAndPump(tester, find.text('Start Preparing'));
      await pumpUntilRouteText(tester, 'ALARM_ROUTE');
      expect(find.text('ALARM_ROUTE'), findsOneWidget);
    }, timeout: const Timeout(Duration(seconds: 15)));

    testWidgets('schedule start in five button navigates home', (tester) async {
      await setLargeTestViewport(tester);

      final schedule = buildSchedule(
        id: 's2b',
        scheduleTime: now.add(const Duration(minutes: 40)),
        steps: const [
          PreparationStepWithTimeEntity(
            id: 'p1',
            preparationName: 'Prep',
            preparationTime: Duration(minutes: 10),
            nextPreparationId: null,
          ),
        ],
      );
      bloc.add(ScheduleUpcomingReceived(schedule));

      final router = GoRouter(
        initialLocation: '/scheduleStart',
        routes: [
          GoRoute(
            path: '/scheduleStart',
            builder: (_, __) =>
                const ScheduleStartScreen(isFiveMinutesBefore: true),
          ),
          GoRoute(
              path: '/alarmScreen',
              builder: (_, __) => const Text('ALARM_ROUTE')),
          GoRoute(path: '/home', builder: (_, __) => const Text('HOME_ROUTE')),
        ],
      );

      await pumpWithRouter(tester, bloc: bloc, router: router);
      await tapAndPump(tester, find.text('Start in 5 minutes'));
      await pumpUntilRouteText(tester, 'HOME_ROUTE');
      expect(find.text('HOME_ROUTE'), findsOneWidget);
    }, timeout: const Timeout(Duration(seconds: 15)));

    testWidgets(
        'manual finish before leave time sends lateness 0 and navigates',
        (tester) async {
      await setLargeTestViewport(tester);
      now = DateTime.now();

      final schedule = buildSchedule(
        id: 's3',
        scheduleTime: now.add(const Duration(minutes: 35)),
        steps: const [
          PreparationStepWithTimeEntity(
            id: 'p1',
            preparationName: 'Prep',
            preparationTime: Duration(minutes: 10),
            nextPreparationId: null,
          ),
        ],
      );

      final router = GoRouter(
        initialLocation: '/alarmScreen',
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const Text('HOME')),
          GoRoute(
              path: '/alarmScreen', builder: (_, __) => const AlarmScreen()),
          GoRoute(
            path: '/earlyLate',
            builder: (_, state) {
              final extra = state.extra as Map<String, dynamic>;
              return Text(
                  'EARLYLATE:${extra['isLate']}:${extra['earlyLateTime']}');
            },
          ),
        ],
      );

      final earlyBundle = createEarlyStartUseCaseBundle();
      final alarmBloc = ScheduleBloc.test(
        StubGetNearestUpcomingScheduleUseCase(() => Stream.value(schedule)),
        navigationService,
        NoopSaveTimedPreparationUseCase(),
        StubGetTimedPreparationSnapshotUseCase({}),
        NoopClearTimedPreparationUseCase(),
        finishUseCase,
        markEarlyStartSessionUseCase: earlyBundle.markUseCase,
        getEarlyStartSessionUseCase: earlyBundle.getUseCase,
        clearEarlyStartSessionUseCase: earlyBundle.clearUseCase,
        nowProvider: () => now,
      );
      addTearDown(alarmBloc.close);

      await pumpWithRouter(tester, bloc: alarmBloc, router: router);
      await pumpUntilFound(tester, find.byType(ElevatedButton));

      await tapAndPump(tester, find.byType(ElevatedButton).first);
      await pumpUntilFound(tester, find.textContaining('EARLYLATE:false'));

      expect(finishUseCase.calls.single.$2, 0);
      expect(find.textContaining('EARLYLATE:false'), findsOneWidget);
    }, timeout: const Timeout(Duration(seconds: 15)));

    testWidgets('manual finish after leave threshold sends positive lateness',
        (tester) async {
      await setLargeTestViewport(tester);
      now = DateTime.now();

      final schedule = buildSchedule(
        id: 's4',
        scheduleTime: now.add(const Duration(minutes: 25)),
        steps: const [
          PreparationStepWithTimeEntity(
            id: 'p1',
            preparationName: 'Prep',
            preparationTime: Duration(minutes: 10),
            nextPreparationId: null,
          ),
        ],
      );
      // make user already late relative to leave time
      now = now.add(const Duration(minutes: 2));

      final router = GoRouter(
        initialLocation: '/alarmScreen',
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const Text('HOME')),
          GoRoute(
              path: '/alarmScreen', builder: (_, __) => const AlarmScreen()),
          GoRoute(
            path: '/earlyLate',
            builder: (_, state) {
              final extra = state.extra as Map<String, dynamic>;
              return Text(
                  'EARLYLATE:${extra['isLate']}:${extra['earlyLateTime']}');
            },
          ),
        ],
      );

      final earlyBundle = createEarlyStartUseCaseBundle();
      final alarmBloc = ScheduleBloc.test(
        StubGetNearestUpcomingScheduleUseCase(() => Stream.value(schedule)),
        navigationService,
        NoopSaveTimedPreparationUseCase(),
        StubGetTimedPreparationSnapshotUseCase({}),
        NoopClearTimedPreparationUseCase(),
        finishUseCase,
        markEarlyStartSessionUseCase: earlyBundle.markUseCase,
        getEarlyStartSessionUseCase: earlyBundle.getUseCase,
        clearEarlyStartSessionUseCase: earlyBundle.clearUseCase,
        nowProvider: () => now,
      );
      addTearDown(alarmBloc.close);

      await pumpWithRouter(tester, bloc: alarmBloc, router: router);
      // This case auto-completes the only step immediately, so finish via dialog.
      await pumpUntilFound(tester, find.byType(TwoActionDialog));
      await tapAndPump(tester, find.byType(ModalWideButton).last);
      await pumpUntilFound(tester, find.textContaining('EARLYLATE:true'));

      expect(finishUseCase.calls.single.$2, greaterThan(0));
      expect(find.textContaining('EARLYLATE:true'), findsOneWidget);
    }, timeout: const Timeout(Duration(seconds: 15)));

    testWidgets('completion dialog continue keeps user in alarm flow',
        (tester) async {
      await setLargeTestViewport(tester);
      now = DateTime.now();

      final schedule = buildSchedule(
        id: 's5',
        scheduleTime: now.add(const Duration(minutes: 35)),
        steps: const [
          PreparationStepWithTimeEntity(
            id: 'p1',
            preparationName: 'Prep',
            preparationTime: Duration(minutes: 10),
            nextPreparationId: null,
            isDone: true,
            elapsedTime: Duration(minutes: 10),
          ),
        ],
      );

      final router = GoRouter(
        initialLocation: '/alarmScreen',
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const Text('HOME')),
          GoRoute(
              path: '/alarmScreen', builder: (_, __) => const AlarmScreen()),
          GoRoute(
              path: '/earlyLate', builder: (_, __) => const Text('EARLYLATE')),
        ],
      );

      final earlyBundle = createEarlyStartUseCaseBundle();
      final alarmBloc = ScheduleBloc.test(
        StubGetNearestUpcomingScheduleUseCase(() => Stream.value(schedule)),
        navigationService,
        NoopSaveTimedPreparationUseCase(),
        StubGetTimedPreparationSnapshotUseCase({}),
        NoopClearTimedPreparationUseCase(),
        finishUseCase,
        markEarlyStartSessionUseCase: earlyBundle.markUseCase,
        getEarlyStartSessionUseCase: earlyBundle.getUseCase,
        clearEarlyStartSessionUseCase: earlyBundle.clearUseCase,
        nowProvider: () => now,
      );
      addTearDown(alarmBloc.close);

      await pumpWithRouter(tester, bloc: alarmBloc, router: router);
      await pumpUntilFound(tester, find.byType(TwoActionDialog));

      expect(find.byType(TwoActionDialog), findsOneWidget);
      await tapAndPump(tester, find.byType(ModalWideButton).first);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('EARLYLATE'), findsNothing);
      expect(finishUseCase.calls, isEmpty);
      // Explicitly finish to stop periodic timer before test ends.
      alarmBloc.add(const ScheduleFinished(0));
      await tester.pump();
    }, timeout: const Timeout(Duration(seconds: 15)));

    testWidgets('completion dialog finish triggers finish flow',
        (tester) async {
      await setLargeTestViewport(tester);
      now = DateTime.now();

      final schedule = buildSchedule(
        id: 's6',
        scheduleTime: now.add(const Duration(minutes: 35)),
        steps: const [
          PreparationStepWithTimeEntity(
            id: 'p1',
            preparationName: 'Prep',
            preparationTime: Duration(minutes: 10),
            nextPreparationId: null,
            isDone: true,
            elapsedTime: Duration(minutes: 10),
          ),
        ],
      );

      final router = GoRouter(
        initialLocation: '/alarmScreen',
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const Text('HOME')),
          GoRoute(
              path: '/alarmScreen', builder: (_, __) => const AlarmScreen()),
          GoRoute(
              path: '/earlyLate', builder: (_, __) => const Text('EARLYLATE')),
        ],
      );

      final earlyBundle = createEarlyStartUseCaseBundle();
      final alarmBloc = ScheduleBloc.test(
        StubGetNearestUpcomingScheduleUseCase(() => Stream.value(schedule)),
        navigationService,
        NoopSaveTimedPreparationUseCase(),
        StubGetTimedPreparationSnapshotUseCase({}),
        NoopClearTimedPreparationUseCase(),
        finishUseCase,
        markEarlyStartSessionUseCase: earlyBundle.markUseCase,
        getEarlyStartSessionUseCase: earlyBundle.getUseCase,
        clearEarlyStartSessionUseCase: earlyBundle.clearUseCase,
        nowProvider: () => now,
      );
      addTearDown(alarmBloc.close);

      await pumpWithRouter(tester, bloc: alarmBloc, router: router);
      await pumpUntilFound(tester, find.byType(TwoActionDialog));

      await tapAndPump(tester, find.byType(ModalWideButton).last);
      await pumpUntilRouteText(tester, 'EARLYLATE');

      expect(find.text('EARLYLATE'), findsOneWidget);
      expect(finishUseCase.calls.length, 1);
    }, timeout: const Timeout(Duration(seconds: 15)));

    testWidgets(
      'stale notification after schedule end should redirect safely (spec-first)',
      (tester) async {
        await setLargeTestViewport(tester);

        final staleEndedSchedule = buildSchedule(
          id: 's7',
          scheduleTime: now.subtract(const Duration(minutes: 1)),
          steps: const [
            PreparationStepWithTimeEntity(
              id: 'p1',
              preparationName: 'Prep',
              preparationTime: Duration(minutes: 10),
              nextPreparationId: null,
            ),
          ],
        );

        final router = GoRouter(
          initialLocation: '/alarmScreen',
          routes: [
            GoRoute(path: '/home', builder: (_, __) => const Text('HOME')),
            GoRoute(
                path: '/alarmScreen', builder: (_, __) => const AlarmScreen()),
            GoRoute(
                path: '/earlyLate',
                builder: (_, __) => const Text('EARLYLATE')),
          ],
        );

        final earlyBundle = createEarlyStartUseCaseBundle();
        final alarmBloc = ScheduleBloc.test(
          StubGetNearestUpcomingScheduleUseCase(
            () => Stream.value(staleEndedSchedule),
          ),
          navigationService,
          NoopSaveTimedPreparationUseCase(),
          StubGetTimedPreparationSnapshotUseCase({}),
          NoopClearTimedPreparationUseCase(),
          finishUseCase,
          markEarlyStartSessionUseCase: earlyBundle.markUseCase,
          getEarlyStartSessionUseCase: earlyBundle.getUseCase,
          clearEarlyStartSessionUseCase: earlyBundle.clearUseCase,
          nowProvider: () => now,
        );
        addTearDown(alarmBloc.close);

        await pumpWithRouter(tester, bloc: alarmBloc, router: router);
        await pumpUntilRouteText(tester, 'HOME');

        expect(find.text('HOME'), findsOneWidget);
        expect(finishUseCase.calls, isEmpty);
      },
    );
  });
}
