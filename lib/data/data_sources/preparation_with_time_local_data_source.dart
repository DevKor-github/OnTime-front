import 'dart:convert';

import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:on_time_front/domain/entities/preparation_action_event_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_with_time_entity.dart';
import 'package:on_time_front/domain/entities/timed_preparation_snapshot_entity.dart';

abstract interface class PreparationWithTimeLocalDataSource {
  Future<void> savePreparation(
    String scheduleId,
    TimedPreparationSnapshotEntity snapshot,
  );
  Future<TimedPreparationSnapshotEntity?> loadPreparation(String scheduleId);
  Future<void> clearPreparation(String scheduleId);
}

@Injectable(as: PreparationWithTimeLocalDataSource)
class PreparationWithTimeLocalDataSourceImpl
    implements PreparationWithTimeLocalDataSource {
  static const String _prefsKeyPrefix = 'preparation_with_time_';

  @override
  Future<void> savePreparation(
    String scheduleId,
    TimedPreparationSnapshotEntity snapshot,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefsKeyPrefix$scheduleId';

    final jsonMap = {
      'savedAt': snapshot.savedAt.millisecondsSinceEpoch,
      'startedAt': snapshot.startedAt?.millisecondsSinceEpoch,
      'scheduleFingerprint': snapshot.scheduleFingerprint,
      'actionEvents': snapshot.actionEvents
          .map(
            (event) => {
              'type': event.type.name,
              'occurredAt': event.occurredAt.millisecondsSinceEpoch,
              'stepId': event.stepId,
            },
          )
          .toList(),
      'steps': snapshot.preparation.preparationStepList
          .map(
            (s) => {
              'id': s.id,
              'name': s.preparationName,
              'time': s.preparationTime.inMilliseconds,
              'nextId': s.nextPreparationId,
              'elapsed': s.elapsedTime.inMilliseconds,
              'isDone': s.isDone,
            },
          )
          .toList(),
    };

    await prefs.setString(key, jsonEncode(jsonMap));
  }

  @override
  Future<TimedPreparationSnapshotEntity?> loadPreparation(
    String scheduleId,
  ) async {
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
      final startedAtMillis = (map['startedAt'] as num?)?.toInt();
      final scheduleFingerprint = map['scheduleFingerprint'] as String? ?? '';
      final actionEvents = _actionEventsFromJson(map['actionEvents']);

      return TimedPreparationSnapshotEntity(
        preparation: PreparationWithTimeEntity(
          preparationStepList: stepEntities,
        ),
        savedAt: savedAtMillis == null
            ? DateTime.now()
            : DateTime.fromMillisecondsSinceEpoch(savedAtMillis),
        startedAt: startedAtMillis == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(startedAtMillis),
        scheduleFingerprint: scheduleFingerprint,
        actionEvents: actionEvents,
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

List<PreparationActionEventEntity> _actionEventsFromJson(Object? raw) {
  if (raw is! List<dynamic>) return const [];
  final events = <PreparationActionEventEntity>[];
  for (final item in raw) {
    if (item is! Map<String, dynamic>) continue;
    final typeName = item['type'] as String?;
    final occurredAtMillis = (item['occurredAt'] as num?)?.toInt();
    if (typeName == null || occurredAtMillis == null) continue;
    final type = PreparationActionEventType.values
        .where((value) => value.name == typeName)
        .firstOrNull;
    if (type == null) continue;
    events.add(
      PreparationActionEventEntity(
        type: type,
        occurredAt: DateTime.fromMillisecondsSinceEpoch(occurredAtMillis),
        stepId: item['stepId'] as String?,
      ),
    );
  }
  return events;
}
