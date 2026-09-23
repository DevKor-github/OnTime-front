import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/services/alarm_scheduler_service.dart';
import 'package:on_time_front/core/services/notification_service.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/entities/delivery_observation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pluginChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const nativeChannel = MethodChannel('on_time_front/native_alarm');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <String>[];
  var pending = <Map<String, Object?>>[];
  var queryFails = false;
  var cancelFails = false;
  var cancelLeavesPending = false;

  NotificationService service({required bool ios}) {
    debugDefaultTargetPlatformOverride = ios
        ? TargetPlatform.iOS
        : TargetPlatform.android;
    if (ios) {
      IOSFlutterLocalNotificationsPlugin.registerWith();
    } else {
      AndroidFlutterLocalNotificationsPlugin.registerWith();
    }
    return NotificationService.test(
      localNotifications: FlutterLocalNotificationsPlugin(),
      isIOSOverride: ios,
      isAndroidOverride: !ios,
      isFlutterLocalNotificationsInitialized: true,
    );
  }

  setUp(() {
    calls.clear();
    pending = [];
    queryFails = false;
    cancelFails = false;
    cancelLeavesPending = false;
    messenger.setMockMethodCallHandler(pluginChannel, (call) async {
      calls.add(call.method);
      if (call.method == 'pendingNotificationRequests') {
        if (queryFails) {
          throw PlatformException(code: 'read_error');
        }
        return pending;
      }
      if (call.method == 'cancel') {
        if (cancelFails) {
          throw PlatformException(code: 'cancel_error');
        }
        if (!cancelLeavesPending) {
          pending.removeWhere(
            (r) =>
                r['id'] ==
                (call.arguments is Map
                    ? (call.arguments as Map)['id']
                    : call.arguments),
          );
        }
      }
      return null;
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(pluginChannel, null);
    messenger.setMockMethodCallHandler(nativeChannel, null);
  });

  for (final ios in [false, true]) {
    test(
      '${ios ? 'iOS OS' : 'Android cache'} observation preserves source and minimal ownership',
      () async {
        pending = [
          {
            'id': 42,
            'title': 'PRIVATE TITLE',
            'body': 'PRIVATE BODY',
            'payload': jsonEncode({
              'type': 'schedule_notification',
              'scheduleId': 'one',
              'untrusted': 'SECRET',
            }),
          },
          {
            'id': 99,
            'payload': jsonEncode({
              'type': 'step_notification',
              'scheduleId': 'other',
            }),
          },
          {'id': 98, 'payload': '{broken'},
        ];
        final observed = await service(
          ios: ios,
        ).observePendingScheduleNotifications();
        expect(observed.available, true);
        expect(observed.isOsObservation, ios);
        expect(
          observed.source,
          ios
              ? DeliveryObservationSource.iosNotificationCenter
              : DeliveryObservationSource.androidPluginCache,
        );
        expect(observed.entries.map((e) => e.scheduleId), ['one', null, null]);
        expect(observed.presence(_record()), DeliveryPresence.present);
        expect(
          observed.presence(_record().copyWith(fallbackNotificationId: 123)),
          DeliveryPresence.absent,
        );
      },
    );

    test(
      '${ios ? 'iOS' : 'Android'} read failure is unknown, not absent',
      () async {
        queryFails = true;
        final observed = await service(
          ios: ios,
        ).observePendingScheduleNotifications();
        expect(observed.presence(_record()), DeliveryPresence.unknown);
        expect(observed.available, false);
      },
    );

    test(
      '${ios ? 'iOS' : 'Android'} cancel needs public success and post read-back',
      () async {
        pending = [
          {'id': 42},
          {'id': 99},
        ];
        await service(ios: ios).cancelFallbackNotification(42);
        expect(pending.map((r) => r['id']), [99]);
        expect(calls, ['cancel', 'pendingNotificationRequests']);
      },
    );

    test(
      '${ios ? 'iOS' : 'Android'} cache absence does not hide cancel failure',
      () async {
        cancelFails = true;
        await expectLater(
          service(ios: ios).cancelFallbackNotification(42),
          throwsA(isA<PlatformException>()),
        );
        expect(calls, ['cancel']);
      },
    );

    test(
      '${ios ? 'iOS' : 'Android'} remaining ID and failed post query are unconfirmed cancellations',
      () async {
        final notifications = service(ios: ios);
        pending = [
          {'id': 42},
        ];
        cancelLeavesPending = true;
        await expectLater(
          notifications.cancelFallbackNotification(42),
          throwsA(isA<AlarmSchedulingException>()),
        );
        cancelLeavesPending = false;
        queryFails = true;
        await expectLater(
          notifications.cancelFallbackNotification(42),
          throwsA(isA<AlarmSchedulingException>()),
        );
      },
    );
  }

  test(
    'AlarmKit observation rejects unavailable, malformed and unrelated IDs',
    () async {
      final native = AlarmSchedulerService();
      for (final response in [
        null,
        {
          'source': 'iosAlarmKit',
          'scheduleIds': ['other'],
          'unmappedCount': 0,
        },
        {'source': 'iosAlarmKit', 'scheduleIds': [], 'unmappedCount': '0'},
      ]) {
        messenger.setMockMethodCallHandler(
          nativeChannel,
          (_) async => response,
        );
        expect(
          (await native.observePendingNativeAlarms(['one'])).available,
          false,
        );
      }
      messenger.setMockMethodCallHandler(
        nativeChannel,
        (_) async => throw PlatformException(code: 'observationFailed'),
      );
      expect(
        (await native.observePendingNativeAlarms(['one'])).presence(_record()),
        DeliveryPresence.unknown,
      );
    },
  );

  test(
    'AlarmKit already absent is idempotent; present cancel requires fresh absence',
    () async {
      var hasNative = false;
      var failReadAfterCancel = false;
      var didCancel = false;
      messenger.setMockMethodCallHandler(nativeChannel, (call) async {
        calls.add(call.method);
        if (call.method == 'getPendingNativeAlarms') {
          if (didCancel && failReadAfterCancel) {
            throw PlatformException(code: 'read_error');
          }
          return {
            'source': 'iosAlarmKit',
            'scheduleIds': hasNative ? ['one'] : <String>[],
            'unmappedCount': 0,
          };
        }
        if (call.method == 'cancelNativeAlarm') {
          didCancel = true;
          hasNative = false;
        }
        return null;
      });
      final native = AlarmSchedulerService();
      final record = _record().copyWith(provider: AlarmProvider.iosAlarmKit);
      await native.cancelNativeAlarm(record);
      expect(calls, ['getPendingNativeAlarms']);
      calls.clear();
      hasNative = true;
      await native.cancelNativeAlarm(record);
      expect(calls, [
        'getPendingNativeAlarms',
        'cancelNativeAlarm',
        'getPendingNativeAlarms',
      ]);
      hasNative = true;
      didCancel = false;
      failReadAfterCancel = true;
      await expectLater(
        native.cancelNativeAlarm(record),
        throwsA(isA<AlarmSchedulingException>()),
      );
    },
  );
}

ScheduledAlarmRecord _record() => ScheduledAlarmRecord(
  scheduleId: 'one',
  alarmTime: DateTime.utc(2030),
  preparationStartTime: DateTime.utc(2030),
  scheduleFingerprint: '',
  provider: AlarmProvider.localNotification,
  fallbackNotificationId: 42,
  scheduleTitle: 'OnTime',
  payload: const {},
);
