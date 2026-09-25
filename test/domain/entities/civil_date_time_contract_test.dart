import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/civil_date_time.dart';

void main() {
  // A10: civil text describes wall fields. A suffix on historical civil text
  // must not turn it into an instant; the selected occurrence offset does that.
  group('preserved civil values', () {
    test('foreign DST gap fields survive parsing and calendar adaptation', () {
      final civil = CivilDateTime.parse('2026-03-08T02:30:15.123456');
      final adapted = CivilDateTime.fromFields(civil.toUtcCarrier());

      expect(adapted.toCivilIso8601String(), '2026-03-08T02:30:15.123456');
      expect(
        adapted.atOffset(32400),
        DateTime.utc(2026, 3, 7, 17, 30, 15, 123, 456),
      );
    });

    test(
      'valid legacy suffixes preserve wall fields instead of shifting them',
      () {
        for (final suffix in ['', 'Z', '+09:00', '-0400', '+23:59', '-2359']) {
          final civil = CivilDateTime.parse(
            '2026-09-25T09:00:01.000001$suffix',
          );

          expect(
            civil.toCivilIso8601String(),
            '2026-09-25T09:00:01.000001',
            reason: 'civil suffix $suffix is not the occurrence selection',
          );
          expect(
            civil.atOffset(32400),
            DateTime.utc(2026, 9, 25, 0, 0, 1, 0, 1),
          );
        }
      },
    );

    test(
      'local DateTime input contributes fields without device UTC conversion',
      () {
        final input = DateTime(2026, 9, 25, 9, 15, 21, 123, 456);
        final civil = CivilDateTime.fromFields(input);

        expect(civil.toCivilIso8601String(), '2026-09-25T09:15:21.123456');
        expect(
          civil.atOffset(32400),
          DateTime.utc(2026, 9, 25, 0, 15, 21, 123, 456),
        );
      },
    );

    test(
      'leap-day and calendar range endpoints retain subsecond precision',
      () {
        for (final literal in [
          '0001-01-01T00:00:00.000001',
          '2000-02-29T23:59:59.999999',
          '2024-02-29T12:34:56.123456',
          '9999-12-31T23:59:59.999999',
        ]) {
          final civil = CivilDateTime.parse(literal);
          expect(civil.toCivilIso8601String(), literal);
          expect(civil.atOffset(0).toIso8601String(), '${literal}Z');
        }
        expect(
          CivilDateTime.parse('2026-09-25T09:00:00.1').toCivilIso8601String(),
          '2026-09-25T09:00:00.100',
        );
      },
    );
  });

  group('invalid civil input is rejected rather than normalized', () {
    test('calendar overflow does not silently move an appointment', () {
      for (final literal in [
        '0000-01-01T00:00:00',
        '10000-01-01T00:00:00',
        '1900-02-29T12:00:00',
        '2026-02-29T12:00:00',
        '2026-04-31T12:00:00',
        '2026-00-01T12:00:00',
        '2026-13-01T12:00:00',
        '2026-01-00T12:00:00',
        '2026-01-01T24:00:00',
        '2026-01-01T12:60:00',
        '2026-01-01T12:00:60',
      ]) {
        expect(
          () => CivilDateTime.parse(literal),
          throwsFormatException,
          reason: literal,
        );
      }
    });

    test('invalid suffixes cannot acquire civil or instant authority', () {
      for (final suffix in [
        '+24:00',
        '-2400',
        '+00:60',
        '-0060',
        '+99:99',
        '+9:00',
        '+00:00:01',
      ]) {
        expect(
          () => CivilDateTime.parse('2026-09-25T09:00:00$suffix'),
          throwsFormatException,
          reason: suffix,
        );
      }
    });

    test(
      'malformed or excessive precision is not truncated into a valid value',
      () {
        for (final literal in [
          '2026-09-25',
          '2026-09-25 09:00:00',
          '2026-09-25T09:00',
          '2026-09-25T09:00:00.',
          '2026-09-25T09:00:00.1234567',
          '2026-09-25T09:00:00Zsuffix',
          ' 2026-09-25T09:00:00',
          '2026-09-25T09:00:00\n',
          '2026-09-25T09:00:00\r\n',
        ]) {
          expect(
            () => CivilDateTime.parse(literal),
            throwsFormatException,
            reason: literal,
          );
        }
      },
    );

    test('calendar adapters reject years outside the persisted contract', () {
      expect(
        () => CivilDateTime.fromFields(DateTime.utc(0)),
        throwsFormatException,
      );
      expect(
        () => CivilDateTime.fromFields(DateTime.utc(10000)),
        throwsFormatException,
      );
    });
  });

  group('selected offset defines the actual occurrence', () {
    test('different civil dates can describe the same appointment instant', () {
      final seoul = CivilDateTime.parse('2026-09-25T09:00:00.123456');
      final newYork = CivilDateTime.parse('2026-09-24T20:00:00.123456');
      final expected = DateTime.utc(2026, 9, 25, 0, 0, 0, 123, 456);

      expect(seoul.atOffset(32400), expected);
      expect(newYork.atOffset(-14400), expected);
      expect(newYork.compareTo(seoul), lessThan(0));
      expect(seoul.toCivilIso8601String(), '2026-09-25T09:00:00.123456');
      expect(newYork.toCivilIso8601String(), '2026-09-24T20:00:00.123456');
    });

    test('explicit overlap choices remain two distinct instants', () {
      final repeatedCivil = CivilDateTime.parse('2026-11-01T01:30:00.000001');

      expect(
        repeatedCivil.atOffset(-14400),
        DateTime.utc(2026, 11, 1, 5, 30, 0, 0, 1),
      );
      expect(
        repeatedCivil.atOffset(-18000),
        DateTime.utc(2026, 11, 1, 6, 30, 0, 0, 1),
      );
    });

    test('second and fractional-hour offsets do not lose precision', () {
      // Synthetic explicit historical offset, without asserting a tzdb version.
      final historical = CivilDateTime.parse('1890-01-01T00:00:00.123456');
      expect(
        historical.atOffset(561),
        DateTime.utc(1889, 12, 31, 23, 50, 39, 123, 456),
      );
      expect(
        historical.atOffset(-561),
        DateTime.utc(1890, 1, 1, 0, 9, 21, 123, 456),
      );
      expect(
        CivilDateTime.parse('2026-09-25T09:00:00').atOffset(20700),
        DateTime.utc(2026, 9, 25, 3, 15),
      );
    });

    test(
      'portable offset endpoints are allowed without wrapping huge integers',
      () {
        final civil = CivilDateTime.parse('2026-09-25T00:00:00.000001');
        expect(civil.atOffset(86400), DateTime.utc(2026, 9, 24, 0, 0, 0, 0, 1));
        expect(
          civil.atOffset(-86400),
          DateTime.utc(2026, 9, 26, 0, 0, 0, 0, 1),
        );
        for (final offset in [
          86401,
          -86401,
          9223372036854775807,
          -9223372036854775808,
        ]) {
          expect(
            () => civil.atOffset(offset),
            throwsFormatException,
            reason: '$offset',
          );
        }
      },
    );

    test(
      'offset application rejects crossing either persisted year boundary',
      () {
        final first = CivilDateTime.parse('0001-01-01T00:00:00');
        final last = CivilDateTime.parse('9999-12-31T23:59:59.999999');

        expect(first.atOffset(-1), DateTime.utc(1, 1, 1, 0, 0, 1));
        expect(
          last.atOffset(1),
          DateTime.utc(9999, 12, 31, 23, 59, 58, 999, 999),
        );
        expect(() => first.atOffset(1), throwsFormatException);
        expect(() => last.atOffset(-1), throwsFormatException);
      },
    );
  });
}
