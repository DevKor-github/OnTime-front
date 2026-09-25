/// OS payloads are untrusted routing hints, never instructions to start a run.
Map<String, String> minimalScheduleRoutePayload(Map<dynamic, dynamic> source) {
  final id = source['scheduleId'];
  if (id is! String ||
      id.trim().isEmpty ||
      id.length > 512 ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(id)) {
    return const {};
  }
  final type = source['type'];
  if (type != 'schedule_alarm' && type != 'schedule_notification') {
    return const {};
  }
  return {
    'type': type as String,
    'scheduleId': id,
    'alarmLaunchPayloadVersion': '9',
    'promptVariant': type == 'schedule_alarm' ? 'alarm' : 'notification',
  };
}
