import 'package:on_time_front/domain/entities/alarm_entities.dart';

class ScheduledAlarmRecordModel {
  final ScheduledAlarmRecord record;

  const ScheduledAlarmRecordModel(this.record);

  factory ScheduledAlarmRecordModel.fromJson(Map<String, dynamic> json) {
    final payload = (json['payload'] as Map<String, dynamic>? ?? const {}).map(
      (key, value) => MapEntry(key, value.toString()),
    );
    // New comparison metadata must never make us discard ownership evidence
    // for the whole registry. Malformed values force a safe legacy replacement.
    final rawDigest = json['contentDigest'];
    final rawVersion = json['contentVersion'];
    final rawLanguage = json['contentLanguageCode'];
    final rawPending = json['cancellationPending'];
    final validMetadata =
        rawDigest is String &&
        RegExp(r'^[0-9a-f]{64}$').hasMatch(rawDigest) &&
        rawVersion is int &&
        rawVersion > 0 &&
        (rawLanguage == 'ko' || rawLanguage == 'en') &&
        (rawPending == null || rawPending is bool);
    return ScheduledAlarmRecordModel(
      ScheduledAlarmRecord(
        scheduleId: json['scheduleId'] as String,
        alarmTime: DateTime.parse(json['alarmTime'] as String),
        preparationStartTime: DateTime.parse(
          json['preparationStartTime'] as String,
        ),
        scheduleFingerprint: json['scheduleFingerprint'] as String? ?? '',
        nativeAlarmId: (json['nativeAlarmId'] as num?)?.toInt(),
        fallbackNotificationId: (json['fallbackNotificationId'] as num?)
            ?.toInt(),
        provider: AlarmProviderWireValue.fromWireValue(
          json['provider'] as String?,
        ),
        scheduleTitle: json['scheduleTitle'] as String? ?? '',
        payload: payload,
        contentDigest: validMetadata ? rawDigest : null,
        contentVersion: validMetadata ? rawVersion : null,
        contentLanguageCode: validMetadata ? rawLanguage as String : null,
        notificationTiming: NotificationTiming.values
            .where((value) => value.name == json['notificationTiming'])
            .firstOrNull,
        cancellationPending:
            rawPending == true || (rawPending != null && rawPending is! bool),
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
      if (record.contentDigest != null) 'contentDigest': record.contentDigest,
      if (record.contentLanguageCode != null)
        'contentLanguageCode': record.contentLanguageCode,
      if (record.contentVersion != null)
        'contentVersion': record.contentVersion,
      if (record.cancellationPending) 'cancellationPending': true,
      if (record.notificationTiming != null)
        'notificationTiming': record.notificationTiming!.name,
    };
  }
}
