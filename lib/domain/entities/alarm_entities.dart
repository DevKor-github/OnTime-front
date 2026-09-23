import 'package:equatable/equatable.dart';
import 'package:on_time_front/domain/entities/scheduled_notification_content.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';

const alarmDefaultOffset = Duration(minutes: 5);
const alarmLaunchPayloadVersion = '9';

enum AlarmProvider { androidAlarmManager, iosAlarmKit, localNotification, none }

const androidFullScreenAlarmPolicyApproved = false;

bool nativeAlarmProviderAllowedByReleasePolicy(AlarmProvider provider) {
  switch (provider) {
    case AlarmProvider.iosAlarmKit:
      return true;
    case AlarmProvider.androidAlarmManager:
      return androidFullScreenAlarmPolicyApproved;
    case AlarmProvider.localNotification:
    case AlarmProvider.none:
      return false;
  }
}

enum AlarmPermissionState { granted, denied, notDetermined, unsupported }

enum AlarmPermissionIssue {
  nativePermissionDenied,
  notificationPermissionDenied,
}

enum AlarmFailureReason {
  preparationLoadFailed,
  scheduleInvalid,
  cancellationFailed,
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
      case 'ANDROID_ALARM_MANAGER':
        return AlarmProvider.androidAlarmManager;
      case 'iosAlarmKit':
      case 'IOS_ALARM_KIT':
        return AlarmProvider.iosAlarmKit;
      case 'localNotification':
      case 'LOCAL_NOTIFICATION':
        return AlarmProvider.localNotification;
      case 'none':
      case 'NONE':
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
      case AlarmFailureReason.cancellationFailed:
        return 'cancellationFailed';
      case AlarmFailureReason.platformError:
        return 'platformError';
      case AlarmFailureReason.unknown:
        return 'unknown';
    }
  }

  static AlarmFailureReason fromWireValue(String? value) {
    switch (value) {
      case 'preparationLoadFailed':
      case 'PREPARATION_LOAD_FAILED':
        return AlarmFailureReason.preparationLoadFailed;
      case 'scheduleInvalid':
      case 'SCHEDULE_INVALID':
        return AlarmFailureReason.scheduleInvalid;
      case 'cancellationFailed':
      case 'CANCELLATION_FAILED':
        return AlarmFailureReason.cancellationFailed;
      case 'platformError':
      case 'PLATFORM_ERROR':
        return AlarmFailureReason.platformError;
      case 'unknown':
      case 'UNKNOWN':
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

class AlarmSettings extends Equatable {
  final bool alarmsEnabled;
  final int defaultAlarmOffsetMinutes;
  final DateTime? updatedAt;
  final bool detailedNotificationContent;

  const AlarmSettings({
    required this.alarmsEnabled,
    this.defaultAlarmOffsetMinutes = 5,
    this.updatedAt,
    this.detailedNotificationContent = false,
  });

  Duration get alarmOffset => Duration(minutes: defaultAlarmOffsetMinutes);

  @override
  List<Object?> get props => [
    alarmsEnabled,
    defaultAlarmOffsetMinutes,
    updatedAt,
    detailedNotificationContent,
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

/// Actual successful registration mode; null on a record means legacy/unknown.
enum NotificationTiming { platformDefault, exact, approximate }

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
  final String? contentDigest;
  final int? contentVersion;
  final String? contentLanguageCode;
  final bool cancellationPending;
  final NotificationTiming? notificationTiming;
  // Ephemeral: the registry stores only the digest/version, not another copy
  // of the rendered body. Fresh desired records always carry this snapshot.
  final ScheduledNotificationContent? notificationContent;

  ScheduledNotificationContent get deliveryContent =>
      notificationContent ??
      ScheduledNotificationContent(
        scheduleTitle: scheduleTitle,
        detailed: payload['detailedNotificationContent'] == 'true',
        displayTimeZone: payload['notificationTimeZone'],
        languageCode: contentLanguageCode ?? 'en',
      );

  bool get hasCurrentContent =>
      contentVersion == ScheduledNotificationContent.schemaVersion &&
      (contentLanguageCode == 'ko' || contentLanguageCode == 'en') &&
      contentDigest != null &&
      contentDigest == deliveryContent.digest &&
      contentDigest ==
          ScheduledNotificationContent(
            scheduleTitle: scheduleTitle,
            detailed: payload['detailedNotificationContent'] == 'true',
            displayTimeZone: payload['notificationTimeZone'],
            languageCode: contentLanguageCode ?? 'en',
          ).digest &&
      !cancellationPending;

  void requireCurrentContent() {
    if (!hasCurrentContent) {
      throw const AlarmSchedulingException(
        reason: AlarmFailureReason.scheduleInvalid,
        message:
            'Notification content requires reconciliation before scheduling',
      );
    }
  }

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
    this.contentDigest,
    this.contentVersion,
    this.contentLanguageCode,
    this.cancellationPending = false,
    this.notificationTiming,
    this.notificationContent,
  });

  ScheduledAlarmRecord copyWith({
    DateTime? alarmTime,
    DateTime? preparationStartTime,
    String? scheduleFingerprint,
    int? nativeAlarmId,
    int? fallbackNotificationId,
    AlarmProvider? provider,
    String? scheduleTitle,
    Map<String, String>? payload,
    String? contentDigest,
    int? contentVersion,
    String? contentLanguageCode,
    bool? cancellationPending,
    NotificationTiming? notificationTiming,
    ScheduledNotificationContent? notificationContent,
  }) {
    return ScheduledAlarmRecord(
      scheduleId: scheduleId,
      alarmTime: alarmTime ?? this.alarmTime,
      preparationStartTime: preparationStartTime ?? this.preparationStartTime,
      scheduleFingerprint: scheduleFingerprint ?? this.scheduleFingerprint,
      nativeAlarmId: nativeAlarmId ?? this.nativeAlarmId,
      fallbackNotificationId:
          fallbackNotificationId ?? this.fallbackNotificationId,
      provider: provider ?? this.provider,
      scheduleTitle: scheduleTitle ?? this.scheduleTitle,
      payload: payload ?? this.payload,
      contentDigest: contentDigest ?? this.contentDigest,
      contentVersion: contentVersion ?? this.contentVersion,
      contentLanguageCode: contentLanguageCode ?? this.contentLanguageCode,
      cancellationPending: cancellationPending ?? this.cancellationPending,
      notificationTiming: notificationTiming ?? this.notificationTiming,
      notificationContent: notificationContent ?? this.notificationContent,
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
    contentDigest,
    contentVersion,
    contentLanguageCode,
    cancellationPending,
    notificationTiming,
  ];
}

class AlarmFailure extends Equatable {
  final String? scheduleId;
  final AlarmFailureReason reason;
  final String? message;

  const AlarmFailure({required this.reason, this.scheduleId, this.message});

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
  bool detailedNotificationContent = false,
  String? currentTimeZoneId,
  String languageCode = 'en',
}) {
  final alarmTime = computeAlarmTime(schedule, offset: alarmOffset);
  final id = stableAlarmId(schedule.id);
  final preparationStartTime = schedule.preparationStartTime;
  final content = ScheduledNotificationContent(
    scheduleTitle: schedule.scheduleName,
    detailed: detailedNotificationContent,
    languageCode: languageCode,
    displayTimeZone:
        currentTimeZoneId != null && currentTimeZoneId != schedule.timeZoneId
        ? schedule.timeZoneId
        : null,
  );
  return ScheduledAlarmRecord(
    scheduleId: schedule.id,
    alarmTime: alarmTime,
    preparationStartTime: preparationStartTime,
    scheduleFingerprint: buildAlarmScheduleFingerprint(schedule),
    nativeAlarmId: id,
    fallbackNotificationId: id,
    provider: provider,
    scheduleTitle: content.title,
    notificationContent: content,
    contentDigest: content.digest,
    contentVersion: ScheduledNotificationContent.schemaVersion,
    contentLanguageCode: content.languageCode,
    payload: {
      'type': 'schedule_notification',
      'alarmLaunchPayloadVersion': alarmLaunchPayloadVersion,
      'scheduleId': schedule.id,
      'promptVariant': 'notification',
      'detailedNotificationContent': detailedNotificationContent.toString(),
      if (detailedNotificationContent &&
          currentTimeZoneId != null &&
          currentTimeZoneId != schedule.timeZoneId)
        'notificationTimeZone': schedule.timeZoneId,
    },
  );
}
