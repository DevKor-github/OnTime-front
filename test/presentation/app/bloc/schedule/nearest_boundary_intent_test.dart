import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/services/navigation_service.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_with_time_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_start_rejected.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/use-cases/get_nearest_upcoming_schedule_use_case.dart';
import 'package:on_time_front/domain/use-cases/schedule_preparation_session_use_case.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';
import '../../../../helpers/fake_clock.dart';
import '../../../../helpers/nearest_query_fixture.dart';

class _Nearest implements GetNearestUpcomingScheduleUseCase {
  _Nearest(this.value);
  final ScheduleWithPreparationEntity value;
  final source = StreamController<NearestScheduleQuery>();
  NearestQueryKey? key;
  @override
  Stream<NearestScheduleQuery> call({required NearestQueryKey key}) {
    this.key = key;
    source.add(nearestQueryFixture(value, key));
    return source.stream;
  }

  @override
  Future<ScheduleWithPreparationEntity?> readActive() async => null;
}

class _Session extends Fake implements SchedulePreparationSessionUseCase {
  int entered = 0;
  int writes = 0;
  Completer<void>? pending;
  String? fingerprint;
  DateTime? committedAt;
  @override
  Future<DateTime> startSchedulePreparation(
    String id, {
    bool Function()? isCurrent,
    String? expectedFingerprint,
  }) async {
    entered++;
    fingerprint = expectedFingerprint;
    await pending?.future;
    if (!(isCurrent?.call() ?? true)) throw ScheduleStartRejected(id);
    writes++;

    return committedAt ?? DateTime.now().toUtc();
  }
}

class _Navigation extends NavigationService {
  final routes = <String>[];
  @override
  void push(String routeName, {Object? extra}) => routes.add(routeName);
}

ScheduleWithPreparationEntity _schedule(DateTime start) =>
    ScheduleWithPreparationEntity(
      id: 'next',
      place: const PlaceEntity(id: 'p', placeName: 'Office'),
      scheduleName: 'Next',
      scheduleTime: start.add(const Duration(minutes: 10)),
      timeZoneId: 'UTC',
      occurrenceOffsetSeconds: 0,
      moveTime: Duration.zero,
      isChanged: false,
      isStarted: false,
      scheduleSpareTime: Duration.zero,
      scheduleNote: '',
      preparation: const PreparationWithTimeEntity(
        preparationStepList: [
          PreparationStepWithTimeEntity(
            id: 'step',
            preparationName: 'Pack',
            preparationTime: Duration(minutes: 10),
            nextPreparationId: null,
          ),
        ],
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final delay in [
    const Duration(microseconds: -1),
    Duration.zero,
    const Duration(seconds: 2),
    const Duration(seconds: 2, microseconds: 1),
  ]) {
    fakeClockTest(
      'owned future boundary lateness $delay respects inclusive two-second policy',
      (tester) async {
        var wall = DateTime.utc(2030, 1, 1, 12);
        var mono = Duration.zero;
        final start = wall.add(const Duration(seconds: 10));
        final nearest = _Nearest(_schedule(start));
        final session = _Session();
        final navigation = _Navigation();
        final bloc = ScheduleBloc.test(
          nearest,
          navigation,
          session,
          nowProvider: () => wall,
          monotonicNow: () => mono,
        );
        try {
          bloc.add(const ScheduleSubscriptionRequested());
          await tester.pump();
          expect(bloc.state.freshNearest, isNotNull);
          session.committedAt = start.add(delay);
          wall = start.add(delay);
          mono = const Duration(seconds: 10) + delay;
          await tester.pump(const Duration(seconds: 10));
          final accepted =
              delay >= Duration.zero && delay <= const Duration(seconds: 2);
          expect(session.writes, accepted ? 1 : 0);
          expect(navigation.routes, accepted ? ['/scheduleStart'] : isEmpty);
          if (accepted) {
            expect(session.fingerprint, nearest.value.cacheFingerprint);
          }
        } finally {
          await tester.complete(bloc.close());
          await tester.complete(nearest.source.close());
        }
      },
    );
  }

  fakeClockTest(
    'query receipt after preparation start does not catch up or write',
    (tester) async {
      final wall = DateTime.utc(2030, 1, 1, 12);
      final nearest = _Nearest(
        _schedule(wall.subtract(const Duration(seconds: 1))),
      );
      final session = _Session();
      final navigation = _Navigation();
      final bloc = ScheduleBloc.test(
        nearest,
        navigation,
        session,
        nowProvider: () => wall,
      );
      bloc.add(const ScheduleSubscriptionRequested());
      await tester.pump();
      expect(bloc.state.status, ScheduleStatus.upcoming);
      expect(bloc.state.freshNearest, isNotNull);
      expect(session.entered, 0);
      expect(navigation.routes, isEmpty);
      await tester.complete(bloc.close());
      await tester.complete(nearest.source.close());
    },
  );

  fakeClockTest(
    'pause while owned start writer is pending discards without unhandled failure or navigation',
    (tester) async {
      var wall = DateTime.utc(2030, 1, 1, 12);
      var mono = Duration.zero;
      final nearest = _Nearest(
        _schedule(wall.add(const Duration(seconds: 10))),
      );
      final pending = Completer<void>();
      final session = _Session()..pending = pending;
      final navigation = _Navigation();
      final bloc = ScheduleBloc.test(
        nearest,
        navigation,
        session,
        nowProvider: () => wall,
        monotonicNow: () => mono,
      );
      bloc.add(const ScheduleSubscriptionRequested());
      await tester.pump();
      wall = wall.add(const Duration(seconds: 10));
      mono = const Duration(seconds: 10);
      await tester.pump(const Duration(seconds: 10));
      expect(session.entered, 1);
      bloc.observeLifecycleState(AppLifecycleState.paused);
      pending.complete();
      await tester.pump();
      expect(session.writes, 0);
      expect(navigation.routes, isEmpty);
      await tester.complete(bloc.close());
      await tester.complete(nearest.source.close());
    },
  );
}
