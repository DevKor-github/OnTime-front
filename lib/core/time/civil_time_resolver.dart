import '../../domain/entities/civil_time_occurrence.dart';
export '../../domain/entities/civil_time_occurrence.dart';
import 'time_zone_rules.dart';
import '../../domain/entities/civil_date_time.dart';
import 'package:timezone/timezone.dart' as tz;

abstract final class CivilTimeResolver {
  /// Resolves a wall-clock selection in [timeZoneId] to every valid instant.
  ///
  /// A normal civil time has one occurrence, a spring-forward gap has none,
  /// and a fall-back overlap has two. Results are ordered by absolute time so
  /// the UI can present an unambiguous first/second occurrence choice.
  static List<CivilTimeOccurrence> resolve(
    DateTime civilTime,
    String timeZoneId,
  ) {
    _ensureInitialized();
    final location = _location(timeZoneId);
    final civil = CivilDateTime.fromFields(civilTime);

    // Enumerate actual zone offsets and round-trip each candidate. This also
    // preserves historical second-level offsets without 73 lookups per slot.
    final candidateOffsets = location.zones
        .map((zone) => zone.offset ~/ Duration.millisecondsPerSecond)
        .toSet();

    final occurrences = <CivilTimeOccurrence>[];
    for (final offsetSeconds in candidateOffsets) {
      DateTime instant;
      try {
        instant = civil.atOffset(offsetSeconds);
      } on FormatException {
        continue; // Outside the persisted year range is not a valid occurrence.
      }
      final roundTrip = tz.TZDateTime.from(instant, location);
      if (_hasSameCivilFields(civilTime, roundTrip)) {
        occurrences.add(
          CivilTimeOccurrence(
            offsetSeconds: offsetSeconds,
            instantUtc: instant,
          ),
        );
      }
    }
    occurrences.sort(
      (left, right) => left.instantUtc.compareTo(right.instantUtc),
    );
    return occurrences;
  }

  /// A proposal only. The caller must obtain an explicit user selection before
  /// modifying a schedule; no gap is silently normalized or persisted.
  static DateTime? nextValidCivilTime(DateTime civilTime, String timeZoneId) {
    if (!TimeZoneRules.contains(timeZoneId)) return null;
    final carrier = CivilDateTime.fromFields(civilTime).toUtcCarrier();
    final minute = DateTime.utc(
      carrier.year,
      carrier.month,
      carrier.day,
      carrier.hour,
      carrier.minute,
    );
    for (var distance = 1; distance <= 2880; distance++) {
      final candidate = minute.add(Duration(minutes: distance));
      if (candidate.year > 9999) return null;
      if (resolve(candidate, timeZoneId).isNotEmpty) return candidate;
    }
    return null;
  }

  static DateTime civilTimeAt(DateTime instant, String timeZoneId) {
    _ensureInitialized();
    return tz.TZDateTime.from(instant.toUtc(), _location(timeZoneId));
  }

  static String formatUtcOffset(int offsetSeconds) {
    if (offsetSeconds < -86400 || offsetSeconds > 86400) {
      throw const FormatException('Occurrence offset is out of range');
    }
    final sign = offsetSeconds < 0 ? '-' : '+';
    final totalMinutes = offsetSeconds.abs() ~/ 60;
    final hours = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    final minutes = (totalMinutes % 60).toString().padLeft(2, '0');
    final seconds = offsetSeconds.abs() % 60;
    return 'UTC$sign$hours:$minutes${seconds == 0 ? '' : ':${seconds.toString().padLeft(2, '0')}'}';
  }

  static void _ensureInitialized() {
    TimeZoneRules.ensureInitialized();
  }

  static tz.Location _location(String timeZoneId) =>
      TimeZoneRules.location(timeZoneId);

  static bool _hasSameCivilFields(DateTime source, DateTime candidate) {
    return source.year == candidate.year &&
        source.month == candidate.month &&
        source.day == candidate.day &&
        source.hour == candidate.hour &&
        source.minute == candidate.minute &&
        source.second == candidate.second &&
        source.millisecond == candidate.millisecond &&
        source.microsecond == candidate.microsecond;
  }
}
