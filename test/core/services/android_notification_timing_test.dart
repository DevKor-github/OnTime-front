import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/services/notification_service.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/entities/scheduled_notification_content.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  const permissions = MethodChannel('flutter.baseflow.com/permissions/methods');
  final calls = <MethodCall>[];
  var exactAllowed = true;
  var displayAllowed = true;
  var queryUnavailable = false;
  final errors = <String>[];
  late NotificationService service;

  setUp(() {
    exactAllowed = true;
    displayAllowed = true;
    queryUnavailable = false;
    errors.clear();
    calls.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      permissions,
      (_) async => displayAllowed ? 1 : 0,
    );
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'canScheduleExactNotifications') {
        if (queryUnavailable) throw PlatformException(code: 'unavailable');
        return exactAllowed;
      }
      if (call.method == 'requestExactAlarmsPermission') return true;
      if (call.method == 'zonedSchedule' && errors.isNotEmpty) {
        throw PlatformException(code: errors.removeAt(0));
      }
      return null;
    });
    service = NotificationService.test(
      localNotifications: FlutterLocalNotificationsPlugin(),
      isIOSOverride: false,
      isAndroidOverride: true,
      isFlutterLocalNotificationsInitialized: true,
    );
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(permissions, null);
  });

  List<Map> scheduled() => calls
      .where((call) => call.method == 'zonedSchedule')
      .map((call) => call.arguments as Map)
      .toList();

  test(
    'fresh permission chooses exact then approximate without full-screen',
    () async {
      expect(
        await service.scheduleFallbackAlarm(_record()),
        NotificationTiming.exact,
      );
      exactAllowed = false;
      expect(
        await service.scheduleFallbackAlarm(_record()),
        NotificationTiming.approximate,
      );
      expect(
        scheduled().map(
          (call) => (call['platformSpecifics'] as Map)['scheduleMode'],
        ),
        ['exactAllowWhileIdle', 'inexactAllowWhileIdle'],
      );
      expect(
        calls.where((call) => call.method == 'canScheduleExactNotifications'),
        hasLength(2),
      );
      for (final call in scheduled()) {
        expect((call['platformSpecifics'] as Map)['fullScreenIntent'], isFalse);
        expect(jsonDecode(call['payload'] as String), {
          'type': 'schedule_notification',
          'scheduleId': 'one',
          'alarmLaunchPayloadVersion': alarmLaunchPayloadVersion,
          'promptVariant': 'notification',
        });
      }
      expect(
        calls.where((call) => call.method == 'requestExactAlarmsPermission'),
        isEmpty,
      );
    },
  );

  test(
    'explicit exact denial retries once and returns actual approximate receipt',
    () async {
      errors.add('exact_alarms_not_permitted');
      expect(
        await service.scheduleFallbackAlarm(_record()),
        NotificationTiming.approximate,
      );
      expect(
        scheduled().map(
          (call) => (call['platformSpecifics'] as Map)['scheduleMode'],
        ),
        ['exactAllowWhileIdle', 'inexactAllowWhileIdle'],
      );
      expect(scheduled()[0]['id'], scheduled()[1]['id']);
    },
  );

  test(
    'unrelated provider error is never converted to approximate success',
    () async {
      errors.add('provider_unavailable');
      await expectLater(
        service.scheduleFallbackAlarm(_record()),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'provider_unavailable',
          ),
        ),
      );
      expect(scheduled(), hasLength(1));
    },
  );

  test(
    'failed approximate retry stays failed and is not retried again',
    () async {
      errors.addAll(['exact_alarms_not_permitted', 'provider_unavailable']);
      await expectLater(
        service.scheduleFallbackAlarm(_record()),
        throwsA(isA<PlatformException>()),
      );
      expect(scheduled(), hasLength(2));
    },
  );

  test(
    'unknown timing permission uses approximate rather than claiming exact',
    () async {
      queryUnavailable = true;
      expect(
        await service.scheduleFallbackAlarm(_record()),
        NotificationTiming.approximate,
      );
      expect(
        (scheduled().single['platformSpecifics'] as Map)['scheduleMode'],
        'inexactAllowWhileIdle',
      );
    },
  );

  test('display denial blocks scheduling even with exact access', () async {
    displayAllowed = false;
    await expectLater(
      service.scheduleFallbackAlarm(_record()),
      throwsA(isA<AlarmSchedulingException>()),
    );
    expect(scheduled(), isEmpty);
  });

  test(
    'settings response is not proof of a grant: permission is reread',
    () async {
      exactAllowed = false;
      expect(
        await service.requestExactTimingPermission(),
        AlarmPermissionState.denied,
      );
      expect(calls.map((call) => call.method), [
        'requestExactAlarmsPermission',
        'canScheduleExactNotifications',
      ]);
    },
  );

  test(
    'iOS timing access is unsupported without calling Android plugin',
    () async {
      service = NotificationService.test(
        localNotifications: FlutterLocalNotificationsPlugin(),
        isIOSOverride: true,
        isAndroidOverride: false,
      );
      expect(
        await service.checkExactTimingPermission(),
        AlarmPermissionState.unsupported,
      );
      expect(
        await service.requestExactTimingPermission(),
        AlarmPermissionState.unsupported,
      );
      expect(calls, isEmpty);
    },
  );
}

ScheduledAlarmRecord _record() {
  final content = ScheduledNotificationContent(
    scheduleTitle: 'OnTime',
    detailed: false,
    languageCode: 'en',
  );
  return ScheduledAlarmRecord(
    scheduleId: 'one',
    alarmTime: DateTime.utc(2030),
    preparationStartTime: DateTime.utc(2030),
    scheduleFingerprint: 'fingerprint',
    provider: AlarmProvider.localNotification,
    scheduleTitle: 'OnTime',
    payload: const {
      'type': 'schedule_notification',
      'scheduleId': 'one',
      'alarmLaunchPayloadVersion': alarmLaunchPayloadVersion,
    },
    contentDigest: content.digest,
    contentVersion: ScheduledNotificationContent.schemaVersion,
    contentLanguageCode: 'en',
    notificationContent: content,
  );
}
