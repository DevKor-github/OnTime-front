import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/time/civil_time_resolver.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  test('normal civil time resolves to one absolute occurrence', () {
    final occurrences = CivilTimeResolver.resolve(
      DateTime.utc(2026, 2, 1, 12, 30),
      'America/New_York',
    );

    expect(occurrences, hasLength(1));
    expect(occurrences.single.offsetSeconds, -5 * 60 * 60);
    expect(occurrences.single.instantUtc, DateTime.utc(2026, 2, 1, 17, 30));
  });

  test('spring-forward gap has no valid occurrence', () {
    expect(
      CivilTimeResolver.resolve(
        DateTime.utc(2026, 3, 8, 2, 30),
        'America/New_York',
      ),
      isEmpty,
    );
  });

  test('fall-back overlap exposes first and second occurrence', () {
    final occurrences = CivilTimeResolver.resolve(
      DateTime.utc(2026, 11, 1, 1, 30),
      'America/New_York',
    );

    expect(occurrences.map((value) => value.offsetSeconds), [
      -4 * 60 * 60,
      -5 * 60 * 60,
    ]);
    expect(occurrences.map((value) => value.instantUtc), [
      DateTime.utc(2026, 11, 1, 5, 30),
      DateTime.utc(2026, 11, 1, 6, 30),
    ]);
  });

  test(
    'unknown zone fails explicitly in both resolution and display conversion',
    () {
      final input = DateTime.utc(2026, 9, 25, 9);
      expect(
        () => CivilTimeResolver.resolve(input, 'Not/A_Real_Zone'),
        throwsA(isA<tz.LocationNotFoundException>()),
      );
      expect(
        () => CivilTimeResolver.civilTimeAt(input, 'Not/A_Real_Zone'),
        throwsA(isA<tz.LocationNotFoundException>()),
      );
      expect(CivilTimeResolver.resolve(input, 'UTC').single.instantUtc, input);
    },
  );

  test('both overlap occurrences retain seconds and microseconds', () {
    final choices = CivilTimeResolver.resolve(
      DateTime.utc(2026, 11, 1, 1, 30, 59, 123, 456),
      'America/New_York',
    );
    expect(choices.map((value) => value.instantUtc), [
      DateTime.utc(2026, 11, 1, 5, 30, 59, 123, 456),
      DateTime.utc(2026, 11, 1, 6, 30, 59, 123, 456),
    ]);
    expect(choices.map((value) => value.offsetSeconds), [-14400, -18000]);
  });

  test('named-zone display conversion includes the different civil date', () {
    final value = CivilTimeResolver.civilTimeAt(
      DateTime.utc(2026, 9, 25, 0, 0, 59, 123, 456),
      'America/New_York',
    );
    expect(
      [
        value.year,
        value.month,
        value.day,
        value.hour,
        value.minute,
        value.second,
        value.millisecond,
        value.microsecond,
      ],
      [2026, 9, 24, 20, 0, 59, 123, 456],
    );
    expect(value.timeZoneOffset, const Duration(hours: -4));
    expect(value.toUtc(), DateTime.utc(2026, 9, 25, 0, 0, 59, 123, 456));
  });

  group('gap proposals are distinct civil drafts', () {
    test(
      'New York gap proposes the first valid minute without normalizing input',
      () {
        final selected = DateTime.utc(2026, 3, 8, 2, 30, 59, 123, 456);
        expect(
          CivilTimeResolver.resolve(selected, 'America/New_York'),
          isEmpty,
        );
        final proposed = CivilTimeResolver.nextValidCivilTime(
          selected,
          'America/New_York',
        );
        expect(proposed, DateTime.utc(2026, 3, 8, 3));
        expect(
          proposed!.isUtc,
          isTrue,
          reason: 'The proposal is a civil carrier, not the occurrence instant',
        );
        expect(
          CivilTimeResolver.resolve(
            proposed,
            'America/New_York',
          ).single.instantUtc,
          DateTime.utc(2026, 3, 8, 7),
        );
        expect(selected, DateTime.utc(2026, 3, 8, 2, 30, 59, 123, 456));
        expect(
          CivilTimeResolver.resolve(selected, 'America/New_York'),
          isEmpty,
        );
      },
    );

    test(
      'Apia skipped date proposes next calendar date without inventing December 30',
      () {
        final selected = DateTime.utc(2011, 12, 30, 12, 34, 56, 789, 123);
        expect(CivilTimeResolver.resolve(selected, 'Pacific/Apia'), isEmpty);
        final proposed = CivilTimeResolver.nextValidCivilTime(
          selected,
          'Pacific/Apia',
        );
        expect(proposed, DateTime.utc(2011, 12, 31));
        expect(
          CivilTimeResolver.resolve(
            proposed!,
            'Pacific/Apia',
          ).single.instantUtc,
          DateTime.utc(2011, 12, 30, 10),
        );
        expect(selected, DateTime.utc(2011, 12, 30, 12, 34, 56, 789, 123));
      },
    );

    test('unknown zone and year overflow provide no invented proposal', () {
      expect(
        CivilTimeResolver.nextValidCivilTime(
          DateTime.utc(2026, 9, 25, 9),
          'Not/A_Real_Zone',
        ),
        isNull,
      );
      expect(
        CivilTimeResolver.nextValidCivilTime(
          DateTime.utc(9999, 12, 31, 23, 59, 59, 999, 999),
          'UTC',
        ),
        isNull,
      );
    });
  });

  group('offset labels preserve the stored precision', () {
    test(
      'whole, fractional-hour and second offsets have unambiguous signs',
      () {
        const expected = {
          0: 'UTC+00:00',
          -18000: 'UTC-05:00',
          19800: 'UTC+05:30',
          20700: 'UTC+05:45',
          30: 'UTC+00:00:30',
          -30: 'UTC-00:00:30',
          -2670: 'UTC-00:44:30',
          -86400: 'UTC-24:00',
          86400: 'UTC+24:00',
        };
        for (final entry in expected.entries) {
          expect(CivilTimeResolver.formatUtcOffset(entry.key), entry.value);
        }
      },
    );

    test(
      'invalid offset bounds including int64 minimum cannot wrap into a label',
      () {
        for (final value in [
          -9223372036854775808,
          -86401,
          86401,
          9223372036854775807,
        ]) {
          expect(
            () => CivilTimeResolver.formatUtcOffset(value),
            throwsFormatException,
          );
        }
      },
    );
  });
}
