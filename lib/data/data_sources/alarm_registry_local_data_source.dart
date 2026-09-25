import 'package:on_time_front/domain/repositories/alarm_registry_repository.dart';
import 'dart:convert';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/data/models/scheduled_alarm_record_model.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/entities/notification_route_payload.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class AlarmRegistryLocalDataSource {
  Future<List<ScheduledAlarmRecord>> loadAll();
  Future<void> replaceAll(List<ScheduledAlarmRecord> records);
}

@Injectable(as: AlarmRegistryLocalDataSource)
class AlarmRegistryLocalDataSourceImpl
    implements
        AlarmRegistryLocalDataSource,
        RecoverableAlarmOwnershipIntegrity {
  static const _prefsKey = 'scheduled_alarm_registry';
  static const _unknownKey = 'scheduled_alarm_ownership_unknown_v1';

  @override
  Future<bool> hasUnresolvedOwnership() async {
    final prefs = await SharedPreferences.getInstance();
    // Any value in this reserved marker means uncertainty, including corruption.
    return prefs.containsKey(_unknownKey);
  }

  @override
  Future<void> clearResolvedOwnership() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.remove(_unknownKey)) {
      throw StateError('Ownership uncertainty removal failed');
    }
    await prefs.reload();
    if (prefs.containsKey(_unknownKey)) {
      throw StateError('Ownership uncertainty removal was not persisted');
    }
  }

  static Future<void> _markUnknown(SharedPreferences prefs) async {
    if (!await prefs.setBool(_unknownKey, true)) {
      throw StateError('Ownership uncertainty could not be preserved');
    }
    await prefs.reload();
    if (prefs.getBool(_unknownKey) != true) {
      throw StateError('Ownership uncertainty was not persisted');
    }
  }

  static bool _validIdentity(Map<String, dynamic> item) {
    final provider = item['provider'];
    if (provider == AlarmProvider.none.wireValue) return true;
    if (!AlarmProvider.values.any((value) => value.wireValue == provider) ||
        item['scheduleId'] is! String ||
        (item['scheduleId'] as String).isEmpty) {
      return false;
    }
    final id =
        item[provider == AlarmProvider.localNotification.wireValue
            ? 'fallbackNotificationId'
            : 'nativeAlarmId'];
    return provider == AlarmProvider.iosAlarmKit.wireValue ||
        id == null ||
        id is int && id >= -2147483648 && id <= 2147483647;
  }

  static ScheduledAlarmRecord _safe(ScheduledAlarmRecord record) {
    final current = ScheduleWithPreparationEntity.isCurrentIdentity(
      record.scheduleFingerprint,
    );
    final payload = minimalScheduleRoutePayload({
      ...record.payload,
      'type': record.payload['type'] == 'schedule_alarm'
          ? 'schedule_alarm'
          : 'schedule_notification',
      'scheduleId': record.scheduleId,
    });
    return ScheduledAlarmRecord(
      scheduleId: record.scheduleId,
      alarmTime: record.alarmTime,
      preparationStartTime: record.preparationStartTime,
      scheduleFingerprint: current ? record.scheduleFingerprint : '',
      nativeAlarmId: record.nativeAlarmId,
      fallbackNotificationId: record.fallbackNotificationId,
      provider: record.provider,
      scheduleTitle: current ? record.scheduleTitle : 'OnTime',
      payload: {
        if (current) ...payload,
        if (current)
          'detailedNotificationContent':
              (record.payload['detailedNotificationContent'] == 'true')
                  .toString(),
        if (current &&
            record.payload['detailedNotificationContent'] == 'true' &&
            record.payload['notificationTimeZone'] != null)
          'notificationTimeZone': record.payload['notificationTimeZone']!,
      },
      contentDigest: current ? record.contentDigest : null,
      contentVersion: current ? record.contentVersion : null,
      contentLanguageCode: current ? record.contentLanguageCode : null,
      // The enum is a scheduling receipt, not private content. Keep it even
      // on a minimal cancellation tombstone with no fingerprint/content.
      notificationTiming: record.notificationTiming,
      cancellationPending: record.cancellationPending || !current,
      notificationContent: current ? record.notificationContent : null,
    );
  }

  @override
  Future<List<ScheduledAlarmRecord>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    String? raw;
    try {
      raw = prefs.getString(_prefsKey);
    } catch (_) {
      await _markUnknown(prefs);
      if (!await prefs.remove(_prefsKey)) {
        throw StateError('Corrupt registry privacy cleanup failed');
      }
      return const [];
    }
    if (raw == null) return const [];
    var unknown = raw.isEmpty;
    final records = <ScheduledAlarmRecord>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is! Map<String, dynamic> || !_validIdentity(item)) {
            unknown = true;
            continue;
          }
          try {
            records.add(_safe(ScheduledAlarmRecordModel.fromJson(item).record));
          } catch (_) {
            // Preserve usable cancellation ownership even when dates/content
            // are malformed. Never keep the original arbitrary payload.
            final id = item['scheduleId'];
            final provider = AlarmProviderWireValue.fromWireValue(
              item['provider'] is String ? item['provider'] as String : null,
            );
            if (id is String &&
                id.isNotEmpty &&
                provider != AlarmProvider.none) {
              records.add(
                _safe(
                  ScheduledAlarmRecord(
                    scheduleId: id,
                    alarmTime: DateTime.fromMillisecondsSinceEpoch(
                      0,
                      isUtc: true,
                    ),
                    preparationStartTime: DateTime.fromMillisecondsSinceEpoch(
                      0,
                      isUtc: true,
                    ),
                    scheduleFingerprint: '',
                    provider: provider,
                    scheduleTitle: 'OnTime',
                    payload: const {},
                    nativeAlarmId: item['nativeAlarmId'] is int
                        ? item['nativeAlarmId'] as int
                        : null,
                    fallbackNotificationId:
                        item['fallbackNotificationId'] is int
                        ? item['fallbackNotificationId'] as int
                        : null,
                    cancellationPending: true,
                  ),
                ),
              );
            }
          }
        }
      } else {
        unknown = true;
      }
    } catch (_) {
      unknown = true;
    }
    // Preserve only uncertainty before scrubbing raw content. Reset migrates
    // this receipt into its independent journal before clearing preferences.
    if (unknown) await _markUnknown(prefs);
    final encoded = jsonEncode(
      records
          .map((record) => ScheduledAlarmRecordModel(record).toJson())
          .toList(),
    );
    if (raw != encoded) await replaceAll(records);
    return records;
  }

  @override
  Future<void> replaceAll(List<ScheduledAlarmRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final success = records.isEmpty
        ? await prefs.remove(_prefsKey)
        : await prefs.setString(
            _prefsKey,
            jsonEncode(
              records
                  .map(
                    (record) =>
                        ScheduledAlarmRecordModel(_safe(record)).toJson(),
                  )
                  .toList(),
            ),
          );
    if (!success) throw StateError('Alarm registry privacy write failed');
  }
}
