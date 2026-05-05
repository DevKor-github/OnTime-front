import 'dart:convert';

import 'package:injectable/injectable.dart';
import 'package:on_time_front/data/models/scheduled_alarm_record_model.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class AlarmRegistryLocalDataSource {
  Future<List<ScheduledAlarmRecord>> loadAll();

  Future<void> replaceAll(List<ScheduledAlarmRecord> records);
}

@Injectable(as: AlarmRegistryLocalDataSource)
class AlarmRegistryLocalDataSourceImpl implements AlarmRegistryLocalDataSource {
  static const _prefsKey = 'scheduled_alarm_registry';

  @override
  Future<List<ScheduledAlarmRecord>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString(_prefsKey);
    if (rawValue == null || rawValue.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(rawValue) as List<dynamic>;
      return decoded
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

  @override
  Future<void> replaceAll(List<ScheduledAlarmRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    if (records.isEmpty) {
      await prefs.remove(_prefsKey);
      return;
    }

    await prefs.setString(
      _prefsKey,
      jsonEncode(
        records
            .map((record) => ScheduledAlarmRecordModel(record).toJson())
            .toList(),
      ),
    );
  }
}
