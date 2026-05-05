import 'package:on_time_front/domain/entities/alarm_entities.dart';

enum AlarmStatusReportWireFormat {
  lowerCamel,
  upperSnake,
}

class AlarmStatusReportModel {
  final AlarmStatusReport report;

  const AlarmStatusReportModel(this.report);

  Map<String, dynamic> toJson({
    AlarmStatusReportWireFormat wireFormat =
        AlarmStatusReportWireFormat.lowerCamel,
  }) {
    return {
      'deviceId': report.deviceId,
      'reconciledAt': _toBackendInstantString(report.reconciledAt),
      'scheduleWindowStart':
          _toBackendDateTimeString(report.scheduleWindowStart),
      'scheduleWindowEnd': _toBackendDateTimeString(report.scheduleWindowEnd),
      'alarmCoverageStart': _toBackendDateTimeString(report.alarmCoverageStart),
      'alarmCoverageEnd': _toBackendDateTimeString(report.alarmCoverageEnd),
      'status': _statusWireValue(report.status, wireFormat),
      if (report.permissionIssue != null)
        'permissionIssue':
            _permissionIssueWireValue(report.permissionIssue!, wireFormat),
      'nativeAlarmProvider':
          _providerWireValue(report.nativeAlarmProvider, wireFormat),
      'fallbackProvider': _providerWireValue(
        report.fallbackProvider,
        wireFormat,
      ),
      'armedScheduleCount': report.armedScheduleCount,
      'armedScheduleIds': report.armedScheduleIds,
      'skippedScheduleCount': report.skippedScheduleCount,
      'failures': report.failures
          .map(
            (failure) => {
              if (failure.scheduleId != null) 'scheduleId': failure.scheduleId,
              'reason': _failureReasonWireValue(failure.reason, wireFormat),
              if (failure.message != null) 'message': failure.message,
            },
          )
          .toList(),
    };
  }

  String _toBackendInstantString(DateTime value) {
    final utc = value.toUtc();
    return '${_formatDateTime(utc)}Z';
  }

  String _toBackendDateTimeString(DateTime value) {
    return _formatDateTime(value.toLocal());
  }

  String _formatDateTime(DateTime value) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    String threeDigits(int value) => value.toString().padLeft(3, '0');

    return '${value.year.toString().padLeft(4, '0')}-'
        '${twoDigits(value.month)}-'
        '${twoDigits(value.day)}T'
        '${twoDigits(value.hour)}:'
        '${twoDigits(value.minute)}:'
        '${twoDigits(value.second)}.'
        '${threeDigits(value.millisecond)}';
  }

  String _providerWireValue(
    AlarmProvider provider,
    AlarmStatusReportWireFormat wireFormat,
  ) {
    if (wireFormat == AlarmStatusReportWireFormat.lowerCamel) {
      return provider.wireValue;
    }
    switch (provider) {
      case AlarmProvider.androidAlarmManager:
        return 'ANDROID_ALARM_MANAGER';
      case AlarmProvider.iosAlarmKit:
        return 'IOS_ALARM_KIT';
      case AlarmProvider.localNotification:
        return 'LOCAL_NOTIFICATION';
      case AlarmProvider.none:
        return 'NONE';
    }
  }

  String _statusWireValue(
    AlarmReconciliationStatus status,
    AlarmStatusReportWireFormat wireFormat,
  ) {
    if (wireFormat == AlarmStatusReportWireFormat.lowerCamel) {
      return status.wireValue;
    }
    switch (status) {
      case AlarmReconciliationStatus.armed:
        return 'ARMED';
      case AlarmReconciliationStatus.partial:
        return 'PARTIAL';
      case AlarmReconciliationStatus.disabled:
        return 'DISABLED';
      case AlarmReconciliationStatus.permissionNeeded:
        return 'PERMISSION_NEEDED';
      case AlarmReconciliationStatus.unsupported:
        return 'UNSUPPORTED';
      case AlarmReconciliationStatus.settingsUnavailable:
        return 'SETTINGS_UNAVAILABLE';
    }
  }

  String _permissionIssueWireValue(
    AlarmPermissionIssue issue,
    AlarmStatusReportWireFormat wireFormat,
  ) {
    if (wireFormat == AlarmStatusReportWireFormat.lowerCamel) {
      return issue.wireValue;
    }
    switch (issue) {
      case AlarmPermissionIssue.nativePermissionDenied:
        return 'NATIVE_PERMISSION_DENIED';
      case AlarmPermissionIssue.notificationPermissionDenied:
        return 'NOTIFICATION_PERMISSION_DENIED';
    }
  }

  String _failureReasonWireValue(
    AlarmFailureReason reason,
    AlarmStatusReportWireFormat wireFormat,
  ) {
    if (wireFormat == AlarmStatusReportWireFormat.lowerCamel) {
      return reason.wireValue;
    }
    switch (reason) {
      case AlarmFailureReason.preparationLoadFailed:
        return 'PREPARATION_LOAD_FAILED';
      case AlarmFailureReason.scheduleInvalid:
        return 'SCHEDULE_INVALID';
      case AlarmFailureReason.platformError:
        return 'PLATFORM_ERROR';
      case AlarmFailureReason.unknown:
        return 'UNKNOWN';
    }
  }
}
