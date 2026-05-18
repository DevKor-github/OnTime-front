import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/data/models/alarm_device_model.dart';
import 'package:on_time_front/data/models/alarm_settings_model.dart';
import 'package:on_time_front/data/models/alarm_status_report_model.dart';
import 'package:on_time_front/data/models/alarm_window_schedule_model.dart';
import 'package:on_time_front/data/models/scheduled_alarm_record_model.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_with_time_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';

void main() {
  test('alarm settings maps backend defaults and update request JSON', () {
    final model = AlarmSettingsModel.fromJson({
      'alarmsEnabled': false,
      'updatedAt': '2026-05-05T09:00:00.000',
    });

    expect(model.toEntity().alarmsEnabled, isFalse);
    expect(model.toEntity().defaultAlarmOffsetMinutes, 5);
    expect(
      const UpdateAlarmSettingsRequestModel(alarmsEnabled: true).toJson(),
      {'alarmsEnabled': true},
    );
  });

  test('alarm settings round trip preserves explicit backend values', () {
    final updatedAt = DateTime.utc(2026, 5, 5, 9);
    final model = AlarmSettingsModel(
      alarmsEnabled: true,
      defaultAlarmOffsetMinutes: 11,
      updatedAt: updatedAt,
    );

    expect(model.toJson(), {
      'alarmsEnabled': true,
      'defaultAlarmOffsetMinutes': 11,
      'updatedAt': updatedAt.toIso8601String(),
    });

    final fromEntity = AlarmSettingsModel.fromEntity(model.toEntity());
    expect(fromEntity.alarmsEnabled, isTrue);
    expect(fromEntity.defaultAlarmOffsetMinutes, 11);
    expect(fromEntity.updatedAt, updatedAt);
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
      'place': {'placeId': 'place-1', 'placeName': 'Office'},
      'scheduleTime': '2026-05-05T10:00:00.000',
      'moveTime': 20,
      'scheduleSpareTime': 10,
      'doneStatus': 'NOT_ENDED',
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
    expect(entity.moveTime, const Duration(minutes: 20));
    expect(
      entity.preparation.preparationStepList.single.nextPreparationId,
      'prep-2',
    );
  });

  test(
    'status report and registry record serialize alarm contract payloads',
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
          payload: const {'type': 'schedule_alarm', 'scheduleId': 'schedule-1'},
        ),
      ).toJson();

      final decoded = ScheduledAlarmRecordModel.fromJson(recordJson).record;
      expect(decoded.provider, AlarmProvider.localNotification);
      expect(decoded.payload['type'], 'schedule_alarm');
      expect(decoded.scheduleFingerprint, 'fingerprint');
    },
  );

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

  test('status report serializes all upper-snake enum branches', () {
    final now = DateTime.utc(2026, 5, 5, 9);

    Map<String, dynamic> reportJson({
      required AlarmReconciliationStatus status,
      required AlarmProvider nativeProvider,
      required AlarmProvider fallbackProvider,
      AlarmPermissionIssue? permissionIssue,
      AlarmFailureReason failureReason = AlarmFailureReason.unknown,
    }) {
      return AlarmStatusReportModel(
        AlarmStatusReport(
          deviceId: 'device-1',
          reconciledAt: now,
          scheduleWindowStart: now,
          scheduleWindowEnd: now.add(const Duration(days: 8)),
          alarmCoverageStart: now,
          alarmCoverageEnd: now.add(const Duration(days: 7)),
          status: status,
          permissionIssue: permissionIssue,
          nativeAlarmProvider: nativeProvider,
          fallbackProvider: fallbackProvider,
          armedScheduleCount: 0,
          armedScheduleIds: const [],
          skippedScheduleCount: 1,
          failures: [AlarmFailure(reason: failureReason)],
        ),
      ).toJson(wireFormat: AlarmStatusReportWireFormat.upperSnake);
    }

    expect(
      reportJson(
        status: AlarmReconciliationStatus.partial,
        nativeProvider: AlarmProvider.androidAlarmManager,
        fallbackProvider: AlarmProvider.none,
        permissionIssue: AlarmPermissionIssue.nativePermissionDenied,
        failureReason: AlarmFailureReason.preparationLoadFailed,
      ),
      containsPair('status', 'PARTIAL'),
    );
    expect(
      reportJson(
        status: AlarmReconciliationStatus.disabled,
        nativeProvider: AlarmProvider.localNotification,
        fallbackProvider: AlarmProvider.iosAlarmKit,
        permissionIssue: AlarmPermissionIssue.notificationPermissionDenied,
        failureReason: AlarmFailureReason.scheduleInvalid,
      ),
      containsPair('permissionIssue', 'NOTIFICATION_PERMISSION_DENIED'),
    );
    expect(
      reportJson(
        status: AlarmReconciliationStatus.permissionNeeded,
        nativeProvider: AlarmProvider.none,
        fallbackProvider: AlarmProvider.localNotification,
        failureReason: AlarmFailureReason.platformError,
      )['failures'],
      [
        {'reason': 'PLATFORM_ERROR'},
      ],
    );
    expect(
      reportJson(
        status: AlarmReconciliationStatus.unsupported,
        nativeProvider: AlarmProvider.iosAlarmKit,
        fallbackProvider: AlarmProvider.none,
      ),
      containsPair('nativeAlarmProvider', 'IOS_ALARM_KIT'),
    );
    expect(
      reportJson(
        status: AlarmReconciliationStatus.settingsUnavailable,
        nativeProvider: AlarmProvider.none,
        fallbackProvider: AlarmProvider.none,
      ),
      containsPair('status', 'SETTINGS_UNAVAILABLE'),
    );
  });

  test('alarm enum wire values tolerate backend and unknown values', () {
    expect(AlarmProvider.androidAlarmManager.wireValue, 'androidAlarmManager');
    expect(AlarmProvider.iosAlarmKit.wireValue, 'iosAlarmKit');
    expect(AlarmProvider.localNotification.wireValue, 'localNotification');
    expect(AlarmProvider.none.wireValue, 'none');
    expect(
      AlarmPermissionStateWireValue.fromWireValue('granted'),
      AlarmPermissionState.granted,
    );
    expect(
      AlarmPermissionStateWireValue.fromWireValue('denied'),
      AlarmPermissionState.denied,
    );
    expect(
      AlarmProviderWireValue.fromWireValue('ANDROID_ALARM_MANAGER'),
      AlarmProvider.androidAlarmManager,
    );
    expect(
      AlarmProviderWireValue.fromWireValue('IOS_ALARM_KIT'),
      AlarmProvider.iosAlarmKit,
    );
    expect(
      AlarmProviderWireValue.fromWireValue('LOCAL_NOTIFICATION'),
      AlarmProvider.localNotification,
    );
    expect(
      AlarmProviderWireValue.fromWireValue('unexpected'),
      AlarmProvider.none,
    );

    expect(
      AlarmPermissionStateWireValue.fromWireValue('notDetermined'),
      AlarmPermissionState.notDetermined,
    );
    expect(
      AlarmPermissionStateWireValue.fromWireValue('unsupported'),
      AlarmPermissionState.unsupported,
    );
    expect(
      AlarmPermissionIssueWireValue.fromWireValue('nativePermissionDenied'),
      AlarmPermissionIssue.nativePermissionDenied,
    );
    expect(AlarmPermissionIssueWireValue.fromWireValue('unknown'), isNull);

    expect(
      AlarmFailureReasonWireValue.fromWireValue('PREPARATION_LOAD_FAILED'),
      AlarmFailureReason.preparationLoadFailed,
    );
    expect(
      AlarmFailureReasonWireValue.fromWireValue('SCHEDULE_INVALID'),
      AlarmFailureReason.scheduleInvalid,
    );
    expect(
      AlarmFailureReasonWireValue.fromWireValue('UNKNOWN'),
      AlarmFailureReason.unknown,
    );
    expect(
      AlarmFailureReason.preparationLoadFailed.wireValue,
      'preparationLoadFailed',
    );
    expect(AlarmFailureReason.scheduleInvalid.wireValue, 'scheduleInvalid');
    expect(AlarmFailureReason.platformError.wireValue, 'platformError');
    expect(AlarmFailureReason.unknown.wireValue, 'unknown');

    expect(AlarmReconciliationStatus.armed.wireValue, 'armed');
    expect(AlarmReconciliationStatus.partial.wireValue, 'partial');
    expect(AlarmReconciliationStatus.disabled.wireValue, 'disabled');
    expect(
      AlarmReconciliationStatus.permissionNeeded.wireValue,
      'permissionNeeded',
    );
    expect(AlarmReconciliationStatus.unsupported.wireValue, 'unsupported');
    expect(
      AlarmReconciliationStatus.settingsUnavailable.wireValue,
      'settingsUnavailable',
    );
    expect(
      AlarmReconciliationStatusWireValue.fromWireValue('permissionNeeded'),
      AlarmReconciliationStatus.permissionNeeded,
    );
    expect(
      AlarmReconciliationStatusWireValue.fromWireValue('partial'),
      AlarmReconciliationStatus.partial,
    );
    expect(
      AlarmReconciliationStatusWireValue.fromWireValue('disabled'),
      AlarmReconciliationStatus.disabled,
    );
    expect(
      AlarmReconciliationStatusWireValue.fromWireValue('unsupported'),
      AlarmReconciliationStatus.unsupported,
    );
    expect(
      AlarmReconciliationStatusWireValue.fromWireValue('anything-else'),
      AlarmReconciliationStatus.settingsUnavailable,
    );
  });

  test(
    'alarm scheduling helpers derive stable alarm records from schedules',
    () {
      final schedule = _scheduleWithPreparation(
        doneStatus: ScheduleDoneStatus.notEnded,
      );

      final record = buildScheduledAlarmRecord(
        schedule,
        alarmOffset: const Duration(minutes: 7),
        provider: AlarmProvider.androidAlarmManager,
      );

      expect(isAlarmEligibleSchedule(schedule), isTrue);
      expect(record.scheduleId, schedule.id);
      expect(
        record.alarmTime,
        schedule.preparationStartTime.subtract(const Duration(minutes: 7)),
      );
      expect(record.preparationStartTime, schedule.preparationStartTime);
      expect(record.nativeAlarmId, stableAlarmId(schedule.id));
      expect(record.fallbackNotificationId, stableAlarmId(schedule.id));
      expect(record.scheduleFingerprint, schedule.cacheFingerprint);
      expect(
        record.payload['alarmLaunchPayloadVersion'],
        alarmLaunchPayloadVersion,
      );
      expect(record.payload['promptVariant'], 'alarm');
      expect(record.payload['placeName'], 'Office');
    },
  );

  test('ended schedules are not eligible for alarm scheduling', () {
    expect(
      isAlarmEligibleSchedule(
        _scheduleWithPreparation(doneStatus: ScheduleDoneStatus.normalEnd),
      ),
      isFalse,
    );
  });

  test('scheduled alarm records copy mutable scheduling fields only', () {
    final original = ScheduledAlarmRecord(
      scheduleId: 'schedule-1',
      alarmTime: DateTime.utc(2026, 5, 15, 8),
      preparationStartTime: DateTime.utc(2026, 5, 15, 8, 5),
      scheduleFingerprint: 'fingerprint',
      nativeAlarmId: 1,
      fallbackNotificationId: 2,
      provider: AlarmProvider.androidAlarmManager,
      scheduleTitle: 'Morning meeting',
      payload: const {'type': 'schedule_alarm'},
    );

    final updated = original.copyWith(
      nativeAlarmId: 3,
      fallbackNotificationId: 4,
      provider: AlarmProvider.localNotification,
      payload: const {'type': 'fallback_alarm'},
    );

    expect(updated.scheduleId, original.scheduleId);
    expect(updated.nativeAlarmId, 3);
    expect(updated.fallbackNotificationId, 4);
    expect(updated.provider, AlarmProvider.localNotification);
    expect(updated.payload['type'], 'fallback_alarm');
  });

  test('alarm exceptions and result summaries expose user-visible context', () {
    final exception = const AlarmSchedulingException(
      reason: AlarmFailureReason.platformError,
      permissionIssue: AlarmPermissionIssue.nativePermissionDenied,
      message: 'permission missing',
    );
    final now = DateTime.utc(2026, 5, 15);
    final result = AlarmReconciliationResult(
      status: AlarmReconciliationStatus.partial,
      permissionIssue: AlarmPermissionIssue.notificationPermissionDenied,
      nativeAlarmProvider: AlarmProvider.none,
      fallbackProvider: AlarmProvider.localNotification,
      armedScheduleIds: const ['schedule-1', 'schedule-2'],
      skippedScheduleCount: 1,
      failures: const [
        AlarmFailure(
          scheduleId: 'schedule-3',
          reason: AlarmFailureReason.scheduleInvalid,
          message: 'ended',
        ),
      ],
      scheduleWindowStart: now,
      scheduleWindowEnd: now.add(const Duration(days: 8)),
      alarmCoverageStart: now,
      alarmCoverageEnd: now.add(const Duration(days: 7)),
    );

    expect(exception.toString(), contains('permission missing'));
    expect(
      const DeviceSessionNotActiveException().toString(),
      'DeviceSessionNotActiveException',
    );
    expect(result.armedScheduleCount, 2);
    expect(result.failures.single.reason, AlarmFailureReason.scheduleInvalid);
  });

  test(
    'alarm value objects compare the fields used by alarm sync contracts',
    () {
      final now = DateTime.utc(2026, 5, 15);
      const device = AlarmDeviceInfo(
        deviceId: 'device-1',
        platform: 'android',
        appVersion: '1.0.0',
        osVersion: '35',
        supportsNativeAlarm: true,
        nativeAlarmProvider: AlarmProvider.androidAlarmManager,
        fallbackProvider: AlarmProvider.localNotification,
      );
      const failure = AlarmFailure(
        scheduleId: 'schedule-1',
        reason: AlarmFailureReason.platformError,
        message: 'permission',
      );
      final result = AlarmReconciliationResult(
        status: AlarmReconciliationStatus.partial,
        permissionIssue: AlarmPermissionIssue.nativePermissionDenied,
        nativeAlarmProvider: AlarmProvider.androidAlarmManager,
        fallbackProvider: AlarmProvider.localNotification,
        armedScheduleIds: const ['schedule-1'],
        skippedScheduleCount: 2,
        failures: const [failure],
        scheduleWindowStart: now,
        scheduleWindowEnd: now.add(const Duration(days: 8)),
        alarmCoverageStart: now,
        alarmCoverageEnd: now.add(const Duration(days: 7)),
      );
      final sameResult = AlarmReconciliationResult(
        status: AlarmReconciliationStatus.partial,
        permissionIssue: AlarmPermissionIssue.nativePermissionDenied,
        nativeAlarmProvider: AlarmProvider.androidAlarmManager,
        fallbackProvider: AlarmProvider.localNotification,
        armedScheduleIds: const ['schedule-1'],
        skippedScheduleCount: 2,
        failures: const [failure],
        scheduleWindowStart: now,
        scheduleWindowEnd: now.add(const Duration(days: 8)),
        alarmCoverageStart: now,
        alarmCoverageEnd: now.add(const Duration(days: 7)),
      );
      final report = AlarmStatusReport(
        deviceId: device.deviceId,
        reconciledAt: now,
        scheduleWindowStart: result.scheduleWindowStart,
        scheduleWindowEnd: result.scheduleWindowEnd,
        alarmCoverageStart: result.alarmCoverageStart,
        alarmCoverageEnd: result.alarmCoverageEnd,
        status: result.status,
        permissionIssue: result.permissionIssue,
        nativeAlarmProvider: result.nativeAlarmProvider,
        fallbackProvider: result.fallbackProvider,
        armedScheduleCount: result.armedScheduleCount,
        armedScheduleIds: result.armedScheduleIds,
        skippedScheduleCount: result.skippedScheduleCount,
        failures: result.failures,
      );
      final settings = AlarmSettings(
        alarmsEnabled: true,
        defaultAlarmOffsetMinutes: 7,
        updatedAt: now,
      );
      const capabilities = AlarmSchedulerCapabilities(
        supportsNativeAlarm: true,
        nativeAlarmProvider: AlarmProvider.androidAlarmManager,
      );
      final record = ScheduledAlarmRecord(
        scheduleId: 'schedule-1',
        alarmTime: now,
        preparationStartTime: now.add(const Duration(minutes: 5)),
        scheduleFingerprint: 'fingerprint',
        nativeAlarmId: 10,
        fallbackNotificationId: 11,
        provider: AlarmProvider.androidAlarmManager,
        scheduleTitle: 'Morning meeting',
        payload: const {'type': 'schedule_alarm'},
      );

      expect(settings.alarmOffset, const Duration(minutes: 7));
      expect(settings.props, [true, 7, now]);
      expect(device.props, [
        'device-1',
        'android',
        '1.0.0',
        '35',
        true,
        AlarmProvider.androidAlarmManager,
        AlarmProvider.localNotification,
      ]);
      expect(capabilities.props, [
        true,
        AlarmProvider.androidAlarmManager,
        AlarmProvider.localNotification,
      ]);
      expect(record.props, [
        'schedule-1',
        now,
        now.add(const Duration(minutes: 5)),
        'fingerprint',
        10,
        11,
        AlarmProvider.androidAlarmManager,
        'Morning meeting',
        const {'type': 'schedule_alarm'},
      ]);
      expect(failure.props, [
        'schedule-1',
        AlarmFailureReason.platformError,
        'permission',
      ]);
      expect(result, equals(sameResult));
      expect(result.props, [
        AlarmReconciliationStatus.partial,
        AlarmPermissionIssue.nativePermissionDenied,
        AlarmProvider.androidAlarmManager,
        AlarmProvider.localNotification,
        const ['schedule-1'],
        2,
        const [failure],
        now,
        now.add(const Duration(days: 8)),
        now,
        now.add(const Duration(days: 7)),
      ]);
      expect(report, equals(report));
      expect(
        report.props,
        containsAll([
          'device-1',
          AlarmReconciliationStatus.partial,
          AlarmPermissionIssue.nativePermissionDenied,
          AlarmProvider.androidAlarmManager,
          AlarmProvider.localNotification,
          1,
          2,
          const [failure],
        ]),
      );
    },
  );
}

ScheduleWithPreparationEntity _scheduleWithPreparation({
  required ScheduleDoneStatus doneStatus,
}) {
  return ScheduleWithPreparationEntity(
    id: 'schedule-1',
    place: const PlaceEntity(id: 'place-1', placeName: 'Office'),
    scheduleName: 'Morning meeting',
    scheduleTime: DateTime.utc(2026, 5, 15, 9),
    moveTime: const Duration(minutes: 20),
    isChanged: false,
    isStarted: false,
    scheduleSpareTime: const Duration(minutes: 5),
    scheduleNote: 'Bring notes',
    doneStatus: doneStatus,
    preparation: const PreparationWithTimeEntity(
      preparationStepList: [
        PreparationStepWithTimeEntity(
          id: 'prep-1',
          preparationName: 'Pack',
          preparationTime: Duration(minutes: 10),
          nextPreparationId: 'prep-2',
        ),
        PreparationStepWithTimeEntity(
          id: 'prep-2',
          preparationName: 'Dress',
          preparationTime: Duration(minutes: 15),
          nextPreparationId: null,
        ),
      ],
    ),
  );
}
