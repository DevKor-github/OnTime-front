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
  FallbackAlarmNotificationServiceImpl({
    NotificationService? notificationService,
  }) : _notificationService =
           notificationService ?? NotificationService.instance;

  final NotificationService _notificationService;

  @override
  Future<AlarmPermissionState> checkPermission() async {
    return _fromAuthorizationStatus(
      await _notificationService.checkNotificationPermission(),
    );
  }

  @override
  Future<AlarmPermissionState> requestPermission() async {
    return _fromAuthorizationStatus(
      await _notificationService.requestPermission(),
    );
  }

  @override
  Future<void> scheduleFallbackAlarm(ScheduledAlarmRecord record) {
    return _notificationService.scheduleFallbackAlarm(record);
  }

  @override
  Future<void> cancelFallbackAlarm(ScheduledAlarmRecord record) async {
    final notificationId =
        record.fallbackNotificationId ?? stableAlarmId(record.scheduleId);
    await _notificationService.cancelFallbackNotification(notificationId);
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
