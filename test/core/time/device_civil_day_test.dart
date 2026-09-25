import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/time/device_civil_day.dart';

void main() {
  final zone = Platform.environment['TZ'];
  const supported = {'UTC', 'Asia/Seoul', 'America/New_York', 'Pacific/Apia'};

  void expectInterval(
    DeviceCivilDay day,
    DateTime start,
    DateTime end,
    int hours,
  ) {
    expect(day.startUtc, start);
    expect(day.endUtc, end);
    expect(day.endUtc.difference(day.startUtc), Duration(hours: hours));
    expect(
      day.contains(start.subtract(const Duration(microseconds: 1))),
      isFalse,
    );
    expect(day.contains(start), isTrue);
    expect(day.contains(start.toLocal()), isTrue);
    expect(day.contains(end.subtract(const Duration(microseconds: 1))), isTrue);
    expect(day.contains(end), isFalse);
  }

  group(
    'actual device civil day in $zone',
    () {
      test('the process actually uses the requested timezone fixture', () {
        final expected = switch (zone) {
          'UTC' => (winter: 0, summer: 0),
          'Asia/Seoul' => (winter: 540, summer: 540),
          'America/New_York' => (winter: -300, summer: -240),
          'Pacific/Apia' => (winter: 780, summer: 780),
          _ => throw StateError('Unsupported TZ fixture'),
        };
        expect(
          DateTime(2026, 1, 15, 12).timeZoneOffset.inMinutes,
          expected.winter,
        );
        expect(
          DateTime(2026, 7, 15, 12).timeZoneOffset.inMinutes,
          expected.summer,
        );
      });

      test(
        'spring day ends at the next local midnight, not 24 elapsed hours',
        () {
          final day = DeviceCivilDay.at(DateTime.utc(2026, 3, 8, 12));
          final expected = switch (zone) {
            'UTC' => (DateTime.utc(2026, 3, 8), DateTime.utc(2026, 3, 9), 24),
            'Asia/Seoul' => (
              DateTime.utc(2026, 3, 7, 15),
              DateTime.utc(2026, 3, 8, 15),
              24,
            ),
            'America/New_York' => (
              DateTime.utc(2026, 3, 8, 5),
              DateTime.utc(2026, 3, 9, 4),
              23,
            ),
            'Pacific/Apia' => (
              DateTime.utc(2026, 3, 8, 11),
              DateTime.utc(2026, 3, 9, 11),
              24,
            ),
            _ => throw StateError('Unsupported TZ fixture'),
          };
          expectInterval(day, expected.$1, expected.$2, expected.$3);
        },
      );

      test(
        'fall day includes both overlap occurrences and excludes next midnight',
        () {
          final day = DeviceCivilDay.at(DateTime.utc(2026, 11, 1, 12));
          final expected = switch (zone) {
            'UTC' => (DateTime.utc(2026, 11, 1), DateTime.utc(2026, 11, 2), 24),
            'Asia/Seoul' => (
              DateTime.utc(2026, 10, 31, 15),
              DateTime.utc(2026, 11, 1, 15),
              24,
            ),
            'America/New_York' => (
              DateTime.utc(2026, 11, 1, 4),
              DateTime.utc(2026, 11, 2, 5),
              25,
            ),
            'Pacific/Apia' => (
              DateTime.utc(2026, 11, 1, 11),
              DateTime.utc(2026, 11, 2, 11),
              24,
            ),
            _ => throw StateError('Unsupported TZ fixture'),
          };
          expectInterval(day, expected.$1, expected.$2, expected.$3);
          if (zone == 'America/New_York') {
            expect(day.contains(DateTime.utc(2026, 11, 1, 5, 30)), isTrue);
            expect(day.contains(DateTime.utc(2026, 11, 1, 6, 30)), isTrue);
          }
        },
      );

      test(
        'one Seoul appointment belongs to the correct current device date',
        () {
          final appointment = DateTime.utc(2026, 9, 25);
          final day = DeviceCivilDay.at(appointment);
          final expectedStart = switch (zone) {
            'UTC' => DateTime.utc(2026, 9, 25),
            'Asia/Seoul' => DateTime.utc(2026, 9, 24, 15),
            'America/New_York' => DateTime.utc(2026, 9, 24, 4),
            'Pacific/Apia' => DateTime.utc(2026, 9, 24, 11),
            _ => throw StateError('Unsupported TZ fixture'),
          };
          expect(day.startUtc, expectedStart);
          expect(day.contains(appointment), isTrue);
          expect(
            appointment.toLocal().day,
            zone == 'America/New_York' ? 24 : 25,
          );
        },
      );

      if (zone == 'Pacific/Apia') {
        test(
          'the skipped local date creates no missing or duplicated instant interval',
          () {
            final transition = DateTime.utc(2011, 12, 30, 10);
            final before = transition.subtract(const Duration(microseconds: 1));
            expect(before.toLocal().day, 29);
            expect(transition.toLocal().day, 31);
            expectInterval(
              DeviceCivilDay.at(before),
              DateTime.utc(2011, 12, 29, 10),
              transition,
              24,
            );
            expectInterval(
              DeviceCivilDay.at(transition),
              transition,
              DateTime.utc(2011, 12, 31, 10),
              24,
            );
          },
        );
      }
    },
    skip: supported.contains(zone)
        ? false
        : 'Requires explicit TZ=UTC, Asia/Seoul, America/New_York or Pacific/Apia; dedicated matrix is mandatory.',
  );
}
