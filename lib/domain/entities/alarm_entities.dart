import 'package:equatable/equatable.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';

const alarmDefaultOffset = Duration(minutes: 5);
const alarmLaunchPayloadVersion = '2';

enum AlarmProvider {
  androidAlarmManager,
  iosAlarmKit,
  localNotification,
  none,
}

enum AlarmPermissionState {
  granted,
  denied,
  notDetermined,
  unsupported,
}

enum AlarmPermissionIssue {
  nativePermissionDenied,
  notificationPermissionDenied,
}

enum AlarmFailureReason {
  preparationLoadFailed,
  scheduleInvalid,
  platformError,
  unknown,
}

enum AlarmReconciliationStatus {
  armed,
  partial,
  disabled,
  permissionNeeded,
  unsupported,
  settingsUnavailable,
}

extension AlarmProviderWireValue on AlarmProvider {
  String get wireValue {
    switch (this) {
      case AlarmProvider.androidAlarmManager:
        return 'androidAlarmManager';
      case AlarmProvider.iosAlarmKit:
        return 'iosAlarmKit';
      case AlarmProvider.localNotification:
        return 'localNotification';
      case AlarmProvider.none:
        return 'none';
    }
  }

  static AlarmProvider fromWireValue(String? value) {
    switch (value) {
      case 'androidAlarmManager':
        return AlarmProvider.androidAlarmManager;
      case 'iosAlarmKit':
        return AlarmProvider.iosAlarmKit;
      case 'localNotification':
        return AlarmProvider.localNotification;
      case 'none':
      default:
        return AlarmProvider.none;
    }
  }
}

extension AlarmPermissionStateWireValue on AlarmPermissionState {
  static AlarmPermissionState fromWireValue(String? value) {
    switch (value) {
      case 'granted':
        return AlarmPermissionState.granted;
      case 'denied':
        return AlarmPermissionState.denied;
      case 'notDetermined':
        return AlarmPermissionState.notDetermined;
      case 'unsupported':
      default:
        return AlarmPermissionState.unsupported;
    }
  }
}

extension AlarmPermissionIssueWireValue on AlarmPermissionIssue {
  String get wireValue {
    switch (this) {
      case AlarmPermissionIssue.nativePermissionDenied:
        return 'nativePermissionDenied';
      case AlarmPermissionIssue.notificationPermissionDenied:
        return 'notificationPermissionDenied';
    }
  }

  static AlarmPermissionIssue? fromWireValue(String? value) {
    switch (value) {
      case 'nativePermissionDenied':
        return AlarmPermissionIssue.nativePermissionDenied;
      case 'notificationPermissionDenied':
        return AlarmPermissionIssue.notificationPermissionDenied;
      case null:
        return null;
      default:
        return null;
    }
  }
}

extension AlarmFailureReasonWireValue on AlarmFailureReason {
  String get wireValue {
    switch (this) {
      case AlarmFailureReason.preparationLoadFailed:
        return 'preparationLoadFailed';
      case AlarmFailureReason.scheduleInvalid:
        return 'scheduleInvalid';
      case AlarmFailureReason.platformError:
        return 'platformError';
      case AlarmFailureReason.unknown:
        return 'unknown';
    }
  }

  static AlarmFailureReason fromWireValue(String? value) {
    switch (value) {
      case 'preparationLoadFailed':
        return AlarmFailureReason.preparationLoadFailed;
      case 'scheduleInvalid':
        return AlarmFailureReason.scheduleInvalid;
      case 'platformError':
        return AlarmFailureReason.platformError;
      case 'unknown':
      default:
        return AlarmFailureReason.unknown;
    }
  }
}

extension AlarmReconciliationStatusWireValue on AlarmReconciliationStatus {
  String get wireValue {
    switch (this) {
      case AlarmReconciliationStatus.armed:
        return 'armed';
      case AlarmReconciliationStatus.partial:
        return 'partial';
      case AlarmReconciliationStatus.disabled:
        return 'disabled';
      case AlarmReconciliationStatus.permissionNeeded:
        return 'permissionNeeded';
      case AlarmReconciliationStatus.unsupported:
        return 'unsupported';
      case AlarmReconciliationStatus.settingsUnavailable:
        return 'settingsUnavailable';
    }
  }

  static AlarmReconciliationStatus fromWireValue(String? value) {
    switch (value) {
      case 'armed':
        return AlarmReconciliationStatus.armed;
      case 'partial':
        return AlarmReconciliationStatus.partial;
      case 'disabled':
        return AlarmReconciliationStatus.disabled;
      case 'permissionNeeded':
        return AlarmReconciliationStatus.permissionNeeded;
      case 'unsupported':
        return AlarmReconciliationStatus.unsupported;
      case 'settingsUnavailable':
      default:
        return AlarmReconciliationStatus.settingsUnavailable;
    }
  }
}

