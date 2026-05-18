import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/services/notification_routing.dart';

void main() {
  group('localizedNotificationText', () {
    test('selects Korean text only for Korean locale', () {
      expect(
        localizedNotificationText(languageCode: 'ko', ko: '준비', en: 'Ready'),
        '준비',
      );
      expect(
        localizedNotificationText(languageCode: 'en', ko: '준비', en: 'Ready'),
        'Ready',
      );
    });
  });

  group('isScheduleAlarmPayload', () {
    test(
      'detects native alarm payloads by type, version, and prompt variant',
      () {
        expect(isScheduleAlarmPayload(null), isFalse);
        expect(
          isScheduleAlarmPayload(const {'type': 'schedule_alarm'}),
          isTrue,
        );
        expect(
          isScheduleAlarmPayload(const {'alarmLaunchPayloadVersion': 1}),
          isTrue,
        );
        expect(
          isScheduleAlarmPayload(const {
            'promptVariant': 'alarm',
            'scheduleId': 'schedule-1',
          }),
          isTrue,
        );
        expect(
          isScheduleAlarmPayload(const {'promptVariant': 'alarm'}),
          isFalse,
        );
        expect(
          isScheduleAlarmPayload(const {'type': 'preparation_step'}),
          isFalse,
        );
      },
    );
  });

  group('isScheduleAlarmMessagePayload', () {
    test('detects native alarm push messages from data or known titles', () {
      expect(
        isScheduleAlarmMessagePayload(
          data: const {'type': 'schedule_alarm'},
          title: null,
        ),
        isTrue,
      );
      expect(
        isScheduleAlarmMessagePayload(data: const {}, title: '약속 알림'),
        isTrue,
      );
      expect(
        isScheduleAlarmMessagePayload(data: const {}, title: 'Schedule alarm'),
        isTrue,
      );
      expect(
        isScheduleAlarmMessagePayload(
          data: const {'type': 'announcement'},
          title: 'General',
        ),
        isFalse,
      );
    });
  });

  group('notificationRouteForPayloadString', () {
    test('routes full schedule alarm payload to the schedule start screen', () {
      final payload = jsonEncode({
        'type': 'schedule_alarm',
        'scheduleId': 'schedule-1',
        'title': 'Morning meeting',
      });

      final target = notificationRouteForPayloadString(payload);

      expect(target, isNotNull);
      expect(target!.path, '/scheduleStart');
      expect(target.extra, {
        'type': 'schedule_alarm',
        'scheduleId': 'schedule-1',
        'title': 'Morning meeting',
      });
    });

    test('routes five-minute prompts as early-start schedule starts', () {
      final target = notificationRouteForPayloadString(
        jsonEncode({
          'type': 'schedule_5min_before',
          'scheduleId': 'schedule-1',
        }),
      );

      expect(
        target,
        const NotificationRouteTarget(
          '/scheduleStart',
          extra: {'promptVariant': 'earlyStart'},
        ),
      );
    });

    test('routes schedule and preparation updates to the alarm screen', () {
      expect(
        notificationRouteForPayloadString(
          jsonEncode({'type': 'schedule_changed'}),
        ),
        const NotificationRouteTarget('/alarmScreen'),
      );
      expect(
        notificationRouteForPayloadString(
          jsonEncode({'type': 'preparation_step'}),
        ),
        const NotificationRouteTarget('/alarmScreen'),
      );
      expect(
        notificationRouteForPayloadString(jsonEncode({'scheduleId': 's-1'})),
        const NotificationRouteTarget('/alarmScreen'),
      );
    });

    test('ignores null, invalid, and unrelated payloads', () {
      expect(notificationRouteForPayloadString(null), isNull);
      expect(notificationRouteForPayloadString('{bad json'), isNull);
      expect(
        notificationRouteForPayloadString(jsonEncode(['not', 'a map'])),
        isNull,
      );
      expect(
        notificationRouteForPayloadString(jsonEncode({'type': 'announcement'})),
        isNull,
      );
    });
  });

  group('notificationRouteForData', () {
    test('routes background message data with the same notification rules', () {
      expect(
        notificationRouteForData(const {
          'type': 'schedule_alarm',
          'scheduleId': 'schedule-2',
        }),
        const NotificationRouteTarget(
          '/scheduleStart',
          extra: {'type': 'schedule_alarm', 'scheduleId': 'schedule-2'},
        ),
      );
      expect(
        notificationRouteForData(const {'type': 'preparation_step'}),
        const NotificationRouteTarget('/alarmScreen'),
      );
      expect(notificationRouteForData(const {'type': 'chat'}), isNull);
    });
  });
}
