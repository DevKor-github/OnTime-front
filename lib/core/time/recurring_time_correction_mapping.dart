import 'package:on_time_front/domain/entities/backup_recurring_time_review.dart';
import 'package:on_time_front/domain/recurrence/recurring_time_correction.dart';
export 'package:on_time_front/domain/recurrence/recurring_time_correction.dart';
import 'package:on_time_front/core/backup/backup_limits.dart';
import 'package:on_time_front/core/backup/backup_recurrence_scan.dart';
import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/recurrence/recurrence_engine.dart';
import 'package:on_time_front/domain/recurrence/recurrence_reference_policy.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
import 'schedule_time_resolution.dart';
import 'time_zone_rules.dart';

/// Bounded, read-only mapping shared by active review and authenticated staging.
/// It never chooses IDs, writes records, invokes a repository or grants commit
/// authority. The caller must revalidate its source/rule/clock claim at commit.
abstract final class RecurringTimeCorrectionMapper {
  static Future<RecurringTimeCorrectionMapping> build({
    required ScheduleEntity anchor,
    required List<RecurringSegment> segments,
    required List<ScheduleEntity> schedules,
    required List<TimeCorrectionExclusion> exclusions,
    required Map<String, String> occurrenceDefinitionOwners,
    required RecurrenceRule requested,
    required bool endExplicitlyChosen,
    required DateTime nowUtc,
    required BackupBudget budget,
  }) {
    if (anchor.recurringSegmentId == null ||
        anchor.recurringSlotKey == null ||
        anchor.recurringOrdinal == null) {
      BackupLimits.invalid();
    }
    return _build(
      segmentId: anchor.recurringSegmentId!,
      anchorCivil: CivilDateTime.parse(anchor.recurringSlotKey!).toUtcCarrier(),
      anchorOrdinal: anchor.recurringOrdinal,
      anchorId: anchor.id,
      segments: segments,
      schedules: schedules,
      exclusions: exclusions,
      occurrenceDefinitionOwners: occurrenceDefinitionOwners,
      requested: requested,
      endExplicitlyChosen: endExplicitlyChosen,
      nowUtc: nowUtc,
      budget: budget,
    );
  }

  static Future<RecurringTimeCorrectionMapping> buildCandidate({
    required BackupRecurringTimeAnchor anchor,
    required DateTime closeAt,
    required bool wholeSource,
    required List<RecurringSegment> segments,
    required List<ScheduleEntity> schedules,
    required List<TimeCorrectionExclusion> exclusions,
    required Map<String, String> occurrenceDefinitionOwners,
    required RecurrenceRule requested,
    required bool endExplicitlyChosen,
    required DateTime nowUtc,
    required BackupBudget budget,
  }) => _build(
    segmentId: anchor.segmentId,
    anchorCivil: closeAt,
    anchorOrdinal: anchor.originalOrdinal,
    anchorId: anchor.scheduleId,
    includeAllFuture: wholeSource,
    segments: segments,
    schedules: schedules,
    exclusions: exclusions,
    occurrenceDefinitionOwners: occurrenceDefinitionOwners,
    requested: requested,
    endExplicitlyChosen: endExplicitlyChosen,
    nowUtc: nowUtc,
    budget: budget,
  );