class AlarmSchedulingException implements Exception {
  final AlarmFailureReason reason;
  final AlarmPermissionIssue? permissionIssue;
  final String message;

  const AlarmSchedulingException({
    required this.reason,
    required this.message,
    this.permissionIssue,
  });

  @override
  String toString() {
    return 'AlarmSchedulingException(reason: $reason, permissionIssue: $permissionIssue, message: $message)';
  }
}

class DeviceSessionNotActiveException implements Exception {
  const DeviceSessionNotActiveException();

  @override
  String toString() => 'DeviceSessionNotActiveException';
}

class AlarmSettings extends Equatable {
  final bool alarmsEnabled;
  final int defaultAlarmOffsetMinutes;
  final DateTime? updatedAt;

  const AlarmSettings({
    required this.alarmsEnabled,
    this.defaultAlarmOffsetMinutes = 5,
    this.updatedAt,
  });

  Duration get alarmOffset => Duration(minutes: defaultAlarmOffsetMinutes);

  @override
  List<Object?> get props => [
        alarmsEnabled,
        defaultAlarmOffsetMinutes,
        updatedAt,
      ];
}

class AlarmDeviceInfo extends Equatable {
  final String deviceId;
  final String platform;
  final String appVersion;
  final String osVersion;
  final bool supportsNativeAlarm;
  final AlarmProvider nativeAlarmProvider;
  final AlarmProvider fallbackProvider;

  const AlarmDeviceInfo({
    required this.deviceId,
    required this.platform,
    required this.appVersion,
    required this.osVersion,
    required this.supportsNativeAlarm,
    required this.nativeAlarmProvider,
    required this.fallbackProvider,
  });

  @override
  List<Object?> get props => [
        deviceId,
        platform,
        appVersion,
        osVersion,
        supportsNativeAlarm,
        nativeAlarmProvider,
        fallbackProvider,
      ];
}

class AlarmSchedulerCapabilities extends Equatable {
  final bool supportsNativeAlarm;
  final AlarmProvider nativeAlarmProvider;
  final AlarmProvider fallbackProvider;

  const AlarmSchedulerCapabilities({
    required this.supportsNativeAlarm,
    required this.nativeAlarmProvider,
    this.fallbackProvider = AlarmProvider.localNotification,
  });

  static const unsupported = AlarmSchedulerCapabilities(
    supportsNativeAlarm: false,
    nativeAlarmProvider: AlarmProvider.none,
    fallbackProvider: AlarmProvider.none,
  );

  @override
  List<Object?> get props => [
        supportsNativeAlarm,
        nativeAlarmProvider,
        fallbackProvider,
      ];
}

class ScheduledAlarmRecord extends Equatable {
  final String scheduleId;
  final DateTime alarmTime;
  final DateTime preparationStartTime;
  final String scheduleFingerprint;
  final int? nativeAlarmId;
  final int? fallbackNotificationId;
  final AlarmProvider provider;
  final String scheduleTitle;
  final Map<String, String> payload;

  const ScheduledAlarmRecord({
    required this.scheduleId,
    required this.alarmTime,
    required this.preparationStartTime,
    required this.scheduleFingerprint,
    required this.provider,
    required this.scheduleTitle,
    required this.payload,
    this.nativeAlarmId,
    this.fallbackNotificationId,
  });

  ScheduledAlarmRecord copyWith({
    int? nativeAlarmId,
    int? fallbackNotificationId,
    AlarmProvider? provider,
  }) {
    return ScheduledAlarmRecord(
      scheduleId: scheduleId,
      alarmTime: alarmTime,
      preparationStartTime: preparationStartTime,
      scheduleFingerprint: scheduleFingerprint,
      nativeAlarmId: nativeAlarmId ?? this.nativeAlarmId,
      fallbackNotificationId:
          fallbackNotificationId ?? this.fallbackNotificationId,
      provider: provider ?? this.provider,
      scheduleTitle: scheduleTitle,
      payload: payload,
    );
  }

  @override
  List<Object?> get props => [
        scheduleId,
        alarmTime,
        preparationStartTime,
        scheduleFingerprint,
        nativeAlarmId,
        fallbackNotificationId,
        provider,
        scheduleTitle,
        payload,
      ];
}

class AlarmFailure extends Equatable {
  final String? scheduleId;
  final AlarmFailureReason reason;
  final String? message;

  const AlarmFailure({
    required this.reason,
    this.scheduleId,
    this.message,
  });

  @override
  List<Object?> get props => [scheduleId, reason, message];
}

