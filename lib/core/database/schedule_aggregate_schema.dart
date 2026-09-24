import 'package:on_time_front/core/database/database.dart';

/// Metadata belongs to the aggregate, not a global mutation log. SQL triggers
/// also observe legacy writers; merely materializing a new occurrence is not an
/// edit of an existing aggregate. None of these fields enter portable backups.
Future<void> installAggregateConcurrency(AppDatabase db) async {
  for (final table in ['schedules', 'recurring_schedule_segments']) {
    await db.customStatement(
      'UPDATE $table SET aggregate_incarnation = lower(hex(randomblob(16))), aggregate_version = 0 WHERE aggregate_incarnation IS NULL',
    );
    await db.customStatement(
      '''CREATE TRIGGER ${table}_identity AFTER INSERT ON $table
      WHEN NEW.aggregate_incarnation IS NULL BEGIN
      UPDATE $table SET aggregate_incarnation = lower(hex(randomblob(16))), aggregate_version = 0 WHERE id = NEW.id; END''',
    );
  }
  await db.customStatement(
    'UPDATE users SET store_incarnation = lower(hex(randomblob(16))) WHERE store_incarnation IS NULL',
  );
  await db.customStatement(
    '''CREATE TRIGGER users_identity AFTER INSERT ON users WHEN NEW.store_incarnation IS NULL BEGIN
    UPDATE users SET store_incarnation = lower(hex(randomblob(16))) WHERE id = NEW.id; END''',
  );
  await db.customStatement(
    "UPDATE recurring_schedule_segments SET root_segment_id = (SELECT r.id FROM recurring_schedule_segments r WHERE r.series_id = recurring_schedule_segments.series_id ORDER BY r.created_at,r.id LIMIT 1) WHERE root_segment_id IS NULL",
  );
  await db.customStatement(
    "CREATE TRIGGER segment_root AFTER INSERT ON recurring_schedule_segments WHEN NEW.root_segment_id IS NULL BEGIN UPDATE recurring_schedule_segments SET root_segment_id = COALESCE((SELECT root_segment_id FROM recurring_schedule_segments WHERE series_id=NEW.series_id AND root_segment_id IS NOT NULL LIMIT 1), NEW.id) WHERE id=NEW.id; END",
  );
  const scheduleFields = [
    'place_id',
    'schedule_name',
    'time_zone_id',
    'occurrence_offset_seconds',
    'schedule_time',
    'move_time',
    'is_changed',
    'is_started',
    'schedule_spare_time',
    'schedule_note',
    'lateness_time',
    'done_status',
    'started_at',
    'finished_at',
    'preparation_mode',
    'preparation_template_id',
    'preparation_template_name',
    'preparation_template_deleted',
    'preparation_frozen',
    'score_contribution_recorded',
    'recurring_segment_id',
    'recurring_slot_key',
    'recurring_ordinal',
    'recurring_overrides',
    'preparation_definition_id',
  ];
  String changed(List<String> fields) =>
      fields.map((f) => 'NEW.$f IS NOT OLD.$f').join(' OR ');
  String rootFor(String segment) =>
      'id = (SELECT root_segment_id FROM recurring_schedule_segments WHERE id = $segment)';
  String invalidateRoots(String schedulePredicate) =>
      'UPDATE recurring_schedule_segments SET aggregate_version=COALESCE(aggregate_version,0)+1 WHERE id IN (SELECT r.root_segment_id FROM recurring_schedule_segments r JOIN schedules s ON s.recurring_segment_id=r.id WHERE $schedulePredicate);';
  await db.customStatement(
    '''CREATE TRIGGER schedules_version AFTER UPDATE OF ${scheduleFields.join(',')} ON schedules
    WHEN ${changed(scheduleFields)} BEGIN
    UPDATE schedules SET aggregate_version = COALESCE(aggregate_version,0)+1 WHERE id = NEW.id;
    UPDATE recurring_schedule_segments SET aggregate_version = COALESCE(aggregate_version,0)+1 WHERE ${rootFor('OLD.recurring_segment_id')}; END''',
  );
  await db.customStatement(
    '''CREATE TRIGGER schedules_deleted AFTER DELETE ON schedules BEGIN
    UPDATE recurring_schedule_segments SET aggregate_version = COALESCE(aggregate_version,0)+1 WHERE ${rootFor('OLD.recurring_segment_id')}; END''',
  );
  const segmentFields = [
    'rule_json',
    'schedule_json',
    'preparation_id',
    'from_slot',
    'before_slot',
    'preparation_not_before',
  ];
  await db.customStatement(
    '''CREATE TRIGGER segments_version AFTER UPDATE OF ${segmentFields.join(',')} ON recurring_schedule_segments
    WHEN ${changed(segmentFields)} BEGIN
    UPDATE recurring_schedule_segments SET aggregate_version = COALESCE(aggregate_version,0)+1 WHERE ${rootFor('NEW.id')}; END''',
  );
  for (final event in ['INSERT', 'UPDATE', 'DELETE']) {
    final row = event == 'DELETE' ? 'OLD' : 'NEW';
    await db.customStatement(
      'CREATE TRIGGER exclusion_${event.toLowerCase()} AFTER $event ON recurring_schedule_exclusions BEGIN UPDATE recurring_schedule_segments SET aggregate_version=COALESCE(aggregate_version,0)+1 WHERE ${rootFor('$row.segment_id')}; END',
    );
    await db.customStatement(
      '''CREATE TRIGGER preparation_schedule_${event.toLowerCase()} AFTER $event ON preparation_schedules BEGIN
      UPDATE schedules SET aggregate_version = COALESCE(aggregate_version,0)+1 WHERE id = $row.schedule_id;
      UPDATE recurring_schedule_segments SET aggregate_version = COALESCE(aggregate_version,0)+1 WHERE ${rootFor('(SELECT recurring_segment_id FROM schedules WHERE id = $row.schedule_id)')}; END''',
    );
    await db.customStatement(
      '''CREATE TRIGGER preparation_default_${event.toLowerCase()} AFTER $event ON preparation_users BEGIN
      UPDATE schedules SET aggregate_version = COALESCE(aggregate_version,0)+1 WHERE preparation_definition_id IS NULL AND NOT EXISTS (SELECT 1 FROM preparation_schedules p WHERE p.schedule_id=schedules.id) AND NOT EXISTS (SELECT 1 FROM preparation_templates p WHERE p.id=schedules.preparation_template_id AND schedules.preparation_template_deleted=0); ${invalidateRoots('s.preparation_definition_id IS NULL AND NOT EXISTS (SELECT 1 FROM preparation_schedules p WHERE p.schedule_id=s.id) AND NOT EXISTS (SELECT 1 FROM preparation_templates p WHERE p.id=s.preparation_template_id AND s.preparation_template_deleted=0)')} END''',
    );
  }
  for (final event in ['INSERT', 'UPDATE', 'DELETE']) {
    final row = event == 'DELETE' ? 'OLD' : 'NEW';
    await db.customStatement(
      "CREATE TRIGGER template_steps_${event.toLowerCase()} AFTER $event ON preparation_template_steps BEGIN UPDATE schedules SET aggregate_version=COALESCE(aggregate_version,0)+1 WHERE preparation_template_id=$row.template_id; ${invalidateRoots('s.preparation_template_id=$row.template_id')} END",
    );
    await db.customStatement(
      "CREATE TRIGGER definition_steps_${event.toLowerCase()} AFTER $event ON preparation_definition_steps BEGIN UPDATE schedules SET aggregate_version=COALESCE(aggregate_version,0)+1 WHERE preparation_definition_id=$row.definition_id; ${invalidateRoots('s.preparation_definition_id=$row.definition_id')} UPDATE recurring_schedule_segments SET aggregate_version=COALESCE(aggregate_version,0)+1 WHERE id IN (SELECT root_segment_id FROM recurring_schedule_segments WHERE preparation_id=$row.definition_id); END",
    );
  }
  for (final event in ['UPDATE', 'DELETE']) {
    await db.customStatement(
      "CREATE TRIGGER template_${event.toLowerCase()} AFTER $event ON preparation_templates BEGIN UPDATE schedules SET aggregate_version=COALESCE(aggregate_version,0)+1 WHERE preparation_template_id=OLD.id; ${invalidateRoots('s.preparation_template_id=OLD.id')} END",
    );
  }
  await db.customStatement(
    '''CREATE TRIGGER place_version AFTER UPDATE OF place_name ON places WHEN NEW.place_name IS NOT OLD.place_name BEGIN
    UPDATE schedules SET aggregate_version = COALESCE(aggregate_version,0)+1 WHERE place_id = NEW.id; ${invalidateRoots('s.place_id=NEW.id')} END''',
  );
}