  static Future<RecurringTimeCorrectionMapping> _build({
    required String segmentId,
    required DateTime anchorCivil,
    required int? anchorOrdinal,
    required String? anchorId,
    bool includeAllFuture = false,
    required List<RecurringSegment> segments,
    required List<ScheduleEntity> schedules,
    required List<TimeCorrectionExclusion> exclusions,
    required Map<String, String> occurrenceDefinitionOwners,
    required RecurrenceRule requested,
    required bool endExplicitlyChosen,
    required DateTime nowUtc,
    required BackupBudget budget,
  }) async {
    final at = nowUtc.toUtc();
    final segmentById = {for (final segment in segments) segment.id: segment};
    final source = segmentById[segmentId];
    if (source == null ||
        segmentById.length != segments.length ||
        segments.any((value) => value.seriesId != source.seriesId)) {
      BackupLimits.invalid();
    }
    if (requested.start.isBefore(RecurrenceRule.civilDate(anchorCivil))) {
      throw const RecurrenceValidationException(
        'The new rule precedes its anchor.',
      );
    }
    final allRefs = <String, List<_Reference>>{
      for (final segment in segments) segment.id: [],
    };
    final scheduleIds = <String>{};
    final futureRows = <ScheduleEntity>[];
    final protectedRows = <ScheduleEntity>[];
    for (final row in schedules) {
      budget.visit();
      if (!scheduleIds.add(row.id) ||
          row.recurringSegmentId == null ||
          row.recurringSlotKey == null ||
          row.recurringOrdinal == null ||
          !segmentById.containsKey(row.recurringSegmentId)) {
        BackupLimits.invalid();
      }
      final slot = CivilDateTime.parse(row.recurringSlotKey!).toUtcCarrier();
      final resolved = ScheduleTimeResolver.resolve(row, nowUtc: at);
      final protected =
          RecurrenceReferencePolicy.hasProtectedFacts(row) ||
          row.startedAt != null ||
          row.finishedAt != null ||
          row.scoreContributionRecorded ||
          resolved.isHistorical ||
          RecurrenceReferencePolicy.isProvablyPast(row, at);
      allRefs[row.recurringSegmentId!]!.add(
        _Reference(slot, row.recurringOrdinal!, protected),
      );
      if (!slot.isBefore(anchorCivil) || (includeAllFuture && !protected)) {
        (protected ? protectedRows : futureRows).add(row);
      }
    }
    final futureExclusions = <TimeCorrectionExclusion>[];
    for (final exclusion in exclusions) {
      budget.visit();
      final refs = allRefs[exclusion.segmentId];
      if (refs == null) BackupLimits.invalid();
      final slot = CivilDateTime.parse(exclusion.slot).toUtcCarrier();
      refs.add(_Reference(slot, exclusion.ordinal, true));
      if (!slot.isBefore(anchorCivil)) futureExclusions.add(exclusion);
    }
    if (anchorId != null && !scheduleIds.contains(anchorId)) {
      BackupLimits.invalid();
    }
    if (anchorId == null &&
        (!endExplicitlyChosen ||
            (requested.count == null && requested.until == null))) {
      throw const RecurringTimeCorrectionCountRequired();
    }
    for (final segment in segments) {
      await _validateReferences(segment, allRefs[segment.id]!, budget);
    }

    var rule = requested;
    var autoCount = false;
    if (!endExplicitlyChosen && source.rule.count != null) {
      final open = segments
          .where(
            (value) =>
                value.beforeSlot == null ||
                value.beforeSlot!.isAfter(anchorCivil),
          )
          .toList();
      if (open.length != 1 ||
          open.single.id != source.id ||
          source.beforeSlot != null ||
          !TimeZoneRules.contains(source.rule.timeZoneId)) {
        throw const RecurringTimeCorrectionCountRequired();
      }
      BackupRuleCandidate? observed;
      await for (final candidate in scanBackupRule(
        rule: source.rule,
        through: anchorCivil,
        budget: budget,
        leadTime: source.leadTime,
        preparationNotBefore: source.preparationNotBefore,
      )) {
        if (candidate.civil == anchorCivil) observed = candidate;
      }
      final ordinal = anchorOrdinal;
      if (ordinal == null ||
          observed == null ||
          !observed.eligible ||
          observed.currentOrdinal != ordinal ||
          ordinal < 1 ||
          ordinal > source.rule.count!) {
        throw const RecurringTimeCorrectionCountRequired();
      }
      rule = requested.withStartAndEnd(count: source.rule.count! - ordinal + 1);
      autoCount = true;
    } else if (!endExplicitlyChosen &&
        segments.where((value) => value.beforeSlot == null).length != 1) {
      throw const RecurringTimeCorrectionCountRequired();
    }
    if (!TimeZoneRules.contains(rule.timeZoneId)) {
      throw const RecurrenceValidationException('Choose a known time zone.');
    }

    final compatible = <ScheduleEntity>[];
    final detached = <ScheduleEntity>[];
    for (final row in futureRows) {
      budget.visit();
      final definition = row.preparationDefinitionId;
      final own =
          definition != null &&
          occurrenceDefinitionOwners[definition] == row.id;
      if (definition == source.preparationId ||
          (own && row.recurringOverrides.split(',').contains('preparation'))) {
        compatible.add(row);
      } else {
        // A time correction cannot re-own or silently clone a preparation.
        detached.add(row);
      }
    }
    final overrides = compatible
        .where((row) => row.recurringOverrides.isNotEmpty)
        .toList();
    final ordinary =
        compatible.where((row) => row.recurringOverrides.isEmpty).toList()
          ..sort((a, b) {
            final slot = CivilDateTime.parse(
              a.recurringSlotKey!,
            ).compareTo(CivilDateTime.parse(b.recurringSlotKey!));
            if (slot != 0) return slot;
            final ordinal = a.recurringOrdinal!.compareTo(b.recurringOrdinal!);
            return ordinal != 0 ? ordinal : a.id.compareTo(b.id);
          });
    final reservations = <String, Object>{};
    void reserve(String slot, Object value) {
      final day = _day(CivilDateTime.parse(slot).toUtcCarrier());
      // Two different retained intents cannot silently collapse into one slot.
      if (reservations.containsKey(day)) {
        throw const RecurrenceValidationException(
          'Several preserved references share a new slot. Choose another anchor.',
        );
      }
      reservations[day] = value;
    }

    for (final row in [...protectedRows, ...overrides]) {
      reserve(row.recurringSlotKey!, row);
    }
    for (final exclusion in futureExclusions) {
      reserve(exclusion.slot, exclusion);
    }
    var throughNeeded = rule.start;
    for (final row in [...futureRows, ...protectedRows]) {
      final slot = CivilDateTime.parse(row.recurringSlotKey!).toUtcCarrier();
      if (slot.isAfter(throughNeeded)) throughNeeded = slot;
    }
    for (final exclusion in futureExclusions) {
      final slot = CivilDateTime.parse(exclusion.slot).toUtcCarrier();
      if (slot.isAfter(throughNeeded)) throughNeeded = slot;
    }
    final byDay = <String, RecurrenceSlot>{};
    final free = <RecurrenceSlot>[];
    RecurrenceSlot? firstSlot;
    await for (final candidate in scanBackupRule(
      rule: rule,
      through: DateTime.utc(9999, 12, 31, 23, 59, 59, 999, 999),
      budget: budget,
      leadTime: Duration.zero,
    )) {
      if (candidate.offsets.length > 1 && rule.repeatedTime == null) {
        throw RepeatedTimeChoiceRequired(candidate.civil);
      }
      if (candidate.eligible) {
        final offset = rule.repeatedTime == RepeatedCivilTime.second
            ? candidate.offsets.last
            : candidate.offsets.first;
        final slot = RecurrenceSlot(
          civilTime: candidate.civil,
          instantUtc: CivilDateTime.fromFields(
            candidate.civil,
          ).atOffset(offset),
          offsetSeconds: offset,
          ordinal: candidate.currentOrdinal,
        );
        final day = _day(candidate.civil);
        firstSlot ??= slot;
        if (reservations.containsKey(day)) {
          byDay[day] = slot;
        } else if (free.length < ordinary.length) {
          free.add(slot);
        }
      }
      if (rule.count != null && candidate.currentOrdinal >= rule.count!) break;
      if (firstSlot != null &&
          !candidate.civil.isBefore(throughNeeded) &&
          free.length >= ordinary.length) {
        break;
      }
    }
    final rows = <TimeCorrectionRowMapping>[];
    for (final row in overrides) {
      rows.add(
        TimeCorrectionRowMapping(
          row,
          byDay[_day(
            CivilDateTime.parse(row.recurringSlotKey!).toUtcCarrier(),
          )],
        ),
      );
    }
    for (var i = 0; i < ordinary.length; i++) {
      rows.add(
        TimeCorrectionRowMapping(ordinary[i], i < free.length ? free[i] : null),
      );
    }
    rows.addAll(detached.map((row) => TimeCorrectionRowMapping(row, null)));
    return RecurringTimeCorrectionMapping(
      rule: rule,
      automaticallyRetainedCount: autoCount,
      rows: rows,
      protectedRows: protectedRows,
      exclusions: [
        for (final exclusion in futureExclusions)
          TimeCorrectionExclusionMapping(
            exclusion,
            byDay[_day(CivilDateTime.parse(exclusion.slot).toUtcCarrier())],
          ),
      ],
      protectedSlots: [
        for (final row in protectedRows)
          ?byDay[_day(
            CivilDateTime.parse(row.recurringSlotKey!).toUtcCarrier(),
          )],
      ],
      workUnits: budget.work,
      firstSlot: firstSlot,
    );
  }

