import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/time/civil_time_resolver.dart';

void main() {
  test('normal civil time resolves to one absolute occurrence', () {
    final occurrences = CivilTimeResolver.resolve(
      DateTime(2026, 2, 1, 12, 30),
      'America/New_York',
    );

    expect(occurrences, hasLength(1));
    expect(occurrences.single.offsetSeconds, -5 * 60 * 60);
    expect(occurrences.single.instantUtc, DateTime.utc(2026, 2, 1, 17, 30));
  });

  test('spring-forward gap has no valid occurrence', () {
    expect(
      CivilTimeResolver.resolve(
        DateTime(2026, 3, 8, 2, 30),
        'America/New_York',
      ),
      isEmpty,
    );
  });

  test('fall-back overlap exposes first and second occurrence', () {
    final occurrences = CivilTimeResolver.resolve(
      DateTime(2026, 11, 1, 1, 30),
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
}
