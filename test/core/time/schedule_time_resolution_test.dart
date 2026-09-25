import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/time/civil_time_resolver.dart';
import 'package:on_time_front/core/time/schedule_time_resolution.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';

ScheduleEntity schedule({
  required DateTime civil,
  String zone = 'Asia/Seoul',
  int? offset,
}) => ScheduleEntity(
  id: 'appointment',
  place: const PlaceEntity(id: 'place', placeName: 'Office'),
  scheduleName: 'Appointment',
  scheduleTime: civil,
  timeZoneId: zone,
  occurrenceOffsetSeconds: offset,
  moveTime: Duration.zero,
  isChanged: false,
  isStarted: false,
  scheduleSpareTime: Duration.zero,
  scheduleNote: '',
);

void main() {
  // A10 chooses an instant only when the stored facts/current rules justify it.
  // The result is time interpretation, never restore/apply/start permission.
  group('actual named-zone resolution', () {
    test('future unique null offset resolves through the named zone', () {
      final result = ScheduleTimeResolver.resolve(
        schedule(civil: DateTime.utc(2026, 9, 25, 9, 0, 1, 123, 456)),
        nowUtc: DateTime.utc(2026, 9, 1),
      );

      expect(result.status, ScheduleTimeResolutionStatus.resolved);
      expect(result.instantUtc, DateTime.utc(2026, 9, 25, 0, 0, 1, 123, 456));
      expect(result.isHistorical, isFalse);
      expect(result.occurrences.map((o) => o.offsetSeconds), [32400]);
    });

    test('unknown zone cannot silently become UTC', () {
      final result = ScheduleTimeResolver.resolve(
        schedule(
          civil: DateTime.utc(2026, 9, 25, 9),
          zone: 'Not/A_Real_Zone',
          offset: 0,
        ),
        nowUtc: DateTime.utc(2026, 9, 1),
      );

      expect(result.status, ScheduleTimeResolutionStatus.unknownZone);
      expect(result.instantUtc, isNull);
      expect(result.proposedInstantUtc, isNull);
    });

    test('explicit UTC is a valid choice', () {
      final result = ScheduleTimeResolver.resolve(
        schedule(civil: DateTime.utc(2026, 9, 25, 9), zone: 'UTC', offset: 0),
        nowUtc: DateTime.utc(2026, 9, 1),
      );

      expect(result.status, ScheduleTimeResolutionStatus.resolved);
      expect(result.instantUtc, DateTime.utc(2026, 9, 25, 9));
    });

    test('overlap without a selection exposes both actual choices', () {
      final result = ScheduleTimeResolver.resolve(
        schedule(
          civil: DateTime.utc(2026, 11, 1, 1, 30),
          zone: 'America/New_York',
        ),
        nowUtc: DateTime.utc(2026, 10, 1),
      );

      expect(result.status, ScheduleTimeResolutionStatus.ambiguous);
      expect(result.instantUtc, isNull);
      expect(result.proposedInstantUtc, isNull);
      expect(result.occurrences.map((o) => o.instantUtc), [
        DateTime.utc(2026, 11, 1, 5, 30),
        DateTime.utc(2026, 11, 1, 6, 30),
      ]);
    });

    test('each explicitly selected overlap occurrence retains its instant', () {
      for (final choice in [
        (offset: -14400, instant: DateTime.utc(2026, 11, 1, 5, 30)),
        (offset: -18000, instant: DateTime.utc(2026, 11, 1, 6, 30)),
      ]) {
        final result = ScheduleTimeResolver.resolve(
          schedule(
            civil: DateTime.utc(2026, 11, 1, 1, 30),
            zone: 'America/New_York',
            offset: choice.offset,
          ),
          nowUtc: DateTime.utc(2026, 10, 1),
        );
        expect(result.status, ScheduleTimeResolutionStatus.resolved);
        expect(result.instantUtc, choice.instant);
      }
    });

    test(
      'stale overlap selection does not choose either replacement silently',
      () {
        final result = ScheduleTimeResolver.resolve(
          schedule(
            civil: DateTime.utc(2026, 11, 1, 1, 30),
            zone: 'America/New_York',
            offset: -21600,
          ),
          nowUtc: DateTime.utc(2026, 10, 1),
        );

        expect(result.status, ScheduleTimeResolutionStatus.changed);
        expect(result.instantUtc, isNull);
        expect(result.proposedInstantUtc, isNull);
        expect(result.occurrences.map((o) => o.offsetSeconds), [
          -14400,
          -18000,
        ]);
      },
    );

    test(
      'future gap is not normalized even when an old offset was supplied',
      () {
        for (final offset in <int?>[null, -18000]) {
          final result = ScheduleTimeResolver.resolve(
            schedule(
              civil: DateTime.utc(2026, 3, 8, 2, 30),
              zone: 'America/New_York',
              offset: offset,
            ),
            nowUtc: DateTime.utc(2026, 3, 1),
          );
          expect(result.status, ScheduleTimeResolutionStatus.nonexistent);
          expect(result.instantUtc, isNull);
          expect(result.proposedInstantUtc, isNull);
          expect(result.occurrences, isEmpty);
        }
      },
    );

    test('45-minute and 30-minute-zone offsets are not rounded to hours', () {
      final kathmandu = ScheduleTimeResolver.resolve(
        schedule(civil: DateTime.utc(2026, 9, 25, 9), zone: 'Asia/Kathmandu'),
        nowUtc: DateTime.utc(2026, 9, 1),
      );
      final lordHowe = ScheduleTimeResolver.resolve(
        schedule(
          civil: DateTime.utc(2026, 7, 1, 9),
          zone: 'Australia/Lord_Howe',
        ),
        nowUtc: DateTime.utc(2026, 6, 1),
      );

      expect(kathmandu.status, ScheduleTimeResolutionStatus.resolved);
      expect(kathmandu.instantUtc, DateTime.utc(2026, 9, 25, 3, 15));
      expect(lordHowe.status, ScheduleTimeResolutionStatus.resolved);
      expect(lordHowe.instantUtc, DateTime.utc(2026, 6, 30, 22, 30));
    });
  });

  group('stored history does not acquire invented certainty', () {
    test('past explicit offset survives disagreement with current rules', () {
      // Synthetic stored +10:00; this does not claim Seoul used it historically.
      final result = ScheduleTimeResolver.resolve(
        schedule(civil: DateTime.utc(2026, 1, 1, 9), offset: 36000),
        nowUtc: DateTime.utc(2026, 1, 3),
      );

      expect(result.status, ScheduleTimeResolutionStatus.resolved);
      expect(result.instantUtc, DateTime.utc(2025, 12, 31, 23));
      expect(result.isHistorical, isTrue);
      expect(result.proposedInstantUtc, isNull);
    });

    test(
      'old null offset stays uncertain even for a currently unique zone',
      () {
        final result = ScheduleTimeResolver.resolve(
          schedule(civil: DateTime.utc(2026, 1, 1, 9)),
          nowUtc: DateTime.utc(2026, 1, 3),
        );

        expect(result.status, ScheduleTimeResolutionStatus.historicalUncertain);
        expect(result.isHistorical, isTrue);
        expect(result.instantUtc, isNull);
        expect(result.proposedInstantUtc, isNull);
      },
    );

    test(
      'all known candidates in the past do not fabricate a historical offset',
      () {
        final result = ScheduleTimeResolver.resolve(
          schedule(civil: DateTime.utc(2026, 9, 25, 9)),
          nowUtc: DateTime.utc(2026, 9, 25, 1),
        );

        expect(result.status, ScheduleTimeResolutionStatus.historicalUncertain);
        expect(result.instantUtc, isNull);
        expect(result.proposedInstantUtc, isNull);
        expect(result.isHistorical, isTrue);
      },
    );

    test('an old gap with no stored offset remains uncertain history', () {
      final result = ScheduleTimeResolver.resolve(
        schedule(
          civil: DateTime.utc(2026, 3, 8, 2, 30),
          zone: 'America/New_York',
        ),
        nowUtc: DateTime.utc(2026, 3, 10),
      );

      expect(result.status, ScheduleTimeResolutionStatus.historicalUncertain);
      expect(result.instantUtc, isNull);
      expect(result.proposedInstantUtc, isNull);
    });

    test('overlap straddling now still requires a choice', () {
      final result = ScheduleTimeResolver.resolve(
        schedule(
          civil: DateTime.utc(2026, 11, 1, 1, 30),
          zone: 'America/New_York',
        ),
        nowUtc: DateTime.utc(2026, 11, 1, 6),
      );

      expect(result.status, ScheduleTimeResolutionStatus.ambiguous);
      expect(result.instantUtc, isNull);
      expect(result.isHistorical, isFalse);
      expect(result.occurrences, hasLength(2));
    });

    test('unique candidate exactly now is not silently relabeled past', () {
      final instant = DateTime.utc(2026, 9, 25);
      final result = ScheduleTimeResolver.resolve(
        schedule(civil: DateTime.utc(2026, 9, 25, 9)),
        nowUtc: instant,
      );

      expect(result.status, ScheduleTimeResolutionStatus.resolved);
      expect(result.instantUtc, instant);
      expect(result.isHistorical, isFalse);
    });

    test(
      'started frozen and completed facts protect explicit future history',
      () {
        final base = schedule(
          civil: DateTime.utc(2026, 9, 25, 9),
          offset: 36000,
        );
        final began = DateTime.utc(2026, 8, 31);
        for (final protected in [
          base.copyWith(
            isStarted: true,
            preparationFrozen: true,
            startedAt: began,
          ),
          base.copyWith(preparationFrozen: true, startedAt: began),
          base.copyWith(
            doneStatus: ScheduleDoneStatus.normalEnd,
            startedAt: began,
            finishedAt: DateTime.utc(2026, 8, 31, 1),
          ),
        ]) {
          final result = ScheduleTimeResolver.resolve(
            protected,
            nowUtc: DateTime.utc(2026, 9, 1),
          );
          expect(result.status, ScheduleTimeResolutionStatus.resolved);
          expect(result.instantUtc, DateTime.utc(2026, 9, 24, 23));
          expect(result.isHistorical, isTrue);
          expect(result.proposedInstantUtc, isNull);
        }
      },
    );
  });

  group('rule change and invalid representations', () {
    test('new unique rules propose a replacement without activating it', () {
      final value = schedule(
        civil: DateTime.utc(2026, 9, 25, 12),
        zone: 'UTC',
        offset: 0,
      );
      final original = ScheduleTimeResolver.resolve(
        value,
        nowUtc: DateTime.utc(2026, 9, 1),
        lookup: (_, _) => [
          CivilTimeOccurrence(
            offsetSeconds: 0,
            instantUtc: DateTime.utc(2026, 9, 25, 12),
          ),
        ],
      );
      final changed = ScheduleTimeResolver.resolve(
        value,
        nowUtc: DateTime.utc(2026, 9, 1),
        lookup: (_, _) => [
          CivilTimeOccurrence(
            offsetSeconds: 3600,
            instantUtc: DateTime.utc(2026, 9, 25, 11),
          ),
        ],
      );

      expect(original.status, ScheduleTimeResolutionStatus.resolved);
      expect(original.instantUtc, DateTime.utc(2026, 9, 25, 12));
      expect(changed.status, ScheduleTimeResolutionStatus.changed);
      expect(changed.instantUtc, isNull);
      expect(changed.proposedInstantUtc, DateTime.utc(2026, 9, 25, 11));
      expect(changed.isHistorical, isFalse);
    });

    test(
      'invalid offset integers return invalid rather than a wrapped instant',
      () {
        for (final offset in [
          86401,
          -86401,
          9223372036854775807,
          -9223372036854775808,
        ]) {
          final result = ScheduleTimeResolver.resolve(
            schedule(civil: DateTime.utc(2026, 9, 25, 9), offset: offset),
            nowUtc: DateTime.utc(2026, 9, 1),
          );
          expect(
            result.status,
            ScheduleTimeResolutionStatus.invalid,
            reason: '$offset',
          );
          expect(result.instantUtc, isNull);
          expect(result.proposedInstantUtc, isNull);
        }
      },
    );

    test('civil and selected instant both obey persisted year bounds', () {
      for (final value in [
        schedule(civil: DateTime.utc(0), zone: 'UTC', offset: 0),
        schedule(civil: DateTime.utc(10000), zone: 'UTC', offset: 0),
        schedule(civil: DateTime.utc(1), zone: 'UTC', offset: 1),
        schedule(
          civil: DateTime.utc(9999, 12, 31, 23, 59, 59, 999, 999),
          zone: 'UTC',
          offset: -1,
        ),
      ]) {
        final result = ScheduleTimeResolver.resolve(
          value,
          nowUtc: DateTime.utc(2026, 9, 1),
        );
        expect(result.status, ScheduleTimeResolutionStatus.invalid);
        expect(result.instantUtc, isNull);
        expect(result.proposedInstantUtc, isNull);
      }
    });
  });
}
