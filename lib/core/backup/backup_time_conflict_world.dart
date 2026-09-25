part of 'backup_validated_ingestion.dart';

/// Candidate-only read adapter. It never opens AppDatabase or calls an active
/// repository, and every scan spends the ingestion owner's original budget.
class _BackupConflictWorld {
  _BackupConflictWorld(
    this.rows,
    this.segments,
    this.exclusions,
    this.possible,
  );
  final List<TimeCorrectionBusyInterval> rows;
  final List<RecurringSegment> segments;
  final Map<String, Set<String>> exclusions;
  final List<TimeCorrectionPossibleOverlap> possible;

  static Future<_BackupConflictWorld> read(
    BackupValidatedIngestion data,
    DateTime now,
    Set<String> ignoredIds, {
    Map<String, DateTime> closingSegments = const {},
  }) async {
    final store = data.store;
    final rows = <TimeCorrectionBusyInterval>[];
    final segments = <RecurringSegment>[];
    final exclusions = <String, Set<String>>{};
    final possible = <TimeCorrectionPossibleOverlap>[];
    for (final row in store.records('exclusion')) {
      (exclusions[row['reference'] as String] ??= {}).add(
        row['slot'] as String,
      );
    }
    for (final record in store.records('schedule')) {
      final value = data._schedule(record['node'] as int);
      if (value.recurringSegmentId != null && value.recurringSlotKey != null) {
        (exclusions[value.recurringSegmentId!] ??= {}).add(
          value.recurringSlotKey!,
        );
      }
      if (ignoredIds.contains(value.id) ||
          value.doneStatus != ScheduleDoneStatus.notEnded) {
        continue;
      }
      if (value.recurringSegmentId != null) {
        final segment = store.record('segment', value.recurringSegmentId!)!;
        final raw = data._segment(segment['node'] as int);
        if (RecurrenceReferencePolicy.isClosedTail(
          value.recurringSlotKey!,
          raw.beforeSlot,
        )) {
          continue;
        }
      }
      final resolution = ScheduleTimeResolver.resolve(value, nowUtc: now);
      final target = resolution.instantUtc;
      if (target == null) {
        if (resolution.isHistorical) continue;
        final lead = data._leadFor(value);
        final civil = CivilDateTime.fromFields(
          value.scheduleTime,
        ).toUtcCarrier();
        final earliest = civil.subtract(const Duration(days: 1) + lead);
        final latest = civil.add(const Duration(days: 1));
        if (latest.isBefore(now)) continue;
        possible.add(
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
      } else {
        rows.add(
          TimeCorrectionBusyInterval(
            value,
            target.subtract(data._leadFor(value)),
            target,
          ),
        );
      }
    }
    for (final record in store.records('segment')) {
      final raw = data._segment(record['node'] as int);
      final spec = await data._spec(raw);
      final from = CivilDateTime.parse(raw.fromSlot).toUtcCarrier();
      var before = raw.beforeSlot == null
          ? null
          : CivilDateTime.parse(raw.beforeSlot!).toUtcCarrier();
      final closing = closingSegments[raw.id];
      if (closing != null && (before == null || closing.isBefore(before))) {
        before = closing;
      }
      if (before != null && !before.isAfter(from)) continue;
      final preparation = data._definitionPreparation(raw.preparationId);
      final value = RecurringSegment(
        id: raw.id,
        seriesId: raw.seriesId,
        rule: spec.rule,
        schedule: spec.schedule,
        preparation: preparation,
        preparationId: raw.preparationId,
        fromSlot: from,
        beforeSlot: before,
        createdAt: raw.createdAt,
        preparationNotBefore: raw.preparationNotBefore,
      );
      if (!TimeZoneRules.contains(spec.rule.timeZoneId)) {
        if (RecurrenceReferencePolicy.hasNoFutureGeneration(
          rule: spec.rule,
          fromSlot: from,
          beforeSlot: before,
          nowUtc: now,
        )) {
          continue;
        }
        final end = before ?? spec.rule.until;
        possible.add(
          TimeCorrectionPossibleOverlap(
            id: 'segment:${raw.id}',
            name: spec.schedule.scheduleName,
            reason: 'unknownZone',
            originalCivil: spec.rule.start,
            timeZoneId: spec.rule.timeZoneId,
            rule: spec.rule,
            earliestPreparationUtc: spec.rule.start.subtract(
              const Duration(days: 1) + value.leadTime,
            ),
            latestTargetUtc: end?.add(const Duration(days: 2)),
          ),
        );
      } else {
        segments.add(value);
      }
    }
    return _BackupConflictWorld(rows, segments, exclusions, possible);
  }
}
