import '../time/time_zone_rules.dart';
import 'package:timezone/timezone.dart' as tz;
import 'backup_limits.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';

abstract final class BackupValueValidation {
  /// Portable syntax/size only. Registry meaning needs a validation-time
  /// context and must be checked before any future execution is authorized.
  static void zoneIdentifier(String value) {
    BackupLimits.string(value, identifier: true);
    if (value.isEmpty) BackupLimits.invalid();
  }

  static void namedZone(String value) {
    zoneIdentifier(value);
    TimeZoneRules.ensureInitialized();
    try {
      tz.getLocation(value);
    } catch (_) {
      BackupLimits.invalid();
    }
  }

  static bool explicitOffset(String value) =>
      RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(value);

  static DateTime instant(String value) {
    // Validate literal calendar before classifying its missing representation.
    date(value, civilTime: true);
    if (!explicitOffset(value)) {
      throw const BackupProcessingFailure(
        BackupFailureKind.unsupportedRepresentation,
      );
    }
    final parsed = date(value).toUtc();
    if (parsed.year < 1 || parsed.year > 9999) BackupLimits.invalid();
    if (parsed.microsecondsSinceEpoch % Duration.microsecondsPerSecond != 0) {
      throw const BackupProcessingFailure(
        BackupFailureKind.unsupportedRepresentation,
      );
    }
    return parsed;
  }

  static DateTime date(String value, {bool civilTime = false}) {
    BackupLimits.string(value);
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,6}))?(Z|[+-]\d{2}:?\d{2})?$',
    ).firstMatch(value);
    if (match == null || match.end != value.length) BackupLimits.invalid();
    final parts = [for (var i = 1; i <= 6; i++) int.parse(match.group(i)!)];
    if (parts[0] < 1 ||
        parts[1] < 1 ||
        parts[1] > 12 ||
        parts[2] < 1 ||
        parts[2] > 31 ||
        parts[3] > 23 ||
        parts[4] > 59 ||
        parts[5] > 59) {
      BackupLimits.invalid();
    }
    final civil = DateTime.utc(
      parts[0],
      parts[1],
      parts[2],
      parts[3],
      parts[4],
      parts[5],
    );
    if (civil.year != parts[0] ||
        civil.month != parts[1] ||
        civil.day != parts[2]) {
      BackupLimits.invalid();
    }
    final zone = match.group(8);
    if (zone != null && zone != 'Z') {
      final digits = zone.substring(1).replaceAll(':', '');
      if (int.parse(digits.substring(0, 2)) > 23 ||
          int.parse(digits.substring(2)) > 59) {
        BackupLimits.invalid();
      }
    }
    if (civilTime) {
      final micros = int.parse((match.group(7) ?? '').padRight(6, '0'));
      return DateTime.utc(
        parts[0],
        parts[1],
        parts[2],
        parts[3],
        parts[4],
        parts[5],
        micros ~/ 1000,
        micros % 1000,
      );
    }
    final result = DateTime.tryParse(value);
    if (result == null || result.year < 1 || result.year > 9999) {
      BackupLimits.invalid();
    }
    return result;
  }
}
