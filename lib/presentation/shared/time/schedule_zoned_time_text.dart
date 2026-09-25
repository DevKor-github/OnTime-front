import 'package:intl/intl.dart';
import 'package:on_time_front/core/time/civil_time_resolver.dart';
import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'package:on_time_front/domain/entities/schedule_time_resolution.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'device_time_zone_state.dart';
import 'zoned_schedule_presentation.dart';

final class ScheduleZonedTimeText {
  const ScheduleZonedTimeText._({
    required this.original,
    required this.device,
    required this.statusMessage,
    required this.semanticsLabel,
    required this.instant,
  });

  factory ScheduleZonedTimeText.format({
    required ZonedSchedulePresentation presentation,
    required AppLocalizations l10n,
    required bool use24HourFormat,
    bool showResolutionStatus = true,
  }) {
    String line(ZonedCivilTime value) => [
      formatCivil(
        value.civil,
        locale: l10n.localeName,
        use24HourFormat: use24HourFormat,
      ),
      value.timeZoneId.isEmpty ? l10n.zonedTimeUnknownZone : value.timeZoneId,
      if (value.offsetSeconds != null)
        CivilTimeResolver.formatUtcOffset(value.offsetSeconds!),
    ].join(' · ');
    final original = line(presentation.original);
    final device = presentation.showDeviceEquivalent
        ? line(presentation.device!)
        : null;
    final resolution = presentation.resolution;
    final unresolved = switch (resolution.status) {
      ScheduleTimeResolutionStatus.resolved => null,
      ScheduleTimeResolutionStatus.historicalUncertain =>
        l10n.zonedTimeHistoricalUncertain,
      ScheduleTimeResolutionStatus.unknownZone =>
        resolution.isHistorical
            ? l10n.zonedTimeHistoricalUnknownZone
            : l10n.zonedTimeUnknownZone,
      ScheduleTimeResolutionStatus.nonexistent => l10n.zonedTimeNonexistent,
      ScheduleTimeResolutionStatus.ambiguous => l10n.zonedTimeAmbiguous,
      ScheduleTimeResolutionStatus.changed => l10n.zonedTimeRulesChanged,
      ScheduleTimeResolutionStatus.invalid => l10n.zonedTimeInvalid,
    };
    final deviceStatus = switch (presentation.deviceTimeZone.status) {
      DeviceTimeZoneStatus.loading => l10n.zonedTimeDeviceLoading,
      DeviceTimeZoneStatus.unavailable => l10n.zonedTimeDeviceUnavailable,
      DeviceTimeZoneStatus.known => null,
    };
    final messages = [
      if (showResolutionStatus) ?unresolved,
      ?deviceStatus,
      if (presentation.deviceConversionStatus ==
          DeviceTimeConversionStatus.outOfRange)
        l10n.zonedTimeDeviceOutOfRange,
    ];
    final status = messages.isEmpty ? null : messages.join('\n');
    return ScheduleZonedTimeText._(
      original: original,
      device: device,
      statusMessage: status,
      instant: presentation.instantUtc?.toIso8601String(),
      semanticsLabel: [
        '${l10n.zonedTimeOriginal}: $original',
        if (device != null) '${l10n.zonedTimeDevice}: $device',
        ...messages,
      ].join('. '),
    );
  }

  final String original;
  final String? device;
  final String? statusMessage;
  final String semanticsLabel;
  final String? instant;

  /// Format wall fields without consulting the device zone. Retain any stored
  /// seconds and fractional seconds, including microseconds beyond intl's SSS.
  static String formatCivil(
    CivilDateTime civil, {
    required String locale,
    required bool use24HourFormat,
  }) {
    final value = civil.toUtcCarrier();
    final micros = value.millisecond * 1000 + value.microsecond;
    final precise = value.second != 0 || micros != 0;
    final time = use24HourFormat
        ? (precise ? DateFormat.Hms(locale) : DateFormat.Hm(locale))
        : (precise ? DateFormat.jms(locale) : DateFormat.jm(locale));
    var pattern = time.pattern!;
    if (micros != 0) {
      final fraction = micros.toString().padLeft(6, '0');
      pattern = pattern.replaceFirstMapped(
        RegExp(r's+'),
        (match) => "${match.group(0)}'.$fraction'",
      );
    }
    return '${DateFormat.yMd(locale).format(value)} ${DateFormat(pattern, locale).format(value)}';
  }
}
