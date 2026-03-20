import 'dart:convert';

import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_with_time_entity.dart';
import 'package:on_time_front/domain/entities/timed_preparation_snapshot_entity.dart';

abstract interface class PreparationWithTimeLocalDataSource {
  Future<void> savePreparation(
      String scheduleId, TimedPreparationSnapshotEntity snapshot);
  Future<TimedPreparationSnapshotEntity?> loadPreparation(String scheduleId);
  Future<void> clearPreparation(String scheduleId);
}

@Injectable(as: PreparationWithTimeLocalDataSource)
class PreparationWithTimeLocalDataSourceImpl
    implements PreparationWithTimeLocalDataSource {
  static const String _prefsKeyPrefix = 'preparation_with_time_';

  @override
  Future<void> savePreparation(
      String scheduleId, TimedPreparationSnapshotEntity snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefsKeyPrefix$scheduleId';

    final jsonMap = {
      'savedAt': snapshot.savedAt.millisecondsSinceEpoch,
      'scheduleFingerprint': snapshot.scheduleFingerprint,
      'steps': snapshot.preparation.preparationStepList
          .map((s) => {
                'id': s.id,
                'name': s.preparationName,
                'time': s.preparationTime.inMilliseconds,
                'nextId': s.nextPreparationId,
                'elapsed': s.elapsedTime.inMilliseconds,
                'isDone': s.isDone,
              })
          .toList()
    };

    await prefs.setString(key, jsonEncode(jsonMap));
  }

  @override
  Future<TimedPreparationSnapshotEntity?> loadPreparation(
      String scheduleId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefsKeyPrefix$scheduleId';
    final jsonString = prefs.getString(key);
    if (jsonString == null) return null;

    try {
      final Map<String, dynamic> map = jsonDecode(jsonString);
      final List<dynamic> steps = map['steps'] as List<dynamic>;

      final stepEntities = steps.map((raw) {
        final m = raw as Map<String, dynamic>;
        return PreparationStepWithTimeEntity(
          id: m['id'] as String,
          preparationName: m['name'] as String,
          preparationTime: Duration(milliseconds: (m['time'] as num).toInt()),
          nextPreparationId: m['nextId'] as String?,
          elapsedTime: Duration(milliseconds: (m['elapsed'] as num).toInt()),
          isDone: m['isDone'] as bool? ?? false,
        );
      }).toList();

      final savedAtMillis = (map['savedAt'] as num?)?.toInt();
      final scheduleFingerprint = map['scheduleFingerprint'] as String? ?? '';

      return TimedPreparationSnapshotEntity(
        preparation:
            PreparationWithTimeEntity(preparationStepList: stepEntities),
        savedAt: savedAtMillis == null
            ? DateTime.now()
            : DateTime.fromMillisecondsSinceEpoch(savedAtMillis),
        scheduleFingerprint: scheduleFingerprint,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clearPreparation(String scheduleId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefsKeyPrefix$scheduleId';
    await prefs.remove(key);
  }
}
