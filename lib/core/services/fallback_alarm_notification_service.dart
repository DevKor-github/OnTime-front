import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/services/notification_service.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';

abstract interface class FallbackAlarmNotificationService {
  Future<AlarmPermissionState> checkPermission();

  Future<AlarmPermissionState> requestPermission();

  Future<void> scheduleFallbackAlarm(ScheduledAlarmRecord record);

  Future<void> cancelFallbackAlarm(ScheduledAlarmRecord record);
}

@Singleton(as: FallbackAlarmNotificationService)
class FallbackAlarmNotificationServiceImpl
    implements FallbackAlarmNotificationService {
  @override
  Future<AlarmPermissionState> checkPermission() async {
    return _fromAuthorizationStatus(
      await NotificationService.instance.checkNotificationPermission(),
    );
  }

  @override
  Future<AlarmPermissionState> requestPermission() async {
    return _fromAuthorizationStatus(
      await NotificationService.instance.requestPermission(),
    );
  }

  @override
  Future<void> scheduleFallbackAlarm(ScheduledAlarmRecord record) {
    return NotificationService.instance.scheduleFallbackAlarm(record);
  }

  @override
  Future<void> cancelFallbackAlarm(ScheduledAlarmRecord record) async {
    final notificationId =
        record.fallbackNotificationId ?? stableAlarmId(record.scheduleId);
    await NotificationService.instance.cancelFallbackNotification(
      notificationId,
    );
  }

  AlarmPermissionState _fromAuthorizationStatus(AuthorizationStatus status) {
    switch (status) {
      case AuthorizationStatus.authorized:
      case AuthorizationStatus.provisional:
        return AlarmPermissionState.granted;
      case AuthorizationStatus.denied:
        return AlarmPermissionState.denied;
      case AuthorizationStatus.notDetermined:
        return AlarmPermissionState.notDetermined;
    }
  }
}