class AlarmReconciliationResult extends Equatable {
  final AlarmReconciliationStatus status;
  final AlarmPermissionIssue? permissionIssue;
  final AlarmProvider nativeAlarmProvider;
  final AlarmProvider fallbackProvider;
  final List<String> armedScheduleIds;
  final int skippedScheduleCount;
  final List<AlarmFailure> failures;
  final DateTime scheduleWindowStart;
  final DateTime scheduleWindowEnd;
  final DateTime alarmCoverageStart;
  final DateTime alarmCoverageEnd;

  const AlarmReconciliationResult({
    required this.status,
    required this.nativeAlarmProvider,
    required this.fallbackProvider,
    required this.armedScheduleIds,
    required this.skippedScheduleCount,
    required this.failures,
    required this.scheduleWindowStart,
    required this.scheduleWindowEnd,
    required this.alarmCoverageStart,
    required this.alarmCoverageEnd,
    this.permissionIssue,
  });

  int get armedScheduleCount => armedScheduleIds.length;

  @override
  List<Object?> get props => [
        status,
        permissionIssue,
        nativeAlarmProvider,
        fallbackProvider,
        armedScheduleIds,
        skippedScheduleCount,
        failures,
        scheduleWindowStart,
        scheduleWindowEnd,
        alarmCoverageStart,
        alarmCoverageEnd,
      ];
}

class AlarmStatusReport extends Equatable {
  final String deviceId;
  final DateTime reconciledAt;
  final DateTime scheduleWindowStart;
  final DateTime scheduleWindowEnd;
  final DateTime alarmCoverageStart;
  final DateTime alarmCoverageEnd;
  final AlarmReconciliationStatus status;
  final AlarmPermissionIssue? permissionIssue;
  final AlarmProvider nativeAlarmProvider;
  final AlarmProvider fallbackProvider;
  final int armedScheduleCount;
  final List<String> armedScheduleIds;
  final int skippedScheduleCount;
  final List<AlarmFailure> failures;

  const AlarmStatusReport({
    required this.deviceId,
    required this.reconciledAt,
    required this.scheduleWindowStart,
    required this.scheduleWindowEnd,
    required this.alarmCoverageStart,
    required this.alarmCoverageEnd,
    required this.status,
    required this.nativeAlarmProvider,
    required this.fallbackProvider,
    required this.armedScheduleCount,
    required this.armedScheduleIds,
    required this.skippedScheduleCount,
    required this.failures,
    this.permissionIssue,
  });

  @override
  List<Object?> get props => [
        deviceId,
        reconciledAt,
        scheduleWindowStart,
        scheduleWindowEnd,
        alarmCoverageStart,
        alarmCoverageEnd,
        status,
        permissionIssue,
        nativeAlarmProvider,
        fallbackProvider,
        armedScheduleCount,
        armedScheduleIds,
        skippedScheduleCount,
        failures,
      ];
}

bool isAlarmEligibleSchedule(ScheduleWithPreparationEntity schedule) {
  return schedule.doneStatus == ScheduleDoneStatus.notEnded;
}

DateTime computeAlarmTime(
  ScheduleWithPreparationEntity schedule, {
  Duration offset = alarmDefaultOffset,
}) {
  return schedule.preparationStartTime.subtract(offset);
}

String buildAlarmScheduleFingerprint(ScheduleWithPreparationEntity schedule) {
  return schedule.cacheFingerprint;
}

int stableAlarmId(String scheduleId) {
  const offsetBasis = 0x811c9dc5;
  const prime = 0x01000193;
  var hash = offsetBasis;
  for (final unit in scheduleId.codeUnits) {
    hash ^= unit;
    hash = (hash * prime) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}

ScheduledAlarmRecord buildScheduledAlarmRecord(
  ScheduleWithPreparationEntity schedule, {
  required Duration alarmOffset,
  required AlarmProvider provider,
}) {
  final alarmTime = computeAlarmTime(schedule, offset: alarmOffset);
  final id = stableAlarmId(schedule.id);
  final preparationStartTime = schedule.preparationStartTime;
  return ScheduledAlarmRecord(
    scheduleId: schedule.id,
    alarmTime: alarmTime,
    preparationStartTime: preparationStartTime,
    scheduleFingerprint: buildAlarmScheduleFingerprint(schedule),
    nativeAlarmId: id,
    fallbackNotificationId: id,
    provider: provider,
    scheduleTitle: schedule.scheduleName,
    payload: {
      'type': 'schedule_alarm',
      'alarmLaunchPayloadVersion': alarmLaunchPayloadVersion,
      'scheduleId': schedule.id,
      'alarmTime': alarmTime.toIso8601String(),
      'preparationStartTime': preparationStartTime.toIso8601String(),
      'scheduleFingerprint': buildAlarmScheduleFingerprint(schedule),
      'promptVariant': 'alarm',
    },
  );
}
