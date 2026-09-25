import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:on_time_front/core/backup/backup_limits.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/time/schedule_time_resolution.dart';
import 'package:on_time_front/core/time/time_correction_conflicts.dart';
import 'package:on_time_front/core/time/time_zone_rules.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_preparation_mode.dart';
import 'package:on_time_front/data/mappers/recurrence_codec.dart';
import 'package:on_time_front/core/constants/local_profile.dart';

/// Active-store read adapter only. Staging supplies its own authenticated graph
/// to the pure scanner instead of calling this adapter or an active repository.
final class TimeCorrectionConflictWorld {
  const TimeCorrectionConflictWorld(
    this.rows,
    this.segments,
    this.exclusions,
    this.possibleOverlaps,
  );
  final List<TimeCorrectionBusyInterval> rows;
  final List<RecurringSegment> segments;
  final Map<String, Set<String>> exclusions;
  final List<TimeCorrectionPossibleOverlap> possibleOverlaps;
  Set<String> get unresolvedIds => possibleOverlaps.map((e) => e.id).toSet();
}

Future<TimeCorrectionConflictWorld> readTimeCorrectionConflictWorld({
  required AppDatabase db,
  required DateTime nowUtc,
  required BackupBudget budget,
  Set<String> ignoredIds = const {},
  Map<String, DateTime> closingSeriesAt = const {},
}) async {
  final preparations = _BoundedPreparations(db, budget);
  final stored = await db.scheduleDao.getScheduleList(
    limit: BackupLimits.schedules + 1,
  );
  if (stored.length > BackupLimits.schedules) {
    BackupLimits.exceeded('schedules');
  }
  budget.visit(stored.length);
  final rawSegments = await (db.select(
    db.recurringScheduleSegments,
  )..limit(BackupLimits.records + 1)).get();
  if (rawSegments.length + stored.length > BackupLimits.records) {
    BackupLimits.exceeded('records');
  }
  budget.visit(rawSegments.length);
  final rawExclusions = await (db.select(
    db.recurringScheduleExclusions,
  )..limit(BackupLimits.records + 1)).get();
  if (rawSegments.length + rawExclusions.length + stored.length >
      BackupLimits.records) {
    BackupLimits.exceeded('records');
  }
  budget.visit(rawExclusions.length);
  final exclusions = <String, Set<String>>{};
  for (final value in rawExclusions) {
    (exclusions[value.segmentId] ??= {}).add(value.slotKey);
  }
  final unresolved = <TimeCorrectionPossibleOverlap>[];
  final rows = <TimeCorrectionBusyInterval>[];
  for (final joined in stored) {
    final value = joined.toScheduleEntity();
    // Every materialized reference owns its original slot, including unresolved
    // overrides. Its uncertainty must never resurrect the base appointment.
    if (value.recurringSegmentId != null && value.recurringSlotKey != null) {
      (exclusions[value.recurringSegmentId!] ??= {}).add(
        value.recurringSlotKey!,
      );
    }
    if (ignoredIds.contains(value.id)) continue;
    final active =
        value.isStarted && value.startedAt != null && value.preparationFrozen;
    if (value.retainedRecurringReference && !active) continue;
    final resolution = ScheduleTimeResolver.resolve(value, nowUtc: nowUtc);
    final instant = resolution.instantUtc;
    if (instant == null) {
      if (value.doneStatus != ScheduleDoneStatus.notEnded ||
          (resolution.isHistorical && !active)) {
        continue;
      }
      final preparation = await preparations.schedule(value);
      final lead =
          preparation.totalDuration +
          value.moveTime +
          (value.scheduleSpareTime ?? Duration.zero);
      DateTime? earliest, latest;
      try {
        final civil = CivilDateTime.fromFields(
          value.scheduleTime,
        ).toUtcCarrier();
        earliest = civil.subtract(const Duration(days: 1) + lead);
        latest = active ? null : civil.add(const Duration(days: 1));
      } on FormatException {
        /* Unknown range remains a possible impact. */
      }
      if (latest != null && latest.isBefore(nowUtc)) continue;
      unresolved.add(
        TimeCorrectionPossibleOverlap(
          id: value.id,
          name: value.scheduleName,
          reason: resolution.status.name,
          originalCivil: value.scheduleTime,
          timeZoneId: value.timeZoneId,
          earliestPreparationUtc: earliest,
          latestTargetUtc: latest,
        ),
      );
      continue;
    }
    final preparation = await preparations.schedule(value);
    budget.visit(preparation.preparationStepList.length + 1);
    if (preparation.preparationStepList.length >
        BackupLimits.preparationSteps) {
      BackupLimits.exceeded('preparationSteps');
    }
    rows.add(
      TimeCorrectionBusyInterval(
        value,
        instant.subtract(
          preparation.totalDuration +
              value.moveTime +
              (value.scheduleSpareTime ?? Duration.zero),
        ),
        instant,
      ),
    );
  }
  final segments = <RecurringSegment>[];
  for (final raw in rawSegments) {
    final value = RecurringSegment(
      id: raw.id,
      seriesId: raw.seriesId,
      rule: RecurrenceCodec.ruleFromJson(jsonDecode(raw.ruleJson)),
      schedule: RecurrenceCodec.scheduleFromJson(jsonDecode(raw.scheduleJson)),
      preparation: await preparations.definition(raw.preparationId),
      preparationId: raw.preparationId,
      fromSlot: CivilDateTime.parse(raw.fromSlot).toUtcCarrier(),
      beforeSlot: raw.beforeSlot == null
          ? null
          : CivilDateTime.parse(raw.beforeSlot!).toUtcCarrier(),
      createdAt: raw.createdAt,
      preparationNotBefore: raw.preparationNotBefore,
    );
    budget.visit(value.preparation.preparationStepList.length + 1);
    if (value.preparation.preparationStepList.length >
        BackupLimits.preparationSteps) {
      BackupLimits.exceeded('preparationSteps');
    }
    var before = value.beforeSlot;
    final close = closingSeriesAt[value.seriesId];
    if (close != null && (before == null || before.isAfter(close))) {
      before = close.isBefore(value.fromSlot) ? value.fromSlot : close;
    }
    if (before != null && !before.isAfter(value.fromSlot)) continue;
    if (!TimeZoneRules.contains(value.rule.timeZoneId)) {
      final earliest = value.rule.start.subtract(
        const Duration(days: 1) + value.leadTime,
      );
      final end = before ?? value.rule.until;
      final latest = end?.add(const Duration(days: 2));
      if (latest == null || !latest.isBefore(nowUtc)) {
        unresolved.add(
          TimeCorrectionPossibleOverlap(
            id: 'segment:${value.id}',
            name: value.schedule.scheduleName,
            reason: 'unknownZone',
            originalCivil: value.rule.start,
            timeZoneId: value.rule.timeZoneId,
            rule: value.rule,
            earliestPreparationUtc: earliest,
            latestTargetUtc: latest,
          ),
        );
      }
      continue;
    }
    segments.add(
      RecurringSegment(
        id: value.id,
        seriesId: value.seriesId,
        rule: value.rule,
        schedule: value.schedule,
        preparation: value.preparation,
        preparationId: value.preparationId,
        fromSlot: value.fromSlot,
        beforeSlot: before,
        createdAt: value.createdAt,
        preparationNotBefore: value.preparationNotBefore,
      ),
    );
  }
  // Force malformed bounds through the strict carrier boundary before claims.
  for (final keys in exclusions.values) {
    for (final key in keys) {
      budget.visit();
      CivilDateTime.parse(key);
    }
  }
  return TimeCorrectionConflictWorld(
    List.unmodifiable(rows),
    List.unmodifiable(segments),
    Map.unmodifiable({
      for (final e in exclusions.entries)
        e.key: Set<String>.unmodifiable(e.value),
    }),
    List.unmodifiable(unresolved),
  );
}

