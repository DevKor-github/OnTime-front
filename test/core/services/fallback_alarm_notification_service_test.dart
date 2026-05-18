import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/services/fallback_alarm_notification_service.dart';
import 'package:on_time_front/core/services/notification_service.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';

void main() {
  test(
    'permission checks map Firebase authorization to alarm permission',
    () async {
      final notificationService = _FakeNotificationService(
        checkStatus: AuthorizationStatus.provisional,
        requestStatus: AuthorizationStatus.denied,
      );
      final service = FallbackAlarmNotificationServiceImpl(
        notificationService: notificationService,
      );

      expect(await service.checkPermission(), AlarmPermissionState.granted);
      expect(await service.requestPermission(), AlarmPermissionState.denied);
      expect(notificationService.checkCount, 1);
      expect(notificationService.requestCount, 1);
    },
  );

  test('not-determined notification status remains recoverable', () async {
    final service = FallbackAlarmNotificationServiceImpl(
      notificationService: _FakeNotificationService(
        checkStatus: AuthorizationStatus.notDetermined,
        requestStatus: AuthorizationStatus.notDetermined,
      ),
    );

    expect(await service.checkPermission(), AlarmPermissionState.notDetermined);
    expect(
      await service.requestPermission(),
      AlarmPermissionState.notDetermined,
    );
  });

  test(
    'schedules and cancels fallback alarms through notification service',
    () async {
      final notificationService = _FakeNotificationService(
        checkStatus: AuthorizationStatus.authorized,
        requestStatus: AuthorizationStatus.authorized,
      );
      final service = FallbackAlarmNotificationServiceImpl(
        notificationService: notificationService,
      );
      final record = _record(fallbackNotificationId: null);

      await service.scheduleFallbackAlarm(record);
      await service.cancelFallbackAlarm(record);

      expect(notificationService.scheduledRecords, [record]);
      expect(notificationService.cancelledIds, [stableAlarmId('schedule-1')]);
    },
  );
}

ScheduledAlarmRecord _record({int? fallbackNotificationId}) {
  return ScheduledAlarmRecord(
    scheduleId: 'schedule-1',
    alarmTime: DateTime.utc(2026, 5, 15, 8),
    preparationStartTime: DateTime.utc(2026, 5, 15, 8, 5),
    scheduleFingerprint: 'fingerprint',
    provider: AlarmProvider.localNotification,
    scheduleTitle: 'Morning meeting',
    payload: const {'type': 'schedule_alarm', 'scheduleId': 'schedule-1'},
    fallbackNotificationId: fallbackNotificationId,
  );
}

class _FakeNotificationService implements NotificationService {
  _FakeNotificationService({
    required this.checkStatus,
    required this.requestStatus,
  });

  final AuthorizationStatus checkStatus;
  final AuthorizationStatus requestStatus;
  final scheduledRecords = <ScheduledAlarmRecord>[];
  final cancelledIds = <int>[];
  int checkCount = 0;
  int requestCount = 0;

  @override
  Future<AuthorizationStatus> checkNotificationPermission() async {
    checkCount += 1;
    return checkStatus;
  }

  @override
  Future<AuthorizationStatus> requestPermission() async {
    requestCount += 1;
    return requestStatus;
  }

  @override
  Future<void> scheduleFallbackAlarm(ScheduledAlarmRecord record) async {
    scheduledRecords.add(record);
  }

  @override
  Future<void> cancelFallbackNotification(int notificationId) async {
    cancelledIds.add(notificationId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
