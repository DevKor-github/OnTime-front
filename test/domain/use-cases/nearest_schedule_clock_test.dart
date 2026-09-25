import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/use-cases/get_nearest_upcoming_schedule_use_case.dart';
import '../../helpers/fake_clock.dart';
import '../../helpers/nearest_query_fixture.dart';
import 'get_nearest_upcoming_schedule_use_case_test.dart'
    show QueryRepositoryFixture, QuerySessionFixture, queryKey, emptyQuery;

void main() {
  fakeClockTest(
    'candidate expiry triggers a new bounded query without a data write',
    (tester) async {
      var now = DateTime.utc(2030, 1, 1, 12);
      final target = now.add(const Duration(seconds: 10));
      final schedule = ScheduleWithPreparationEntity(
        id: 'first',
        place: const PlaceEntity(id: 'p', placeName: 'Office'),
        scheduleName: 'First',
        scheduleTime: target,
        timeZoneId: 'UTC',
        occurrenceOffsetSeconds: 0,
        moveTime: Duration.zero,
        isChanged: false,
        isStarted: false,
        scheduleSpareTime: Duration.zero,
        scheduleNote: '',
        preparation: const PreparationWithTimeEntity(preparationStepList: []),
      );
      final repository = QueryRepositoryFixture();
      repository.openHandler = (key) async => QuerySessionFixture(
        (_) async => now.isAfter(target)
            ? emptyQuery(key)
            : nearestQueryFixture(schedule, key),
      );
      final seen = <NearestScheduleQuery>[];
      final subscription = GetNearestUpcomingScheduleUseCase(
        repository,
        now: () => now,
      )(key: queryKey()).listen(seen.add);
      await tester.pump();
      expect(seen.last, isA<NearestQueryReady>());
      now = target.add(const Duration(microseconds: 1));
      await tester.pump(const Duration(seconds: 10, microseconds: 1));
      expect(seen.last, isA<NearestQueryEmpty>());
      expect(repository.keys, hasLength(2));
      await tester.complete(subscription.cancel());
      await tester.complete(repository.source.close());
    },
  );

  fakeClockTest(
    'pausing stops chunk work and resume retains the same epoch budget',
    (tester) async {
      final repository = QueryRepositoryFixture();
      late QuerySessionFixture session;
      repository.openHandler = (key) async => session = QuerySessionFixture(
        (_) async => session.calls == 4
            ? emptyQuery(key)
            : NearestQueryLimited(
                key: key,
                reason: NearestQueryLimitReason.interrupted,
                progress: NearestQueryProgress(
                  visitedCandidates: session.calls,
                  candidateBudget: 4,
                  provenSegments: 0,
                  totalSegments: 1,
                ),
                canContinue: true,
                canRetry: false,
              ),
      );
      late StreamSubscription<NearestScheduleQuery> subscription;
      final seen = <NearestScheduleQuery>[];
      subscription =
          GetNearestUpcomingScheduleUseCase(repository, chunkSize: 1)(
            key: queryKey(),
          ).listen((value) {
            seen.add(value);
            if (value is NearestQueryLoading &&
                value.progress.visitedCandidates == 1) {
              subscription.pause();
            }
          });
      await tester.pump();
      final pausedCalls = session.calls;
      await tester.pump(const Duration(minutes: 2));
      expect(session.calls, pausedCalls);
      subscription.resume();
      await tester.pump();
      expect(session.calls, 4);
      expect(repository.keys, hasLength(1));
      expect(seen.last, isA<NearestQueryEmpty>());
      await tester.complete(subscription.cancel());
      await tester.complete(repository.source.close());
    },
  );
}
