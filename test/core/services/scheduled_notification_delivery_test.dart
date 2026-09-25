import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/services/alarm_scheduler_service.dart';
import 'package:on_time_front/core/services/notification_service.dart';
import 'package:on_time_front/data/models/scheduled_alarm_record_model.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/entities/scheduled_notification_content.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const notificationChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const nativeChannel = MethodChannel('on_time_front/native_alarm');
  final calls = <MethodCall>[];
  final nativeCalls = <MethodCall>[];
  late NotificationService service;

  setUp(() {
    calls.clear();
    nativeCalls.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    IOSFlutterLocalNotificationsPlugin.registerWith();
    tz.initializeTimeZones();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationChannel, (call) async {
          calls.add(call);
          if (call.method == 'checkPermissions') return {'isEnabled': true};
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeChannel, (call) async {
          nativeCalls.add(call);
          return null;
        });
    service = NotificationService.test(
      localNotifications: FlutterLocalNotificationsPlugin(),
      // The content was fixed before delivery. A later OS locale read must
      // never silently change the body while retaining the old digest.
      localeProvider: () => 'en',
      isIOSOverride: true,
      isFlutterLocalNotificationsInitialized: true,
      isTimezoneInitialized: true,
    );
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeChannel, null);
  });

  for (final language in ['ko', 'en']) {
    for (final detailed in [false, true]) {
      test(
        'native and fallback send the same $language detailed=$detailed snapshot after persistence',
        () async {
          final original = _record(language: language, detailed: detailed);
          final json = ScheduledAlarmRecordModel(original).toJson();
          expect(json, isNot(contains('body')));
          expect(json, isNot(contains('notificationContent')));
          final restored = ScheduledAlarmRecordModel.fromJson(json).record;
          expect(restored.notificationContent, isNull);
          expect(restored.deliveryContent.digest, original.contentDigest);
          await service.scheduleFallbackAlarm(restored);
          await AlarmSchedulerService().scheduleNativeAlarm(
            restored.copyWith(provider: AlarmProvider.iosAlarmKit),
          );
          final fallback =
              calls
                      .singleWhere((call) => call.method == 'zonedSchedule')
                      .arguments
                  as Map;
          final native = nativeCalls.single.arguments as Map;
          expect(fallback['title'], original.deliveryContent.title);
          expect(fallback['body'], original.deliveryContent.body);
          expect(native['title'], fallback['title']);
          expect(native['body'], fallback['body']);
          expect(jsonDecode(fallback['payload'] as String), {
            'type': 'schedule_notification',
            'scheduleId': original.scheduleId,
            'alarmLaunchPayloadVersion': '10',
            'promptVariant': 'notification',
          });
          expect(native['payload'], jsonDecode(fallback['payload'] as String));
          if (!detailed) {
            expect(
              '${fallback['title']} ${fallback['body']}',
              isNot(contains('Sensitive appointment')),
            );
            expect(
              '${fallback['title']} ${fallback['body']}',
              isNot(contains('Asia/Seoul')),
            );
          }
        },
      );
    }
  }

  test(
    'legacy and corrupted content cannot bypass reconciliation at either provider',
    () async {
      final valid = _record(language: 'ko', detailed: true);
      for (final json in [
        ScheduledAlarmRecordModel(valid).toJson()..remove('contentDigest'),
        ScheduledAlarmRecordModel(valid).toJson()..remove('contentVersion'),
        ScheduledAlarmRecordModel(valid).toJson()
          ..remove('contentLanguageCode'),
        ScheduledAlarmRecordModel(valid).toJson()..['contentDigest'] = 'wrong',
        ScheduledAlarmRecordModel(valid).toJson()
          ..['contentLanguageCode'] = 'en',
        ScheduledAlarmRecordModel(valid).toJson()
          ..['cancellationPending'] = true,
      ]) {
        final legacy = ScheduledAlarmRecordModel.fromJson(json).record;
        await expectLater(
          service.scheduleFallbackAlarm(legacy),
          throwsA(isA<AlarmSchedulingException>()),
        );
        await expectLater(
          AlarmSchedulerService().scheduleNativeAlarm(legacy),
          throwsA(isA<AlarmSchedulingException>()),
        );
      }
      expect(calls, isEmpty);
      expect(nativeCalls, isEmpty);
    },
  );

  test(
    'targeted cancel uses the plugin API for pending and presented IDs, never cancelAll',
    () async {
      await service.cancelFallbackNotification(42);
      expect(calls.map((call) => call.method), [
        'cancel',
        'pendingNotificationRequests',
      ]);
      expect(calls.first.arguments, 42);
      // This verifies the plugin boundary. Device notification-center read-back
      // remains necessary to prove that an actual displayed item was removed.
    },
  );

  test('targeted cancellation errors are visible to reconciliation', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationChannel, (_) async {
          throw PlatformException(code: 'cancellation_unavailable');
        });
    await expectLater(
      service.cancelFallbackNotification(42),
      throwsA(isA<PlatformException>()),
    );
  });
}

ScheduledAlarmRecord _record({
  required String language,
  required bool detailed,
}) {
  final content = ScheduledNotificationContent(
    scheduleTitle: 'Sensitive appointment',
    detailed: detailed,
    languageCode: language,
    displayTimeZone: 'Asia/Seoul',
  );
  return ScheduledAlarmRecord(
    scheduleId: 'owned',
    alarmTime: DateTime.utc(2030, 1, 1),
    preparationStartTime: DateTime.utc(2030, 1, 1, 0, 5),
    scheduleFingerprint: 'fixture',
    fallbackNotificationId: 42,
    provider: AlarmProvider.localNotification,
    scheduleTitle: content.title,
    payload: {
      'type': 'schedule_notification',
      'scheduleId': 'owned',
      'detailedNotificationContent': detailed.toString(),
      if (detailed) 'notificationTimeZone': 'Asia/Seoul',
    },
    contentDigest: content.digest,
    contentVersion: ScheduledNotificationContent.schemaVersion,
    contentLanguageCode: content.languageCode,
    notificationContent: content,
  );
}