final class _BoundedPreparations {
  _BoundedPreparations(this.db, this.budget);
  final AppDatabase db;
  final BackupBudget budget;
  final _cache = <String, PreparationEntity>{};

  Future<PreparationEntity> _load(
    String key,
    String sql,
    String owner, {
    bool linked = false,
  }) async {
    if (_cache[key] case final value?) return value;
    final rows = await db
        .customSelect(
          '$sql LIMIT ${BackupLimits.preparationSteps + 1}',
          variables: [Variable<String>(owner)],
        )
        .get();
    budget.visit(rows.length + 1);
    if (rows.length > BackupLimits.preparationSteps) {
      BackupLimits.exceeded('preparationSteps');
    }
    var minutes = 0;
    final steps = <PreparationStepEntity>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final amount = BackupLimits.minutes(row.read<int>('minutes'));
      minutes = BackupLimits.minutes(minutes + amount);
      steps.add(
        PreparationStepEntity(
          id: row.read<String>('id'),
          preparationName: row.read<String>('name'),
          preparationTime: Duration(minutes: amount),
          nextPreparationId: linked
              ? row.readNullable<String>('next_id')
              : i + 1 < rows.length
              ? rows[i + 1].read<String>('id')
              : null,
        ),
      );
    }
    return _cache[key] = PreparationEntity(
      preparationStepList: List.unmodifiable(steps),
    );
  }

  Future<PreparationEntity> definition(String id) => _load(
    'definition:$id',
    'SELECT id,name,minutes FROM preparation_definition_steps WHERE definition_id = ? ORDER BY position',
    id,
  );
  Future<PreparationEntity> schedule(ScheduleEntity value) async {
    // A frozen run owns its captured steps; a current template/default never
    // replaces them just because a mutable preparation source still exists.
    if (!value.preparationFrozen &&
        value.preparationMode == SchedulePreparationMode.template &&
        value.preparationTemplateId != null &&
        !value.preparationTemplateDeleted) {
      final id = value.preparationTemplateId!;
      final exists = await db
          .customSelect(
            'SELECT id FROM preparation_templates WHERE id = ? LIMIT 1',
            variables: [Variable<String>(id)],
          )
          .get();
      budget.visit();
      if (exists.isNotEmpty) {
        return _load(
          'template:$id',
          'SELECT id,preparation_name AS name,preparation_time AS minutes FROM preparation_template_steps WHERE template_id = ? ORDER BY position',
          id,
        );
      }
    }
    final own = value.preparationDefinitionId != null
        ? await definition(value.preparationDefinitionId!)
        : await _load(
            'schedule:${value.id}',
            'SELECT id,preparation_name AS name,preparation_time AS minutes,next_preparation_id AS next_id FROM preparation_schedules WHERE schedule_id = ?',
            value.id,
            linked: true,
          );
    if (value.preparationFrozen || own.preparationStepList.isNotEmpty) {
      return own;
    }
    return _load(
      'default',
      'SELECT id,preparation_name AS name,preparation_time AS minutes,next_preparation_id AS next_id FROM preparation_users WHERE user_id = ?',
      localProfileId,
      linked: true,
    );
  }
}
