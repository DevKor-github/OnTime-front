import 'package:on_time_front/domain/entities/schedule_entity.dart';
import '../../../../helpers/nearest_query_fixture.dart';
import 'dart:async';

import '../../../../helpers/fake_clock.dart';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/services/navigation_service.dart';
import 'package:on_time_front/domain/entities/early_start_session_entity.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_action_event_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_with_time_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/use-cases/get_nearest_upcoming_schedule_use_case.dart';
import 'package:on_time_front/domain/use-cases/schedule_preparation_session_use_case.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';

class _Nearest implements GetNearestUpcomingScheduleUseCase {
  _Nearest(this.value);
  ScheduleWithPreparationEntity? value;
  bool initialActiveRead = false;
  bool terminalLimited = false;
  @override
  Future<ScheduleWithPreparationEntity?> readActive() async =>
      (initialActiveRead || sources.isNotEmpty) &&
          value != null &&
          value!.isStarted &&
          value!.startedAt != null &&
          value!.preparationFrozen &&
          value!.doneStatus == ScheduleDoneStatus.notEnded
      ? value
      : null;
  final sources = <StreamController<ScheduleWithPreparationEntity?>>[];
  @override
  Stream<NearestScheduleQuery> call({required NearestQueryKey key}) {
    final source = StreamController<ScheduleWithPreparationEntity?>();
    sources.add(source);
    source.add(value);
    return source.stream.map((received) {
      value = received;
      if (terminalLimited) {
        return NearestQueryLimited(
          key: key,
          reason: NearestQueryLimitReason.searchBudgetExhausted,
          progress: const NearestQueryProgress(
            visitedCandidates: 200000,
            candidateBudget: 200000,
            provenSegments: 0,
            totalSegments: 1,
          ),
          canContinue: false,
          canRetry: false,
        );
      }
      return nearestQueryFixture(received, key);
    });
  }
}

class _Navigation extends NavigationService {
  final routes = <String>[];
  @override
  void push(String routeName, {Object? extra}) => routes.add(routeName);
}

class _Session extends Fake implements SchedulePreparationSessionUseCase {
  bool hasValidatedRuntime = true;
  Duration restoredStartDifference = Duration.zero;
  Completer<void>? pendingRestore;
  final starts = <String>[];
  final clears = <String>[];
  @override
  Future<EarlyStartSessionEntity?> getEarlyStartSession(String id) async =>
      null;
  @override
  Future<DateTime> startSchedulePreparation(
    String id, {
    bool Function()? isCurrent,
    String? expectedFingerprint,
  }) async {
    starts.add(id);

    return DateTime.now().toUtc();
  }

  @override
  Future<void> clearPersistedState(String id) async {
    clears.add(id);
  }

  @override
  Future<ScheduleWithPreparationEntity> restoreTimedPreparationIfValid(
    ScheduleWithPreparationEntity schedule, {
    required DateTime now,
    RestoredSessionCallback? onRestoredSession,
    void Function()? onInvalidated,
  }) async {
    final pending = pendingRestore;
    pendingRestore = null;
    if (pending != null) await pending.future;
    if (hasValidatedRuntime) {
      onRestoredSession?.call(
        startedAt: schedule.startedAt?.add(restoredStartDifference),
        actionEvents: const [],
      );
    }
    return schedule;
  }

