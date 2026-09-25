import 'package:equatable/equatable.dart';

/// Wall-clock fields, not an instant or the device's local time.
///
/// The UTC DateTime is an adapter for calendar arithmetic only. Resolve the
/// named zone and selected offset before using this value on an instant axis.
final class CivilDateTime extends Equatable
    implements Comparable<CivilDateTime> {
  CivilDateTime.fromFields(DateTime value)
    : _carrier = DateTime.utc(
        value.year,
        value.month,
        value.day,
        value.hour,
        value.minute,
        value.second,
        value.millisecond,
        value.microsecond,
      ) {
    if (value.year < 1 || value.year > 9999) {
      throw const FormatException('Civil year is out of range');
    }
  }

  const CivilDateTime._(this._carrier);
  final DateTime _carrier;

  factory CivilDateTime.parse(String value) {
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,6}))?(Z|[+-]\d{2}:?\d{2})?$',
    ).firstMatch(value);
    if (match == null || match.end != value.length) {
      throw const FormatException('Invalid civil time');
    }
    // Historical civil wire values can carry a suffix. Validate its syntax
    // without applying it to the wall fields, matching the portable decoder.
    final suffix = match.group(8);
    if (suffix != null && suffix != 'Z') {
      final digits = suffix.substring(1).replaceAll(':', '');
      if (int.parse(digits.substring(0, 2)) > 23 ||
          int.parse(digits.substring(2)) > 59) {
        throw const FormatException('Invalid civil offset suffix');
      }
    }
    final fields = [for (var i = 1; i <= 6; i++) int.parse(match.group(i)!)];
    final micros = int.parse((match.group(7) ?? '').padRight(6, '0'));
    final carrier = DateTime.utc(
      fields[0],
      fields[1],
      fields[2],
      fields[3],
      fields[4],
      fields[5],
      micros ~/ 1000,
      micros % 1000,
    );
    if (fields[0] < 1 ||
        fields[0] > 9999 ||
        carrier.year != fields[0] ||
        carrier.month != fields[1] ||
        carrier.day != fields[2] ||
        carrier.hour != fields[3] ||
        carrier.minute != fields[4] ||
        carrier.second != fields[5]) {
      throw const FormatException('Invalid civil time');
    }
    return CivilDateTime._(carrier);
  }

  DateTime toUtcCarrier() => _carrier;

  String toCivilIso8601String() {
    final encoded = _carrier.toIso8601String();
    return encoded.substring(0, encoded.length - 1);
  }

  DateTime atOffset(int offsetSeconds) {
    // abs(minInt64) wraps on native Dart, so compare before arithmetic.
    if (offsetSeconds < -86400 || offsetSeconds > 86400) {
      throw const FormatException('Occurrence offset is out of range');
    }
    final instant = _carrier.subtract(Duration(seconds: offsetSeconds));
    if (instant.year < 1 || instant.year > 9999) {
      throw const FormatException('Occurrence instant is out of range');
    }
    return instant;
  }

  @override
  int compareTo(CivilDateTime other) => _carrier.compareTo(other._carrier);

  @override
  List<Object> get props => [_carrier];
}
