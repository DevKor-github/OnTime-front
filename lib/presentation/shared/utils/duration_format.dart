import 'package:flutter/material.dart';
import 'package:on_time_front/l10n/app_localizations.dart';

String formatDuration(BuildContext context, Duration duration) {
  final localizations = AppLocalizations.of(context)!;
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);

  final parts = <String>[];
  if (hours > 0) {
    parts.add(localizations.hourFormatted(hours));
  }
  if (minutes > 0) {
    parts.add(localizations.minuteFormatted(minutes));
  }

  if (parts.isEmpty) {
    return localizations.minuteFormatted(0);
  }

  return parts.join(' ');
}
