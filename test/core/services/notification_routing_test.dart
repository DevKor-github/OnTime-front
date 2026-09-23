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
      'detects native alarm payloads without suppressing schedule notifications',
      () {
        expect(isScheduleAlarmPayload(null), isFalse);
        expect(
          isScheduleAlarmPayload(const {'type': 'schedule_alarm'}),
          isTrue,
        );
        expect(
          isScheduleAlarmPayload(const {
            'type': 'schedule_notification',
            'alarmLaunchPayloadVersion': 1,
          }),
          isFalse,
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

  group('notificationRouteForPayloadString', () {
    test(
      'routes schedule notification payload to the schedule start screen',
      () {
        final payload = jsonEncode({
          'type': 'schedule_notification',
          'scheduleId': 'schedule-1',
          'title': 'Morning meeting',
        });

        final target = notificationRouteForPayloadString(payload);

        expect(target, isNotNull);
        expect(target!.path, '/scheduleStart');
        expect(target.extra, {
          'type': 'schedule_notification',
          'scheduleId': 'schedule-1',
          'alarmLaunchPayloadVersion': '9',
          'promptVariant': 'notification',
        });
      },
    );

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

  test('invalid schedule hints never route to nearest preparation', () {
    for (final bad in [null, 42, '', ' ', 'x' * 513, 'a\u0000b']) {
      for (final type in ['schedule_alarm', 'schedule_notification']) {
        expect(
          notificationRouteForData({'type': type, 'scheduleId': bad}),
          isNull,
        );
      }
    }
  });

  group('notificationRouteForData', () {
    test('routes decoded local payload data with the same rules', () {
      expect(
        notificationRouteForData(const {
          'type': 'schedule_notification',
          'scheduleId': 'schedule-2',
        }),
        const NotificationRouteTarget(
          '/scheduleStart',
          extra: {
            'type': 'schedule_notification',
            'scheduleId': 'schedule-2',
            'alarmLaunchPayloadVersion': '9',
            'promptVariant': 'notification',
          },
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
