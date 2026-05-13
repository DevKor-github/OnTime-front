import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/data/models/alarm_device_model.dart';
import 'package:on_time_front/data/models/alarm_settings_model.dart';
import 'package:on_time_front/data/models/alarm_status_report_model.dart';
import 'package:on_time_front/data/models/alarm_window_schedule_model.dart';
import 'package:on_time_front/data/models/scheduled_alarm_record_model.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';

void main() {
  test('alarm settings maps backend defaults and update request JSON', () {
    final model = AlarmSettingsModel.fromJson({
      'alarmsEnabled': false,
      'updatedAt': '2026-05-05T09:00:00.000',
    });

    expect(model.toEntity().alarmsEnabled, isFalse);
    expect(model.toEntity().defaultAlarmOffsetMinutes, 5);
    expect(const UpdateAlarmSettingsRequestModel(alarmsEnabled: true).toJson(),
        {'alarmsEnabled': true});
  });

  test('device info serializes provider wire values', () {
    final json = AlarmDeviceInfoModel.fromEntity(
      const AlarmDeviceInfo(
        deviceId: 'device-1',
        platform: 'android',
        appVersion: '1.0.0',
        osVersion: 'android-35',
        supportsNativeAlarm: true,
        nativeAlarmProvider: AlarmProvider.androidAlarmManager,
        fallbackProvider: AlarmProvider.localNotification,
      ),
    ).toJson();

    expect(json['deviceId'], 'device-1');
    expect(json['nativeAlarmProvider'], 'androidAlarmManager');
    expect(json['fallbackProvider'], 'localNotification');
  });

  test('alarm window schedule maps backend schedule and preparation JSON', () {
    final entity = AlarmWindowScheduleModel.fromJson({
      'scheduleId': 'schedule-1',
      'scheduleName': 'Morning meeting',
      'place': {
        'placeId': 'place-1',
        'placeName': 'Office',
      },
      'scheduleTime': '2026-05-05T10:00:00.000',
      'moveTime': 20,
      'scheduleSpareTime': 10,
      'doneStatus': 'NOT_ENDED',
      'startedAt': '2026-05-05T09:00:00.000Z',
      'finishedAt': null,
      'preparations': [
        {
          'preparationId': 'prep-1',
          'preparationName': 'Shower',
          'preparationTime': 15,
          'nextPreparationId': 'prep-2',
        },
      ],
    }).toEntity();

    expect(entity.id, 'schedule-1');
    expect(entity.place.placeName, 'Office');
    expect(entity.doneStatus, ScheduleDoneStatus.notEnded);
    expect(entity.startedAt, DateTime.parse('2026-05-05T09:00:00.000Z'));
    expect(entity.finishedAt, isNull);
    expect(entity.moveTime, const Duration(minutes: 20));
    expect(entity.preparation.preparationStepList.single.nextPreparationId,
        'prep-2');
  });

  test('status report and registry record serialize alarm contract payloads',
      () {
    final now = DateTime.utc(2026, 5, 5, 9, 0, 0, 123, 456);
    final statusJson = AlarmStatusReportModel(
      AlarmStatusReport(
        deviceId: 'device-1',
        reconciledAt: now,
        scheduleWindowStart: now,
        scheduleWindowEnd: now.add(const Duration(days: 8)),
        alarmCoverageStart: now,
        alarmCoverageEnd: now.add(const Duration(days: 7)),
        status: AlarmReconciliationStatus.partial,
        permissionIssue: AlarmPermissionIssue.notificationPermissionDenied,
        nativeAlarmProvider: AlarmProvider.none,
        fallbackProvider: AlarmProvider.localNotification,
        armedScheduleCount: 1,
        armedScheduleIds: const ['schedule-1'],
        skippedScheduleCount: 2,
        failures: const [
          AlarmFailure(
            scheduleId: 'schedule-2',
            reason: AlarmFailureReason.platformError,
            message: 'failed',
          ),
        ],
      ),
    ).toJson();

    expect(statusJson['status'], 'partial');
    expect(statusJson['permissionIssue'], 'notificationPermissionDenied');
    expect(statusJson['reconciledAt'], '2026-05-05T09:00:00.123Z');
    expect(statusJson['armedScheduleIds'], ['schedule-1']);
    expect(
      (statusJson['failures'] as List).single['reason'],
      'platformError',
    );

    final recordJson = ScheduledAlarmRecordModel(
      ScheduledAlarmRecord(
        scheduleId: 'schedule-1',
        alarmTime: now,
        preparationStartTime: now.add(const Duration(minutes: 5)),
        scheduleFingerprint: 'fingerprint',
        nativeAlarmId: 123,
        fallbackNotificationId: 123,
        provider: AlarmProvider.localNotification,
        scheduleTitle: 'Morning meeting',
        payload: const {
          'type': 'schedule_alarm',
          'scheduleId': 'schedule-1',
        },
      ),
    ).toJson();

    final decoded = ScheduledAlarmRecordModel.fromJson(recordJson).record;
    expect(decoded.provider, AlarmProvider.localNotification);
    expect(decoded.payload['type'], 'schedule_alarm');
    expect(decoded.scheduleFingerprint, 'fingerprint');
  });

  test('status report defaults to lower-camel and supports backend enums', () {
    final now = DateTime.utc(2026, 5, 5, 9);
    final model = AlarmStatusReportModel(
      AlarmStatusReport(
        deviceId: 'device-1',
        reconciledAt: now,
        scheduleWindowStart: now,
        scheduleWindowEnd: now.add(const Duration(days: 8)),
        alarmCoverageStart: now,
        alarmCoverageEnd: now.add(const Duration(days: 7)),
        status: AlarmReconciliationStatus.armed,
        nativeAlarmProvider: AlarmProvider.iosAlarmKit,
        fallbackProvider: AlarmProvider.localNotification,
        armedScheduleCount: 1,
        armedScheduleIds: const ['schedule-1'],
        skippedScheduleCount: 0,
        failures: const [],
      ),
    );

    final json = model.toJson();
    expect(json.containsKey('permissionIssue'), isFalse);
    expect(json['reconciledAt'], '2026-05-05T09:00:00.000Z');
    expect(json['status'], 'armed');
    expect(json['nativeAlarmProvider'], 'iosAlarmKit');
    expect(json['fallbackProvider'], 'localNotification');

    final backendJson = model.toJson(
      wireFormat: AlarmStatusReportWireFormat.upperSnake,
    );
    expect(backendJson.containsKey('permissionIssue'), isFalse);
    expect(backendJson['status'], 'ARMED');
    expect(backendJson['nativeAlarmProvider'], 'IOS_ALARM_KIT');
  });
}
