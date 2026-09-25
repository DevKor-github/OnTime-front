import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/mappers/recurrence_codec.dart';

/// Transaction-internal cleanup of content owned by the rows being removed.
/// Never scans or collects unrelated pre-existing orphan content.
Future<bool> removeScheduleOwnedContent(AppDatabase db, String id) async {
  final row = await removeScheduleRow(db, id);
  if (row == null) return false;
  if (row.preparationDefinitionId case final String definition) {
    await collectUnusedScheduleDefinition(db, definition);
  }
  await collectUnusedSchedulePlace(db, row.placeId);
  return true;
}

/// Removes projection rows while preserving content ownership for replacement.
/// Explicit deletion uses removeScheduleOwnedContent instead.
Future<Schedule?> removeScheduleRow(AppDatabase db, String id) async {
  final row = await (db.select(
    db.schedules,
  )..where((t) => t.id.equals(id))).getSingleOrNull();
  if (row == null) return null;
  await (db.update(
    db.preparationSchedules,
  )..where((t) => t.scheduleId.equals(id))).write(
    const PreparationSchedulesCompanion(nextPreparationId: Value(null)),
  );
  await (db.delete(
    db.preparationSchedules,
  )..where((t) => t.scheduleId.equals(id))).go();
  await (db.delete(db.schedules)..where((t) => t.id.equals(id))).go();
  return row;
}

Future<void> collectUnusedScheduleDefinition(
  AppDatabase db,
  String candidate,
) async {
  final unused = await db
      .customSelect(
        "SELECT id FROM preparation_definitions d WHERE id=? AND scope IN ('recurring','occurrence') AND NOT EXISTS(SELECT 1 FROM schedules s WHERE s.preparation_definition_id=d.id) AND NOT EXISTS(SELECT 1 FROM recurring_schedule_segments r WHERE r.preparation_id=d.id)",
        variables: [Variable(candidate)],
      )
      .get();
  if (unused.isEmpty) return;
  await (db.delete(
    db.preparationDefinitionSteps,
  )..where((t) => t.definitionId.equals(candidate))).go();
  await (db.delete(
    db.preparationDefinitions,
  )..where((t) => t.id.equals(candidate))).go();
}

Future<void> collectUnusedSchedulePlace(
  AppDatabase db,
  String candidate,
) async {
  final schedules =
      await (db.select(db.schedules)
            ..where((t) => t.placeId.equals(candidate))
            ..limit(1))
          .get();
  if (schedules.isNotEmpty) return;
  // Segments own their source Place even without any materialized occurrences.
  // The reference is JSON, not a SQLite FK. Invalid content cannot prove orphanage.
  for (final segment in await db.select(db.recurringScheduleSegments).get()) {
    try {
      final source = RecurrenceCodec.scheduleFromJson(
        Map<String, dynamic>.from(jsonDecode(segment.scheduleJson) as Map),
      );
      if (source.place.id == candidate) return;
    } catch (_) {
      return;
    }
  }
  await (db.delete(db.places)..where((t) => t.id.equals(candidate))).go();
}
