import '../../../../helpers/nearest_query_fixture.dart';
import 'dart:async';

import '../../../../helpers/fake_clock.dart';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/services/navigation_service.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/use-cases/get_nearest_upcoming_schedule_use_case.dart';
import 'package:on_time_front/domain/use-cases/schedule_preparation_session_use_case.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';

class _Nearest implements GetNearestUpcomingScheduleUseCase {
  final streams = <StreamController<ScheduleWithPreparationEntity?>>[];
  var cancellations = 0;
  Future<ScheduleWithPreparationEntity?> Function()? activeRead;
  @override
  Future<ScheduleWithPreparationEntity?> readActive() async =>
      activeRead == null ? null : await activeRead!();
  @override
  Stream<NearestScheduleQuery> call({required NearestQueryKey key}) {
    final source = StreamController<ScheduleWithPreparationEntity?>(
      onCancel: () {
        cancellations++;
      },
    );
    streams.add(source);
    source.add(null);
    return source.stream.map((value) => nearestQueryFixture(value, key));
  }
}

class _Session extends Fake implements SchedulePreparationSessionUseCase {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Nearest nearest;
  late ScheduleBloc bloc;
  late DateTime now;
  void lifecycleTest(
    String description,
    Future<void> Function(FakeClock) body,
  ) {
    fakeClockTest(description, (tester) async {
      nearest = _Nearest();
      now = DateTime(2030, 1, 1, 23, 59, 59);
      bloc = ScheduleBloc.test(
        nearest,
        NavigationService(),
        _Session(),
        nowProvider: () => now,
      );
      try {
        await body(tester);
      } finally {
        await tester.complete(bloc.close());
        for (final source in nearest.streams) {
          await tester.complete(source.close());
        }
      }
    });
  }

  lifecycleTest('device midnight replaces the query without a database event', (
    tester,
  ) async {
    bloc.add(const ScheduleSubscriptionRequested());
    await tester.pump();
    expect(nearest.streams, hasLength(1));
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(nearest.streams, hasLength(2));
    expect(nearest.cancellations, 1);
    expect(bloc.state.status, ScheduleStatus.notExists);
  });

  lifecycleTest('resume renews an existing query and paused phases do not', (
    tester,
  ) async {
    bloc.add(const ScheduleSubscriptionRequested());
    await tester.pump();
    bloc.observeLifecycleState(AppLifecycleState.paused);
    await tester.pump();
    expect(nearest.streams, hasLength(1));
    now = DateTime(2030, 1, 5, 8);
    bloc.observeLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(nearest.streams, hasLength(2));
    expect(nearest.cancellations, 1);
  });

  lifecycleTest(
    'foreground date discontinuity renews the query on the clock check',
    (tester) async {
      now = DateTime(2030, 1, 1, 10);
      bloc.add(const ScheduleSubscriptionRequested());
      await tester.pump();
      now = DateTime(2029, 12, 31, 10);
      await tester.pump(const Duration(minutes: 1));
      expect(nearest.streams, hasLength(2));
      await tester.pump(const Duration(minutes: 1));
      expect(nearest.streams, hasLength(2));
    },
  );

  lifecycleTest(
    'close cancels midnight, foreground clock and live query owners',
    (tester) async {
      bloc.add(const ScheduleSubscriptionRequested());
      await tester.pump();
      await tester.complete(bloc.close());
      now = DateTime(2030, 1, 4);
      await tester.pump(const Duration(days: 3));
      expect(nearest.streams, hasLength(1));
      expect(nearest.cancellations, 1);
    },
  );
  lifecycleTest(
    'same civil day clock jump refreshes and named-zone change refreshes once',
    (tester) async {
      now = DateTime(2030, 1, 1, 10);
      bloc.add(const ScheduleSubscriptionRequested());
      await tester.pump();
      now = now.add(const Duration(hours: 1));
      await tester.pump(const Duration(minutes: 1));
      expect(nearest.streams, hasLength(2));
      bloc.observeDeviceTimeZone('Asia/Seoul');
      bloc.observeDeviceTimeZone('Asia/Tokyo');
      await tester.pump();
      expect(nearest.streams, hasLength(3));
      bloc.observeDeviceTimeZone('Asia/Tokyo');
      await tester.pump();
      expect(nearest.streams, hasLength(3));
    },
  );

  lifecycleTest(
    'pause cancels query heartbeat across midnight and resume issues exactly one fresh query',
    (tester) async {
      bloc.add(const ScheduleSubscriptionRequested());
      await tester.pump();
      bloc.observeLifecycleState(AppLifecycleState.paused);
      await tester.pump();
      now = now.add(const Duration(days: 2));
      await tester.pump(const Duration(days: 2));
      expect(nearest.streams, hasLength(1));
      expect(nearest.cancellations, 1);
      bloc.observeLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      expect(nearest.streams, hasLength(2));
    },
  );
  for (final paused in [false, true]) {
    lifecycleTest(
      'late rejected initial active read cannot install a retired query after ${paused ? "pause" : "newer subscription"}',
      (tester) async {
        final pending = Completer<ScheduleWithPreparationEntity?>();
        var reads = 0;
        nearest.activeRead = () =>
            ++reads == 1 ? pending.future : Future.value(null);
        bloc.add(const ScheduleSubscriptionRequested());
        await tester.pump();
        expect(nearest.streams, isEmpty);
        if (paused) {
          bloc.observeLifecycleState(AppLifecycleState.paused);
        } else {
          bloc.add(const ScheduleSubscriptionRequested());
        }
        await tester.pump();
        expect(nearest.streams, hasLength(paused ? 0 : 1));
        pending.completeError(StateError('retired active read failed'));
        await tester.pump();
        expect(nearest.streams, hasLength(paused ? 0 : 1));
        bloc.observeLifecycleState(AppLifecycleState.resumed);
        await tester.pump();
        expect(nearest.streams, hasLength(paused ? 1 : 2));
        expect(
          nearest.cancellations,
          paused ? 0 : 1,
          reason:
              'The latest subscription handle remains owned and is cancelled exactly once.',
        );
      },
    );
  }
}
