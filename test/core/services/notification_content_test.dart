import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/services/notification_content.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';

void main() {
  test('remote notification content prefers FCM notification text', () {
    final content = remoteNotificationDisplayContent(
      notificationTitle: 'Server title',
      notificationBody: 'Server body',
      data: const {
        'title': 'Data title',
        'body': 'Data body',
        'scheduleId': 'schedule-1',
      },
    );

    expect(content?.title, 'Server title');
    expect(content?.body, 'Server body');
    expect(jsonDecode(content!.payload), {
      'title': 'Data title',
      'body': 'Data body',
      'scheduleId': 'schedule-1',
    });
  });

  test(
    'remote notification content accepts backend title and body variants',
    () {
      expect(
        remoteNotificationDisplayContent(
          data: const {'Title': 'Upper title', 'Content': 'Upper content'},
        )?.title,
        'Upper title',
      );
      expect(
        remoteNotificationDisplayContent(
          data: const {'title': 'Lower title', 'content': 'Lower content'},
        )?.body,
        'Lower content',
      );
      expect(
        remoteNotificationDisplayContent(
          data: const {'Body': 'Body only'},
        )?.title,
        '알림',
      );
      expect(remoteNotificationDisplayContent(data: const {}), isNull);
    },
  );

  test('local notification payloads are encoded only when present', () {
    expect(encodeLocalNotificationPayload(null), isNull);
    expect(
      jsonDecode(
        encodeLocalNotificationPayload(const {
          'type': 'preparation_step',
          'scheduleId': 'schedule-1',
        })!,
      ),
      {'type': 'preparation_step', 'scheduleId': 'schedule-1'},
    );
  });

  test('preparation step notification content carries routing payload', () {
    expect(
      preparationStepNotificationTitle(
        scheduleName: 'Morning meeting',
        preparationName: 'Pack bag',
      ),
      '[Morning meeting] Pack bag',
    );
    expect(preparationStepNotificationBody(languageCode: 'ko'), '이어서 준비하세요.');
    expect(
      preparationStepNotificationBody(languageCode: 'en'),
      'Continue preparing',
    );
    expect(
      preparationStepNotificationPayload(
        scheduleId: 'schedule-1',
        stepId: 'step-2',
      ),
      {
        'type': 'preparation_step',
        'scheduleId': 'schedule-1',
        'stepId': 'step-2',
      },
    );
  });

  test(
    'fallback alarm notification uses explicit id or stable schedule id',
    () {
      final explicit = _record(fallbackNotificationId: 42);
      final implicit = _record(fallbackNotificationId: null);

      expect(fallbackNotificationIdForRecord(explicit), 42);
      expect(
        fallbackNotificationIdForRecord(implicit),
        stableAlarmId('schedule-1'),
      );
      expect(
        fallbackAlarmNotificationBody(languageCode: 'ko'),
        '준비를 시작할 시간입니다.',
      );
      expect(
        fallbackAlarmNotificationBody(languageCode: 'en'),
        'It is time to get ready.',
      );
    },
  );
}

ScheduledAlarmRecord _record({required int? fallbackNotificationId}) {
  return ScheduledAlarmRecord(
    scheduleId: 'schedule-1',
    alarmTime: DateTime.utc(2026, 5, 15, 8),
    preparationStartTime: DateTime.utc(2026, 5, 15, 8, 5),
    scheduleFingerprint: 'fingerprint',
    provider: AlarmProvider.localNotification,
    scheduleTitle: 'Morning meeting',
    payload: const {'type': 'schedule_alarm'},
    fallbackNotificationId: fallbackNotificationId,
  );
}
