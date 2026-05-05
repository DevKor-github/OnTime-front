import 'package:on_time_front/domain/entities/alarm_entities.dart';

class ScheduledAlarmRecordModel {
  final ScheduledAlarmRecord record;

  const ScheduledAlarmRecordModel(this.record);

  factory ScheduledAlarmRecordModel.fromJson(Map<String, dynamic> json) {
    final payload = (json['payload'] as Map<String, dynamic>? ?? const {})
        .map((key, value) => MapEntry(key, value.toString()));
    return ScheduledAlarmRecordModel(
      ScheduledAlarmRecord(
        scheduleId: json['scheduleId'] as String,
        alarmTime: DateTime.parse(json['alarmTime'] as String),
        preparationStartTime:
            DateTime.parse(json['preparationStartTime'] as String),
        scheduleFingerprint: json['scheduleFingerprint'] as String? ?? '',
        nativeAlarmId: (json['nativeAlarmId'] as num?)?.toInt(),
        fallbackNotificationId:
            (json['fallbackNotificationId'] as num?)?.toInt(),
        provider:
            AlarmProviderWireValue.fromWireValue(json['provider'] as String?),
        scheduleTitle: json['scheduleTitle'] as String? ?? '',
        payload: payload,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'scheduleId': record.scheduleId,
      'alarmTime': record.alarmTime.toIso8601String(),
      'preparationStartTime': record.preparationStartTime.toIso8601String(),
      'scheduleFingerprint': record.scheduleFingerprint,
      'nativeAlarmId': record.nativeAlarmId,
      'fallbackNotificationId': record.fallbackNotificationId,
      'provider': record.provider.wireValue,
      'scheduleTitle': record.scheduleTitle,
      'payload': record.payload,
    };
  }
}
