import 'package:on_time_front/core/database/restore_runtime_identity.dart';
import 'dart:convert';

import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
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
    final identity = RestoreRuntimeIdentity.shared;
    final incarnation = identity.storeIncarnation;
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefsKeyPrefix$scheduleId';

    if (!ScheduleWithPreparationEntity.isCurrentIdentity(
      snapshot.scheduleFingerprint,
    )) {
      throw StateError('Unvalidated preparation snapshot cannot be persisted');
    }
    final jsonMap = {
      'schemaVersion': 2,
      'storeIncarnation': ?incarnation,
      if (snapshot.requiresConfirmation) 'requiresConfirmation': true,
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
              'elapsed': s.elapsedTime.inMilliseconds,
              'isDone': s.isDone,
            },
          )
          .toList(),
    };

    if (!identity.accepts(incarnation)) throw StateError('Old runtime owner');
    if (!await prefs.setString(key, jsonEncode(jsonMap))) {
      throw StateError('Preparation snapshot was not saved');
    }
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
      if (!RestoreRuntimeIdentity.shared.accepts(map['storeIncarnation'])) {
        return null;
      }
      final minimal = map['schemaVersion'] == 2;
      if (map['schemaVersion'] != null && !minimal) return null;
      final List<dynamic> steps = map['steps'] as List<dynamic>;

      final stepEntities = steps.map((raw) {
        final m = raw as Map<String, dynamic>;
        return PreparationStepWithTimeEntity(
          id: m['id'] as String,
          preparationName: minimal ? '' : m['name'] as String,
          preparationTime: minimal
              ? Duration.zero
              : Duration(milliseconds: (m['time'] as num).toInt()),
          nextPreparationId: minimal ? null : m['nextId'] as String?,
          elapsedTime: Duration(milliseconds: (m['elapsed'] as num).toInt()),
          isDone: m['isDone'] as bool? ?? false,
        );
      }).toList();

      if (stepEntities.any((step) => step.elapsedTime.isNegative)) return null;
      final savedAtMillis = (map['savedAt'] as num?)?.toInt();
      final startedAtMillis = (map['startedAt'] as num?)?.toInt();
      final scheduleFingerprint = map['scheduleFingerprint'] as String? ?? '';
      final actionEvents = _actionEventsFromJson(
        map['actionEvents'],
        supplied: map.containsKey('actionEvents'),
      );
      if (minimal &&
          !ScheduleWithPreparationEntity.isCurrentIdentity(
            scheduleFingerprint,
          )) {
        return null;
      }

      if (savedAtMillis == null || scheduleFingerprint.isEmpty) return null;
      return TimedPreparationSnapshotEntity(
        contentOmitted: minimal,
        requiresConfirmation: map['requiresConfirmation'] == true,
        preparation: PreparationWithTimeEntity(
          preparationStepList: stepEntities,
        ),
        savedAt: DateTime.fromMillisecondsSinceEpoch(savedAtMillis),
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
    if (!await prefs.remove(key)) {
      throw StateError('Preparation snapshot was not removed');
    }
  }
}

List<PreparationActionEventEntity> _actionEventsFromJson(
  Object? raw, {
  required bool supplied,
}) {
  if (!supplied) return const [];
  if (raw is! List<dynamic>) {
    throw const FormatException('Invalid preparation events');
  }
  final events = <PreparationActionEventEntity>[];
  for (final item in raw) {
    if (item is! Map<String, dynamic>) {
      throw const FormatException('Invalid preparation event');
    }
    final typeName = item['type'];
    final occurredAtMillis = item['occurredAt'];
    final stepId = item['stepId'];
    if (typeName is! String ||
        occurredAtMillis is! int ||
        (stepId != null && (stepId is! String || stepId.isEmpty))) {
      throw const FormatException('Invalid preparation event fields');
    }
    final type = PreparationActionEventType.values
        .where((value) => value.name == typeName)
        .firstOrNull;
    if (type == null ||
        (type == PreparationActionEventType.skipStep && stepId == null)) {
      throw const FormatException('Invalid preparation event type');
    }
    events.add(
      PreparationActionEventEntity(
        type: type,
        occurredAt: DateTime.fromMillisecondsSinceEpoch(occurredAtMillis),
        stepId: stepId as String?,
      ),
    );
  }
  return events;
}
