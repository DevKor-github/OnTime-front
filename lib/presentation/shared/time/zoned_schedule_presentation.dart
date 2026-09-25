import 'package:on_time_front/core/time/civil_time_resolver.dart';
import 'package:on_time_front/core/time/time_zone_rules.dart';
import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'package:on_time_front/domain/entities/schedule_time_resolution.dart';
import 'device_time_zone_state.dart';

enum DeviceTimeConversionStatus {
  available,
  unresolvedSchedule,
  loading,
  unavailable,
  outOfRange,
}

/// Wall fields and the offset at this occurrence, not today's zone offset.
final class ZonedCivilTime {
  const ZonedCivilTime({
    required this.civil,
    required this.timeZoneId,
    required this.offsetSeconds,
  });

  final CivilDateTime civil;
  final String timeZoneId;
  final int? offsetSeconds;
}

/// Pure display projection of one already interpreted commitment.
///
/// It does not resolve missing history, select an occurrence, read a clock or
/// write data. In particular, unknown zones do not gain a device equivalent.
final class ZonedSchedulePresentation {
  ZonedSchedulePresentation._({
    required this.original,
    required this.device,
    required this.resolution,
    required this.deviceTimeZone,
    required this.instantUtc,
    required this.deviceConversionStatus,
  });

  factory ZonedSchedulePresentation.from({
    required CivilDateTime civil,
    required String scheduleTimeZoneId,
    required ScheduleTimeResolution resolution,
    required DeviceTimeZoneState deviceTimeZone,
  }) {
    final instant = resolution.status == ScheduleTimeResolutionStatus.resolved
        ? resolution.instantUtc?.toUtc()
        : null;
    final offset = instant == null
        ? null
        : civil.toUtcCarrier().difference(instant).inSeconds;
    ZonedCivilTime? device;
    var observed = deviceTimeZone;
    var conversion = switch (observed.status) {
      DeviceTimeZoneStatus.loading => DeviceTimeConversionStatus.loading,
      DeviceTimeZoneStatus.unavailable =>
        DeviceTimeConversionStatus.unavailable,
      DeviceTimeZoneStatus.known =>
        DeviceTimeConversionStatus.unresolvedSchedule,
    };
    final deviceId = observed.identifier;
    if (observed.status == DeviceTimeZoneStatus.known) {
      if (deviceId == null || !TimeZoneRules.contains(deviceId)) {
        observed = const DeviceTimeZoneState.unavailable();
        conversion = DeviceTimeConversionStatus.unavailable;
      } else if (instant != null) {
        try {
          final converted = CivilTimeResolver.civilTimeAt(instant, deviceId);
          device = ZonedCivilTime(
            civil: CivilDateTime.fromFields(converted),
            timeZoneId: deviceId,
            offsetSeconds: converted.timeZoneOffset.inSeconds,
          );
          conversion = DeviceTimeConversionStatus.available;
        } on FormatException {
          conversion = DeviceTimeConversionStatus.outOfRange;
        } on Exception {
          observed = const DeviceTimeZoneState.unavailable();
          conversion = DeviceTimeConversionStatus.unavailable;
        }
      }
    }
    return ZonedSchedulePresentation._(
      original: ZonedCivilTime(
        civil: civil,
        timeZoneId: scheduleTimeZoneId,
        offsetSeconds: offset,
      ),
      device: device,
      resolution: resolution,
      deviceTimeZone: observed,
      instantUtc: instant,
      deviceConversionStatus: conversion,
    );
  }

  final ZonedCivilTime original;
  final ZonedCivilTime? device;
  final ScheduleTimeResolution resolution;
  final DeviceTimeZoneState deviceTimeZone;
  final DateTime? instantUtc;
  final DeviceTimeConversionStatus deviceConversionStatus;

  // Different offsets are neither necessary nor sufficient to identify zones.
  // Preserve the supplied names; do not guess alias equivalence.
  bool get showDeviceEquivalent =>
      device != null && device!.timeZoneId != original.timeZoneId;

  bool get hasDifferentDeviceDate {
    final other = device?.civil.toUtcCarrier();
    if (other == null) return false;
    final own = original.civil.toUtcCarrier();
    return own.year != other.year ||
        own.month != other.month ||
        own.day != other.day;
  }
}
