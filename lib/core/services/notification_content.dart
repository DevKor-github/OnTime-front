import 'dart:convert';

import 'package:on_time_front/core/services/notification_routing.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';

class NotificationDisplayContent {
  const NotificationDisplayContent({
    required this.title,
    required this.body,
    required this.payload,
  });

  final String title;
  final String body;
  final String payload;
}

NotificationDisplayContent? remoteNotificationDisplayContent({
  required Map<String, dynamic> data,
  String? notificationTitle,
  String? notificationBody,
}) {
  final title = notificationTitle ?? data['title'] ?? data['Title'];
  final body =
      notificationBody ??
      data['content'] ??
      data['body'] ??
      data['Content'] ??
      data['Body'];

  if (title == null && body == null) {
    return null;
  }

  return NotificationDisplayContent(
    title: title?.toString() ?? '알림',
    body: body?.toString() ?? '',
    payload: jsonEncode(data),
  );
}

String? encodeLocalNotificationPayload(Map<String, dynamic>? payload) {
  return payload == null ? null : jsonEncode(payload);
}

String preparationStepNotificationTitle({
  required String scheduleName,
  required String preparationName,
}) {
  return '[$scheduleName] $preparationName';
}

String preparationStepNotificationBody({required String languageCode}) {
  return localizedNotificationText(
    languageCode: languageCode,
    ko: '이어서 준비하세요.',
    en: 'Continue preparing',
  );
}

Map<String, String> preparationStepNotificationPayload({
  required String scheduleId,
  required String stepId,
}) {
  return {
    'type': 'preparation_step',
    'scheduleId': scheduleId,
    'stepId': stepId,
  };
}

int fallbackNotificationIdForRecord(ScheduledAlarmRecord record) {
  return record.fallbackNotificationId ?? stableAlarmId(record.scheduleId);
}

String fallbackAlarmNotificationBody({required String languageCode}) {
  return localizedNotificationText(
    languageCode: languageCode,
    ko: '준비를 시작할 시간입니다.',
    en: 'It is time to get ready.',
  );
}
