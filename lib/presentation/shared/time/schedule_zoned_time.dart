import 'package:flutter/material.dart';
import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'package:on_time_front/domain/entities/schedule_time_resolution.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'device_time_zone_scope.dart';
import 'device_time_zone_state.dart';
import 'schedule_zoned_time_text.dart';
import 'zoned_schedule_presentation.dart';

class ScheduleZonedTime extends StatelessWidget {
  const ScheduleZonedTime({
    super.key,
    required this.civil,
    required this.timeZoneId,
    required this.resolution,
    this.deviceTimeZone,
    this.showInstant = false,
    this.showResolutionStatus = true,
    this.style,
  });

  final CivilDateTime civil;
  final String timeZoneId;
  final ScheduleTimeResolution resolution;
  final DeviceTimeZoneState? deviceTimeZone;
  final bool showInstant;

  /// False only when the containing form already provides occurrence guidance.
  /// Device observation and conversion messages remain visible.
  final bool showResolutionStatus;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final text = ScheduleZonedTimeText.format(
      presentation: ZonedSchedulePresentation.from(
        civil: civil,
        scheduleTimeZoneId: timeZoneId,
        resolution: resolution,
        deviceTimeZone: deviceTimeZone ?? DeviceTimeZoneScope.stateOf(context),
      ),
      l10n: l10n,
      use24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      showResolutionStatus: showResolutionStatus,
    );
    final instant = showInstant ? text.instant : null;
    return Semantics(
      label: [
        text.semanticsLabel,
        if (instant != null) '${l10n.zonedTimeInstant}: $instant',
      ].join('. '),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${l10n.zonedTimeOriginal}: ${text.original}', style: style),
            if (text.device != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${l10n.zonedTimeDevice}: ${text.device}',
                  style: style,
                ),
              ),
            if (text.statusMessage != null)
              Text(text.statusMessage!, style: style),
            if (instant != null)
              Text('${l10n.zonedTimeInstant}: $instant', style: style),
          ],
        ),
      ),
    );
  }
}
