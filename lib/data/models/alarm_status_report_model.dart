import 'package:on_time_front/domain/entities/alarm_entities.dart';

class AlarmStatusReportModel {
  final AlarmStatusReport report;

  const AlarmStatusReportModel(this.report);

  Map<String, dynamic> toJson() {
    return {
      'deviceId': report.deviceId,
      'reconciledAt': report.reconciledAt.toIso8601String(),
      'scheduleWindowStart': report.scheduleWindowStart.toIso8601String(),
      'scheduleWindowEnd': report.scheduleWindowEnd.toIso8601String(),
      'alarmCoverageStart': report.alarmCoverageStart.toIso8601String(),
      'alarmCoverageEnd': report.alarmCoverageEnd.toIso8601String(),
      'status': report.status.wireValue,
      'permissionIssue': report.permissionIssue?.wireValue,
      'nativeAlarmProvider': report.nativeAlarmProvider.wireValue,
      'fallbackProvider': report.fallbackProvider.wireValue,
      'armedScheduleCount': report.armedScheduleCount,
      'armedScheduleIds': report.armedScheduleIds,
      'skippedScheduleCount': report.skippedScheduleCount,
      'failures': report.failures
          .map(
            (failure) => {
              if (failure.scheduleId != null) 'scheduleId': failure.scheduleId,
              'reason': failure.reason.wireValue,
              if (failure.message != null) 'message': failure.message,
            },
          )
          .toList(),
    };
  }
}
