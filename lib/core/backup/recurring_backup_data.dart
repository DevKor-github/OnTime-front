import 'dart:convert';

import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/mappers/recurrence_codec.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/recurrence/recurrence_engine.dart';

/// Durable recurrence state in portable backup format 2. Format 1 has none.
class RecurringBackupData {
  const RecurringBackupData({
    this.definitions = const [],
    this.steps = const [],
    this.segments = const [],
    this.exclusions = const [],
  });
  final List<PreparationDefinition> definitions;
  final List<PreparationDefinitionStep> steps;
  final List<RecurringScheduleSegment> segments;
  final List<RecurringScheduleExclusion> exclusions;

  static Future<RecurringBackupData> capture(AppDatabase db) async =>
      RecurringBackupData(
        definitions: await db.select(db.preparationDefinitions).get(),
        steps: await db.select(db.preparationDefinitionSteps).get(),
        segments: await db.select(db.recurringScheduleSegments).get(),
        exclusions: await db.select(db.recurringScheduleExclusions).get(),
      );

  Map<String, Object?> toJson() => {
    'definitions': definitions.map((r) => r.toJson()).toList(),
    'steps': steps.map((r) => r.toJson()).toList(),
    'segments': segments.map((r) => _portableSegment(r.toJson())).toList(),
    'exclusions': exclusions.map((r) => r.toJson()).toList(),
  };

  static Map<String, dynamic> _portableSegment(Map<String, dynamic> source) => {
    for (final key in [
      'id',
      'seriesId',
      'ruleJson',
      'scheduleJson',
      'preparationId',
      'fromSlot',
      'beforeSlot',
      'createdAt',
      'preparationNotBefore',
    ])
      key: source[key],
  };

  factory RecurringBackupData.fromJson(Object? value) {
    try {
      final map = value as Map<String, dynamic>;
      List<T> rows<T>(String key, T Function(Map<String, dynamic>) parse) =>
          (map[key] as List)
              .map((v) => parse(v as Map<String, dynamic>))
              .toList();
      return RecurringBackupData(
        definitions: rows('definitions', PreparationDefinition.fromJson),
        steps: rows('steps', PreparationDefinitionStep.fromJson),
        segments: rows(
          'segments',
          (json) => RecurringScheduleSegment.fromJson(_portableSegment(json)),
        ),
        exclusions: rows('exclusions', RecurringScheduleExclusion.fromJson),
      );
    } catch (_) {
      throw const FormatException('Invalid recurring schedule backup.');
    }
  }

  void validate(List<ScheduleEntity> schedules) {
    Never invalid() => throw const FormatException(
      'Invalid recurring schedule references or values.',
    );
    final definitionsById = {for (final d in definitions) d.id: d};
    final segmentsById = {for (final s in segments) s.id: s};
    if (definitionsById.length != definitions.length ||
        segmentsById.length != segments.length) {
      invalid();
    }
    for (final d in definitions) {
      if (d.id.isEmpty ||
          d.ownerId.isEmpty ||
          !{'recurring', 'occurrence', 'template'}.contains(d.scope)) {
        invalid();
      }
      final own = steps.where((s) => s.definitionId == d.id).toList()
        ..sort((a, b) => a.position.compareTo(b.position));
      if (own.isEmpty) invalid();
      for (var i = 0; i < own.length; i++) {
        if (own[i].position != i) invalid();
      }
    }
    final stepIds = <String>{};
    for (final step in steps) {
      if (step.id.isEmpty ||
          !stepIds.add(step.id) ||
          !definitionsById.containsKey(step.definitionId) ||
          step.name.trim().isEmpty ||
          step.name.length > 30 ||
          step.minutes < 0 ||
          step.minutes > 1440) {
        invalid();
      }
    }
    for (final segment in segments) {
      if (segment.id.isEmpty ||
          segment.seriesId.isEmpty ||
          !definitionsById.containsKey(segment.preparationId)) {
        invalid();
      }
      try {
        final rule = RecurrenceCodec.ruleFromJson(jsonDecode(segment.ruleJson));
        final schedule = RecurrenceCodec.scheduleFromJson(
          jsonDecode(segment.scheduleJson),
        );
        final from = DateTime.parse(segment.fromSlot);
        final before = segment.beforeSlot == null
            ? null
            : DateTime.parse(segment.beforeSlot!);
        if (from.isBefore(rule.start) ||
            (before?.isBefore(from) ?? false) ||
            schedule.timeZoneId != rule.timeZoneId ||
            schedule.moveTime.isNegative ||
            (schedule.scheduleSpareTime?.isNegative ?? false) ||
            schedule.scheduleName.trim().isEmpty) {
          invalid();
        }
        // Also validates the named time zone without expanding the full series.
        const RecurrenceEngine().expand(rule, through: rule.start, limit: 1);
      } catch (_) {
        invalid();
      }
    }
    final keys = <String>{};
    for (final e in exclusions) {
      if (!segmentsById.containsKey(e.segmentId) ||
          e.ordinal < 1 ||
          DateTime.tryParse(e.slotKey) == null ||
          !keys.add('${e.segmentId}/${e.slotKey}')) {
        invalid();
      }
    }
    const fields = {
      'name',
      'time',
      'place',
      'move',
      'spare',
      'note',
      'preparation',
    };
    for (final s in schedules) {
      final metadata = [
        s.recurringSegmentId,
        s.recurringSlotKey,
        s.recurringOrdinal,
      ];
      if (metadata.any((v) => v != null) && metadata.any((v) => v == null)) {
        invalid();
      }
      if (s.preparationDefinitionId != null &&
          !definitionsById.containsKey(s.preparationDefinitionId)) {
        invalid();
      }
      if (s.isRecurring &&
          (!segmentsById.containsKey(s.recurringSegmentId) ||
              s.preparationDefinitionId == null ||
              s.recurringOrdinal! < 1 ||
              DateTime.tryParse(s.recurringSlotKey!) == null)) {
        invalid();
      }
      if (s.recurringOverrides
          .split(',')
          .where((s) => s.isNotEmpty)
          .any((s) => !fields.contains(s))) {
        invalid();
      }
    }
  }

  Future<void> restore(AppDatabase db) async {
    for (final value in definitions) {
      await db.into(db.preparationDefinitions).insert(value.toCompanion(false));
    }
    for (final value in steps) {
      await db
          .into(db.preparationDefinitionSteps)
          .insert(value.toCompanion(false));
    }
    for (final value in segments) {
      await db
          .into(db.recurringScheduleSegments)
          .insert(value.toCompanion(false));
    }
    for (final value in exclusions) {
      await db
          .into(db.recurringScheduleExclusions)
          .insert(value.toCompanion(false));
    }
  }
}