  @override
  Future<void> saveTimedPreparationSnapshot(
    ScheduleWithPreparationEntity schedule, {
    DateTime? savedAt,
    DateTime? startedAt,
    List<PreparationActionEventEntity> actionEvents = const [],
    bool persist = true,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2030, 1, 2, 0, 5);
  ScheduleWithPreparationEntity active() => ScheduleWithPreparationEntity(
    id: 'active',
    place: const PlaceEntity(id: 'place', placeName: 'Office'),
    scheduleName: 'Yesterday appointment',
    scheduleTime: DateTime.utc(2030, 1, 1, 23, 55),
    timeZoneId: 'UTC',
    occurrenceOffsetSeconds: 0,
    moveTime: Duration.zero,
    isChanged: false,
    isStarted: true,
    startedAt: DateTime.utc(2030, 1, 1, 23, 35),
    preparationFrozen: true,
    scheduleSpareTime: Duration.zero,
    scheduleNote: '',
    preparation: const PreparationWithTimeEntity(
      preparationStepList: [
        PreparationStepWithTimeEntity(
          id: 'prepare',
          preparationName: 'Prepare',
          preparationTime: Duration(minutes: 20),
          nextPreparationId: null,
          elapsedTime: Duration(minutes: 20),
          isDone: true,
        ),
      ],
    ),
  );

  for (final (hasRuntime, difference) in [
    (true, Duration.zero),
    (false, Duration.zero),
    (true, const Duration(minutes: 1)),
  ]) {
    final validated = hasRuntime && difference == Duration.zero;
    fakeClockTest(
      'late durable run runtime=$hasRuntime start difference=$difference is not newly started on resume',
      (tester) async {
        final nearest = _Nearest(active());
        final session = _Session()
          ..hasValidatedRuntime = hasRuntime
          ..restoredStartDifference = difference;
        final navigation = _Navigation();
        final bloc = ScheduleBloc.test(
          nearest,
          navigation,
          session,
          nowProvider: () => now,
        );
        try {
          bloc.add(const ScheduleSubscriptionRequested());
          await tester.pump();
          expect(bloc.state.schedule?.id, 'active');
          expect(
            bloc.state.status,
            validated ? ScheduleStatus.started : ScheduleStatus.upcoming,
          );
          expect(bloc.state.schedule?.requiresStartConfirmation, !validated);
          expect(bloc.state.isResumedPreparation, validated);
          expect(session.starts, isEmpty);
          expect(navigation.routes, isEmpty);
          bloc.observeLifecycleState(AppLifecycleState.resumed);
          await tester.pump();
          expect(nearest.sources, hasLength(2));
          expect(bloc.state.schedule?.id, 'active');
          expect(session.starts, isEmpty);
          expect(navigation.routes, isEmpty);
        } finally {
          await tester.complete(bloc.close());
          for (final source in nearest.sources) {
            await tester.complete(source.close());
          }
        }
      },
    );
  }

  fakeClockTest(
    'an authoritative missing active read releases runtime references without durable cleanup',
    (tester) async {
      final nearest = _Nearest(active());
      final session = _Session();
      final bloc = ScheduleBloc.test(
        nearest,
        _Navigation(),
        session,
        nowProvider: () => now,
      );
      try {
        bloc.add(const ScheduleSubscriptionRequested());
        await tester.pump();
        expect(bloc.state.schedule?.id, 'active');
        nearest.value = null;
        nearest.sources.last.add(null);
        await tester.pump();
        expect(bloc.state.status, ScheduleStatus.notExists);
        expect(session.clears, isEmpty);
        expect(session.starts, isEmpty);
      } finally {
        await tester.complete(bloc.close());
        for (final source in nearest.sources) {
          await tester.complete(source.close());
        }
      }
    },
  );
  fakeClockTest(
    'a retired query cannot restore its pending active run over a replacement missing candidate',
    (tester) async {
      final nearest = _Nearest(active());
      final pending = Completer<void>();
      final session = _Session()..pendingRestore = pending;
      final navigation = _Navigation();
      final bloc = ScheduleBloc.test(
        nearest,
        navigation,
        session,
        nowProvider: () => now,
      );
      try {
        bloc.add(const ScheduleSubscriptionRequested());
        await tester.pump();
        nearest.value = null;
        bloc.observeLifecycleState(AppLifecycleState.resumed);
        await tester.pump();
        expect(nearest.sources, hasLength(2));
        expect(bloc.state.status, ScheduleStatus.notExists);
        pending.complete();
        await tester.pump();
        expect(bloc.state.status, ScheduleStatus.notExists);
        expect(session.starts, isEmpty);
        expect(navigation.routes, isEmpty);
      } finally {
        if (!pending.isCompleted) pending.complete();
        await tester.complete(bloc.close());
        for (final source in nearest.sources) {
          await tester.complete(source.close());
        }
      }
    },
  );
  fakeClockTest(
    'read errors retain the validated active run until a real missing result arrives',
    (tester) async {
      final nearest = _Nearest(active());
      final session = _Session();
      final navigation = _Navigation();
      final bloc = ScheduleBloc.test(
        nearest,
        navigation,
        session,
        nowProvider: () => now,
      );
      try {
        bloc.add(const ScheduleSubscriptionRequested());
        await tester.pump();
        final original = bloc.state.schedule;
        nearest.sources.last.addError(StateError('temporary read failure'));
        await tester.pump();
        expect(bloc.state.hasUpcomingReadFailure, isTrue);
        expect(bloc.state.schedule, original);
        expect(bloc.state.status, ScheduleStatus.started);
        expect(session.clears, isEmpty);
        expect(session.starts, isEmpty);
        expect(navigation.routes, isEmpty);
        nearest.sources.last.add(null);
        await tester.pump();
        expect(bloc.state.hasUpcomingReadFailure, isFalse);
        expect(bloc.state.status, ScheduleStatus.notExists);
        expect(session.clears, isEmpty);
        expect(session.starts, isEmpty);
      } finally {
        await tester.complete(bloc.close());
        for (final source in nearest.sources) {
          await tester.complete(source.close());
        }
      }
    },
  );

  fakeClockTest(
    'a failed future projection cannot automatically or explicitly start before a successful retry',
    (tester) async {
      final future = ScheduleWithPreparationEntity(
        id: 'future',
        place: const PlaceEntity(id: 'place', placeName: 'Office'),
        scheduleName: 'Future appointment',
        scheduleTime: now.add(const Duration(minutes: 21)),
        timeZoneId: 'UTC',
        occurrenceOffsetSeconds: 0,
        isChanged: false,
        isStarted: false,
        moveTime: Duration.zero,
        scheduleSpareTime: Duration.zero,
        scheduleNote: '',
        preparation: const PreparationWithTimeEntity(
          preparationStepList: [
            PreparationStepWithTimeEntity(
              id: 'prepare',
              preparationName: 'Prepare',
              preparationTime: Duration(minutes: 20),
              nextPreparationId: null,
            ),
          ],
        ),
      );
      final nearest = _Nearest(future);
      final session = _Session()..hasValidatedRuntime = false;
      final navigation = _Navigation();
      final bloc = ScheduleBloc.test(
        nearest,
        navigation,
        session,
        nowProvider: () => now,
      );
      try {
        bloc.add(const ScheduleSubscriptionRequested());
        await tester.pump();
        expect(bloc.state.status, ScheduleStatus.upcoming);
        final initialClears = List<String>.of(session.clears);
        nearest.sources.last.addError(StateError('read unavailable'));
        await tester.pump();
        expect(bloc.state.hasUpcomingReadFailure, isTrue);
        bloc.add(const ScheduleStarted());
        final receipt = bloc.requestPreparationStart(isCurrent: () => true);
        await tester.pump(const Duration(minutes: 2));
        await tester.complete(receipt.then((value) => expect(value, isNull)));
        expect(session.starts, isEmpty);
        expect(navigation.routes, isEmpty);
        expect(session.clears, initialClears);
        bloc.add(const ScheduleSubscriptionRequested());
        await tester.pump();
        expect(bloc.state.hasUpcomingReadFailure, isFalse);
        expect(bloc.state.schedule?.id, 'future');
        expect(nearest.sources, hasLength(2));
      } finally {
        await tester.complete(bloc.close());
        for (final source in nearest.sources) {
          await tester.complete(source.close());
        }
      }
    },
  );

  fakeClockTest('a pending restore cannot erase a newer read failure', (
    tester,
  ) async {
    final nearest = _Nearest(active());
    final pending = Completer<void>();
    final session = _Session()..pendingRestore = pending;
    final navigation = _Navigation();
    final bloc = ScheduleBloc.test(
      nearest,
      navigation,
      session,
      nowProvider: () => now,
    );
    try {
      bloc.add(const ScheduleSubscriptionRequested());
      await tester.pump();
      nearest.sources.last.addError(StateError('newer source failure'));
      await tester.pump();
      expect(bloc.state.hasUpcomingReadFailure, isTrue);
      pending.complete();
      await tester.pump();
      expect(bloc.state.hasUpcomingReadFailure, isTrue);
      expect(bloc.state.status, ScheduleStatus.initial);
      expect(session.starts, isEmpty);
      expect(navigation.routes, isEmpty);
      expect(session.clears, isEmpty);
    } finally {
      if (!pending.isCompleted) pending.complete();
      await tester.complete(bloc.close());
      for (final source in nearest.sources) {
        await tester.complete(source.close());
      }
    }
  });
  fakeClockTest(
    'initial durable active recovery survives terminal nearest budget limit',
    (tester) async {
      final nearest = _Nearest(active())
        ..initialActiveRead = true
        ..terminalLimited = true;
      final session = _Session();
      final navigation = _Navigation();
      final bloc = ScheduleBloc.test(
        nearest,
        navigation,
        session,
        nowProvider: () => now,
      );
      try {
        bloc.add(const ScheduleSubscriptionRequested());
        await tester.pump();
        expect(bloc.state.nearestQuery, isA<NearestQueryLimited>());
        expect(bloc.state.schedule?.id, 'active');
        expect(bloc.state.hasOwnedPreparationSurface, isTrue);
        expect(bloc.state.status, ScheduleStatus.started);
        expect(session.starts, isEmpty);
        expect(session.clears, isEmpty);
        expect(navigation.routes, isEmpty);
      } finally {
        await tester.complete(bloc.close());
        for (final source in nearest.sources) {
          await tester.complete(source.close());
        }
      }
    },
  );
}
