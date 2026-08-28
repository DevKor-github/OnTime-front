import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:on_time_front/core/database/installation_key_store.dart';
import 'package:on_time_front/core/database/local_data_files.dart';
import 'package:on_time_front/core/services/alarm_scheduler_service.dart';
import 'package:on_time_front/core/services/fallback_alarm_notification_service.dart';
import 'package:on_time_front/core/services/notification_service.dart';
import 'package:on_time_front/data/models/scheduled_alarm_record_model.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class LocalDataLifecycle {
  static const _storage = FlutterSecureStorage();
  static const _cutoverMarker = 'ontime_local_only_cutover_v1';
  static const _resetMarker = 'ontime_local_reset_pending_v1';
  static const _alarmRegistryKey = 'scheduled_alarm_registry';
  static const _legacyTokenKeys = ['accessToken', 'refreshToken'];
  static const _legacyIosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  static Future<void> bootstrap() async {
    if (await _storage.read(key: _resetMarker) != null) {
      await _finishInterruptedReset();
    }
    if (await _storage.read(key: _cutoverMarker) == null) {
      await _performOneWayCutover();
    }
  }

  static Future<void> markResetPending() =>
      _storage.write(key: _resetMarker, value: 'pending');

  static Future<void> _performOneWayCutover() async {
    await deleteLocalDatabaseFiles(includeLegacy: true);
    await (await SharedPreferences.getInstance()).clear();
    for (final key in _legacyTokenKeys) {
      await _storage.delete(key: key);
      await _storage.delete(key: key, iOptions: _legacyIosOptions);
    }
    await _storage.write(key: _cutoverMarker, value: 'complete');
  }

  static Future<void> _finishInterruptedReset() async {
    final preferences = await SharedPreferences.getInstance();
    final records = _readAlarmRecords(preferences.getString(_alarmRegistryKey));
    final scheduler = AlarmSchedulerService();
    final fallback = FallbackAlarmNotificationServiceImpl();
    for (final record in records) {
      try {
        if (record.provider == AlarmProvider.localNotification) {
          await fallback.cancelFallbackAlarm(record);
        } else if (record.provider != AlarmProvider.none) {
          await scheduler.cancelNativeAlarm(record);
        }
      } catch (_) {
        // The marker remains until local files and credentials are removed.
      }
    }
    await NotificationService.instance.cancelAll().catchError((_) {});
    await deleteLocalDatabaseFiles(includeLegacy: true);
    await preferences.clear();
    await InstallationKeyStore().delete();
    for (final key in _legacyTokenKeys) {
      await _storage.delete(key: key);
      await _storage.delete(key: key, iOptions: _legacyIosOptions);
    }
    await _storage.delete(key: _resetMarker);
  }

  static List<ScheduledAlarmRecord> _readAlarmRecords(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map(
            (item) => ScheduledAlarmRecordModel.fromJson(
              item as Map<String, dynamic>,
            ).record,
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