  static String _day(DateTime value) =>
      RecurrenceRule.civilDate(value).toIso8601String();

  static Future<void> _validateReferences(
    RecurringSegment segment,
    List<_Reference> references,
    BackupBudget budget,
  ) async {
    if (references.isEmpty) return;
    references.sort((a, b) => a.civil.compareTo(b.civil));
    var ordinal = 0;
    DateTime? previous;
    for (final reference in references) {
      budget.visit();
      if (reference.ordinal <= ordinal ||
          previous == reference.civil ||
          reference.civil.isBefore(segment.fromSlot) ||
          (segment.rule.count != null &&
              reference.ordinal > segment.rule.count!) ||
          (segment.beforeSlot != null &&
              !reference.civil.isBefore(segment.beforeSlot!) &&
              !reference.retained)) {
        BackupLimits.invalid();
      }
      previous = reference.civil;
      ordinal = reference.ordinal;
    }
    var index = 0;
    // Calendar membership is independent of unknown/changed zone rules. This
    // scan is not used to assign or prove historical occurrence instants.
    await for (final candidate in scanBackupRule(
      rule: segment.rule,
      through: references.last.civil,
      budget: budget,
      leadTime: Duration.zero,
      offsetLookup: (_, _, meter) {
        meter.visit();
        return const [0];
      },
    )) {
      if (index == references.length) break;
      final reference = references[index];
      if (candidate.civil.isAfter(reference.civil)) BackupLimits.invalid();
      if (candidate.civil == reference.civil) {
        if (reference.ordinal > candidate.calendarOrdinal) {
          BackupLimits.invalid();
        }
        index++;
      }
    }
    if (index != references.length) BackupLimits.invalid();
  }
}

final class _Reference {
  const _Reference(this.civil, this.ordinal, this.retained);
  final DateTime civil;
  final int ordinal;
  final bool retained;
}
