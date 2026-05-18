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
      payload['alarmLaunchPayloadVersion'] != null ||
      (promptVariant == 'alarm' && payload['scheduleId'] != null);
}

bool isScheduleAlarmMessagePayload({
  required Map<dynamic, dynamic> data,
  String? title,
}) {
  return isScheduleAlarmPayload(data) ||
      title == '약속 알림' ||
      title == 'Schedule alarm';
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

  if (type == 'schedule_alarm' && scheduleId != null) {
    return NotificationRouteTarget(
      '/scheduleStart',
      extra: Map<String, dynamic>.from(data),
    );
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
