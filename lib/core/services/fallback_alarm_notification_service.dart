import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/services/notification_service.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/entities/delivery_observation.dart';

abstract interface class FallbackAlarmNotificationService {
  Future<AlarmPermissionState> checkPermission();

  Future<AlarmPermissionState> requestPermission();

  Future<AlarmPermissionState> checkExactTimingPermission();

  Future<AlarmPermissionState> requestExactTimingPermission();

  Future<NotificationTiming> scheduleFallbackAlarm(ScheduledAlarmRecord record);

  Future<void> cancelFallbackAlarm(ScheduledAlarmRecord record);

  Future<DeliveryObservation> observePending();
}

@Singleton(as: FallbackAlarmNotificationService)
class FallbackAlarmNotificationServiceImpl
    implements FallbackAlarmNotificationService {
  FallbackAlarmNotificationServiceImpl({
    @ignoreParam NotificationService? notificationService,
  }) : _notificationService =
           notificationService ?? NotificationService.instance;

  final NotificationService _notificationService;

  @override
  Future<DeliveryObservation> observePending() =>
      _notificationService.observePendingScheduleNotifications();

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
  Future<AlarmPermissionState> checkExactTimingPermission() =>
      _notificationService.checkExactTimingPermission();

  @override
  Future<AlarmPermissionState> requestExactTimingPermission() =>
      _notificationService.requestExactTimingPermission();

  @override
  Future<NotificationTiming> scheduleFallbackAlarm(
    ScheduledAlarmRecord record,
  ) {
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
