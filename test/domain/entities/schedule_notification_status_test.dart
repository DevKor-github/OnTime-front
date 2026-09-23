import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/entities/schedule_notification_status.dart';
import 'package:on_time_front/domain/entities/scheduled_notification_content.dart';

void main() {
  final now = DateTime.utc(2030);
  ScheduleNotificationStatus status(
    List<ScheduledAlarmRecord> records, {
    bool enabled = true,
    bool canDeliver = true,
    AlarmReconciliationStatus resultStatus = AlarmReconciliationStatus.armed,
    List<String>? armedIds,
  }) => scheduleNotificationStatus(
    enabled: enabled,
    canDeliver: canDeliver,
    records: records,
    now: now,
    result: AlarmReconciliationResult(
      status: resultStatus,
      nativeAlarmProvider: AlarmProvider.none,
      fallbackProvider: AlarmProvider.localNotification,
      armedScheduleIds:
          armedIds ?? records.map((record) => record.scheduleId).toList(),
      skippedScheduleCount: 0,
      failures: const [],
      scheduleWindowStart: now,
      scheduleWindowEnd: now.add(const Duration(days: 1)),
      alarmCoverageStart: now,
      alarmCoverageEnd: now.add(const Duration(days: 1)),
    ),
  );

  test('only all successful exact receipts produce precise status', () {
    final exact = _record('one', NotificationTiming.exact);
    expect(status([exact]), ScheduleNotificationStatus.precise);
    expect(
      status([exact, _record('two', NotificationTiming.approximate)]),
      ScheduleNotificationStatus.mixed,
    );
    expect(
      status([_record('one', NotificationTiming.approximate)]),
      ScheduleNotificationStatus.approximate,
    );
    expect(
      status([_record('one', null)]),
      ScheduleNotificationStatus.incomplete,
    );
    expect(
      status([exact], resultStatus: AlarmReconciliationStatus.partial),
      ScheduleNotificationStatus.incomplete,
    );
    expect(
      status([exact.copyWith(cancellationPending: true)]),
      ScheduleNotificationStatus.incomplete,
    );
    expect(
      status([exact], armedIds: ['one', 'failed']),
      ScheduleNotificationStatus.incomplete,
    );
  });

  test(
    'off and denied display take precedence over stored exact registrations',
    () {
      final records = [_record('one', NotificationTiming.exact)];
      expect(status(records, enabled: false), ScheduleNotificationStatus.off);
      expect(
        status(records, canDeliver: false),
        ScheduleNotificationStatus.permissionNeeded,
      );
    },
  );

  test('no future registrations never becomes precise from capability', () {
    expect(status([]), ScheduleNotificationStatus.empty);
    expect(
      status([
        _record(
          'past',
          NotificationTiming.exact,
        ).copyWith(alarmTime: DateTime.utc(2029)),
      ], armedIds: []),
      ScheduleNotificationStatus.empty,
    );
  });

  test(
    'iOS alarm and notification language remains capability appropriate',
    () {
      final record = _record('one', NotificationTiming.platformDefault);
      expect(status([record]), ScheduleNotificationStatus.notification);
      expect(
        status([record.copyWith(provider: AlarmProvider.iosAlarmKit)]),
        ScheduleNotificationStatus.alarm,
      );
    },
  );
}

ScheduledAlarmRecord _record(String id, NotificationTiming? timing) {
  final content = ScheduledNotificationContent(
    scheduleTitle: 'OnTime',
    detailed: false,
    languageCode: 'en',
  );
  return ScheduledAlarmRecord(
    scheduleId: id,
    alarmTime: DateTime.utc(2030, 1, 1, 1),
    preparationStartTime: DateTime.utc(2030, 1, 1, 1),
    scheduleFingerprint: 'safe',
    provider: AlarmProvider.localNotification,
    scheduleTitle: 'OnTime',
    payload: const {},
    contentDigest: content.digest,
    contentVersion: ScheduledNotificationContent.schemaVersion,
    contentLanguageCode: 'en',
    notificationContent: content,
    notificationTiming: timing,
  );
}
