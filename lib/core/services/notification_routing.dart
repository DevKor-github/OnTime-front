import 'package:on_time_front/domain/entities/notification_route_payload.dart';
import 'dart:convert';

import 'package:equatable/equatable.dart';

class NotificationRouteTarget extends Equatable {
  const NotificationRouteTarget(this.path, {this.extra});

  final String path;
  final Object? extra;

  @override
  List<Object?> get props => [path, extra];
}

String localizedNotificationText({
  required String languageCode,
  required String ko,
  required String en,
}) {
  return languageCode == 'ko' ? ko : en;
}

bool isScheduleAlarmPayload(Map<dynamic, dynamic>? payload) {
  if (payload == null) return false;
  final type = payload['type']?.toString();
  final promptVariant = payload['promptVariant']?.toString();
  return type == 'schedule_alarm' ||
      (promptVariant == 'alarm' && payload['scheduleId'] != null);
}

NotificationRouteTarget? notificationRouteForPayloadString(String? payload) {
  if (payload == null) return null;

  try {
    final decoded = jsonDecode(payload);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return notificationRouteForData(decoded);
  } on FormatException {
    return null;
  }
}

NotificationRouteTarget? notificationRouteForData(Map<dynamic, dynamic> data) {
  final type = data['type']?.toString();
  final scheduleId = data['scheduleId']?.toString();

  if (type == 'schedule_alarm' || type == 'schedule_notification') {
    final safe = minimalScheduleRoutePayload(data);
    if (safe.isEmpty) return null;
    return NotificationRouteTarget('/scheduleStart', extra: safe);
  }

  if (type != null && type.contains('5min')) {
    return const NotificationRouteTarget(
      '/scheduleStart',
      extra: {'promptVariant': 'earlyStart'},
    );
  }

  if ((type != null &&
          (type.startsWith('schedule_') || type.startsWith('preparation_'))) ||
      scheduleId != null) {
    return const NotificationRouteTarget('/alarmScreen');
  }

  return null;
}

/// Accepted tap inputs only. Legacy broad route heuristics are not an inbox
/// validator: unknown types must never replace a valid pending Schedule tap.
Map<String, dynamic>? safeNotificationTapData(String? raw) {
  if (raw == null) return null;
  try {
    final value = jsonDecode(raw);
    if (value is! Map<String, dynamic>) return null;
    final safe = minimalScheduleRoutePayload(value);
    if (safe.isNotEmpty) return safe;
    if (value['type'] == 'preparation_step') {
      final id = value['scheduleId'];
      if (id is! String ||
          id.trim().isEmpty ||
          id.length > 512 ||
          RegExp(r'[\x00-\x1f\x7f]').hasMatch(id)) {
        return null;
      }
      return {
        'type': 'preparation_step',
        'scheduleId': id,
        if (value['storeIncarnation'] is String)
          'storeIncarnation': value['storeIncarnation'],
      };
    }
  } on FormatException {
    return null;
  }
  return null;
}
