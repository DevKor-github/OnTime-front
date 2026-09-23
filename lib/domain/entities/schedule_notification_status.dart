import 'package:on_time_front/domain/entities/alarm_entities.dart';

enum ScheduleNotificationStatus {
  off,
  permissionNeeded,
  empty,
  alarm,
  notification,
  precise,
  approximate,
  mixed,
  incomplete,
}

/// Capability is intentionally not evidence that an OS registration succeeded.
ScheduleNotificationStatus scheduleNotificationStatus({
  required bool enabled,
  required bool canDeliver,
  required List<ScheduledAlarmRecord> records,
  required AlarmReconciliationResult? result,
  required DateTime now,
  bool requiresExactTimingEvidence = true,
}) {
  if (!enabled) return ScheduleNotificationStatus.off;
  if (!canDeliver) return ScheduleNotificationStatus.permissionNeeded;
  if (result == null ||
      result.status != AlarmReconciliationStatus.armed ||
      result.failures.isNotEmpty ||
      records.any((record) => record.cancellationPending)) {
    return ScheduleNotificationStatus.incomplete;
  }
  final future = records
      .where((record) => record.alarmTime.isAfter(now))
      .toList();
  if (future.isEmpty && result.armedScheduleIds.isEmpty) {
    return ScheduleNotificationStatus.empty;
  }
  final ids = future.map((record) => record.scheduleId).toSet();
  if (ids.length != result.armedScheduleIds.length ||
      !ids.containsAll(result.armedScheduleIds) ||
      future.any((record) => !record.hasCurrentContent)) {
    return ScheduleNotificationStatus.incomplete;
  }
  if (future.every((record) => record.provider == AlarmProvider.iosAlarmKit)) {
    return ScheduleNotificationStatus.alarm;
  }
  if (future.any(
    (record) => record.provider != AlarmProvider.localNotification,
  )) {
    return ScheduleNotificationStatus.notification;
  }
  if (!requiresExactTimingEvidence) {
    return ScheduleNotificationStatus.notification;
  }
  final modes = future.map((record) => record.notificationTiming).toSet();
  if (modes.contains(null)) return ScheduleNotificationStatus.incomplete;
  if (modes.contains(NotificationTiming.platformDefault)) {
    return ScheduleNotificationStatus.notification;
  }
  if (modes.length > 1) return ScheduleNotificationStatus.mixed;
  return modes.single == NotificationTiming.exact
      ? ScheduleNotificationStatus.precise
      : ScheduleNotificationStatus.approximate;
}
