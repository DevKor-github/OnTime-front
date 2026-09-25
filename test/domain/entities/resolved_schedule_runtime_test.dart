import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/time/civil_time_resolver.dart';
import 'package:on_time_front/core/time/schedule_time_resolution.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';

void main() {
  final raw = ScheduleEntity(
    id: 'raw',
    place: const PlaceEntity(id: 'place', placeName: 'Place'),
    scheduleName: 'UTC',
    scheduleTime: DateTime.utc(2010, 1, 1, 12),
    timeZoneId: 'UTC',
    moveTime: Duration.zero,
    isChanged: false,
    isStarted: false,
    scheduleSpareTime: Duration.zero,
    scheduleNote: '',
  );
  const preparation = PreparationWithTimeEntity(preparationStepList: []);

  test(
    'a fixed pass remains deterministic even when actual wall clock is after its occurrence',
    () {
      final runtime =
          ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
            raw,
            preparation,
            timeResolution: ScheduleTimeResolver.resolve(
              raw,
              nowUtc: DateTime.utc(2009),
            ),
          );
      expect(runtime.occurrenceOffsetSeconds, isNull);
      expect(runtime.occurrenceInstantUtc, DateTime.utc(2010, 1, 1, 12));
      expect(runtime.preparationStartTime, DateTime.utc(2010, 1, 1, 12));
      final identity = runtime.cacheFingerprint;
      expect(runtime.cacheFingerprint, identity);
      final confirmed =
          ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
            raw.copyWith(
              occurrenceOffsetSeconds: 0,
              isStarted: true,
              preparationFrozen: true,
              startedAt: DateTime.utc(2010, 1, 1, 11),
            ),
            preparation,
            timeResolution: ScheduleTimeResolver.resolve(
              raw.copyWith(
                occurrenceOffsetSeconds: 0,
                isStarted: true,
                preparationFrozen: true,
                startedAt: DateTime.utc(2010, 1, 1, 11),
              ),
              nowUtc: DateTime.utc(2011),
            ),
          );
      expect(confirmed.cacheFingerprint, identity);
      expect(raw.occurrenceOffsetSeconds, isNull);
    },
  );

  test(
    'another pass after the deadline is unresolved and cannot reuse runtime identity as authority',
    () {
      final before =
          ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
            raw,
            preparation,
            timeResolution: ScheduleTimeResolver.resolve(
              raw,
              nowUtc: DateTime.utc(2009),
            ),
          );
      final after =
          ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
            raw,
            preparation,
            timeResolution: ScheduleTimeResolver.resolve(
              raw,
              nowUtc: DateTime.utc(2011),
            ),
          );
      expect(
        after.timeResolution!.status,
        ScheduleTimeResolutionStatus.historicalUncertain,
      );
      expect(after, isNot(before));
      expect(
        () => after.cacheFingerprint,
        throwsA(isA<ScheduleTimeUnresolved>()),
      );
      expect(before.occurrenceInstantUtc, DateTime.utc(2010, 1, 1, 12));
    },
  );

  test(
    'same raw values with changed occurrence produce distinct runtime state and fingerprint',
    () {
      ScheduleWithPreparationEntity interpreted(int offset) =>
          ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
            raw,
            preparation,
            timeResolution: ScheduleTimeResolver.resolve(
              raw,
              nowUtc: DateTime.utc(2009),
              lookup: (_, _) => [
                CivilTimeOccurrence(
                  offsetSeconds: offset,
                  instantUtc: DateTime.utc(
                    2010,
                    1,
                    1,
                    12,
                  ).subtract(Duration(seconds: offset)),
                ),
              ],
            ),
          );
      final first = interpreted(0);
      final same = interpreted(0);
      final changed = interpreted(3600);
      expect(first, same);
      expect(changed, isNot(first));
      expect(changed.cacheFingerprint, isNot(first.cacheFingerprint));
      expect(first.occurrenceOffsetSeconds, isNull);
      expect(changed.occurrenceOffsetSeconds, isNull);
    },
  );
}
