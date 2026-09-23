import 'package:equatable/equatable.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class CivilTimeOccurrence extends Equatable {
  const CivilTimeOccurrence({
    required this.offsetSeconds,
    required this.instantUtc,
  });

  final int offsetSeconds;
  final DateTime instantUtc;

  @override
  List<Object> get props => [offsetSeconds, instantUtc];
}

abstract final class CivilTimeResolver {
  static bool _initialized = false;

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
    final location = _locationOrUtc(timeZoneId);
    final civilAsUtc = DateTime.utc(
      civilTime.year,
      civilTime.month,
      civilTime.day,
      civilTime.hour,
      civilTime.minute,
      civilTime.second,
      civilTime.millisecond,
      civilTime.microsecond,
    );

    // Enumerate actual zone offsets and round-trip each candidate. This also
    // preserves historical second-level offsets without 73 lookups per slot.
    final candidateOffsets = location.zones
        .map((zone) => zone.offset ~/ Duration.millisecondsPerSecond)
        .toSet();

    final occurrences = <CivilTimeOccurrence>[];
    for (final offsetSeconds in candidateOffsets) {
      final instant = civilAsUtc.subtract(Duration(seconds: offsetSeconds));
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

  static DateTime civilTimeAt(DateTime instant, String timeZoneId) {
    _ensureInitialized();
    return tz.TZDateTime.from(instant.toUtc(), _locationOrUtc(timeZoneId));
  }

  static String formatUtcOffset(int offsetSeconds) {
    final sign = offsetSeconds < 0 ? '-' : '+';
    final totalMinutes = offsetSeconds.abs() ~/ 60;
    final hours = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    final minutes = (totalMinutes % 60).toString().padLeft(2, '0');
    return 'UTC$sign$hours:$minutes';
  }

  static void _ensureInitialized() {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    _initialized = true;
  }

  static tz.Location _locationOrUtc(String timeZoneId) {
    try {
      return tz.getLocation(timeZoneId);
    } catch (_) {
      return tz.UTC;
    }
  }

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
