import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_limits.dart';
import 'package:on_time_front/core/time/time_correction_conflicts.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';

void main() {
  final now = DateTime.utc(2030, 1, 1);
  final start = DateTime.utc(2030, 1, 2, 10);
  ScheduleEntity row(
    String id,
    DateTime at, {
    String zone = 'UTC',
    int offset = 0,
  }) => ScheduleEntity(
    id: id,
    place: PlaceEntity(id: 'place-$id', placeName: 'Office'),
    scheduleName: id,
    scheduleTime: at,
    timeZoneId: zone,
    occurrenceOffsetSeconds: offset,
    moveTime: Duration.zero,
    scheduleSpareTime: Duration.zero,
    scheduleNote: '',
    isChanged: false,
    isStarted: false,
  );
  RecurrenceRule rule({int? count = 2, DateTime? at}) => RecurrenceRule(
    frequency: RecurrenceFrequency.daily,
    start: at ?? start,
    timeZoneId: 'UTC',
    count: count,
  );
  Future<TimeCorrectionConflictProof> scan({
    RecurrenceRule? targetRule,
    List<TimeCorrectionBusyInterval> stored = const [],
    List<RecurringSegment> segments = const [],
    Map<String, Set<String>> excludedOthers = const {},
    Set<String> excluded = const {},
    Duration preparation = const Duration(minutes: 10),
    BackupBudget? budget,
  }) => TimeCorrectionConflictScanner.scan(
    rule: targetRule ?? rule(),
    base: row('base', start),
    basePreparation: preparation,
    proposedOverrides: {},
    proposedPreparationById: {},
    excludedSlots: excluded,
    storedOthers: stored,
    otherSegments: segments,
    otherExcludedSlots: excludedOthers,
    nowUtc: now,
    budget: budget ?? BackupBudget(),
  );

  test(
    'inclusive end date checks its final evening and ambiguity remains a possible impact',
    () async {
      final last = DateTime.utc(2030, 1, 3, 23, 59, 59, 999, 999);
      final untilRule = RecurrenceRule(
        frequency: RecurrenceFrequency.daily,
        start: DateTime.utc(2030, 1, 2, 23, 59, 59, 999, 999),
        timeZoneId: 'UTC',
        until: DateTime.utc(2030, 1, 3),
      );
      final proof = await scan(
        targetRule: untilRule,
        stored: [TimeCorrectionBusyInterval(row('last', last), last, last)],
      );
      expect(proof.conflicts.single.slot.instantUtc, last);
      final overlap = DateTime.utc(2030, 11, 3, 1, 30);
      final segment = RecurringSegment(
        id: 'ambiguous',
        seriesId: 'series',
        rule: RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          start: overlap,
          timeZoneId: 'America/New_York',
          count: 1,
        ),
        schedule: row('ambiguous', overlap),
        preparation: const PreparationEntity(preparationStepList: []),
        preparationId: 'definition',
        fromSlot: overlap,
        createdAt: now,
      );
      final selected = rule(count: 1, at: DateTime.utc(2030, 11, 3, 6));
      final uncertain = await scan(targetRule: selected, segments: [segment]);
      expect(uncertain.conflicts, isEmpty);
      expect(uncertain.possibleOverlaps, hasLength(1));
      expect(uncertain.possibleOverlaps.single.originalCivil, overlap);
      expect(uncertain.possibleOverlaps.single.timeZoneId, 'America/New_York');
      expect(
        (await scan(
          targetRule: selected,
          segments: [segment],
          excludedOthers: {
            'ambiguous': {overlap.toIso8601String()},
          },
        )).possibleOverlaps,
        isEmpty,
      );
      expect(
        (await scan(
          targetRule: rule(count: 1, at: DateTime.utc(2030, 11, 3, 9)),
          segments: [segment],
        )).possibleOverlaps,
        isEmpty,
      );
    },
  );

  test(
    'equal target instants conflict even with zero preparations and foreign civil dates',
    () async {
      final ny = row(
        'new-york',
        DateTime.utc(2030, 1, 2, 5),
        zone: 'America/New_York',
        offset: -18000,
      );
      final proof = await scan(
        preparation: Duration.zero,
        stored: [TimeCorrectionBusyInterval(ny, start, start)],
      );
      expect(proof.conflicts, hasLength(1));
      expect(proof.conflicts.single.slot.instantUtc, start);
      expect(proof.conflicts.single.other.schedule.id, 'new-york');
    },
  );
  test(
    'touching preparation endpoints do not overlap while one microsecond inside does',
    () async {
      final target = start.subtract(const Duration(minutes: 10));
      final exact = TimeCorrectionBusyInterval(
        row('touch', target),
        target,
        target,
      );
      expect((await scan(stored: [exact])).conflicts, isEmpty);
      final inside = target.add(const Duration(microseconds: 1));
      expect(
        (await scan(
          stored: [
            TimeCorrectionBusyInterval(row('inside', inside), inside, inside),
          ],
        )).conflicts,
        hasLength(1),
      );
    },
  );
  test(
    'other unmaterialized recurrence is expanded read-only and respects its tombstone',
    () async {
      final segment = RecurringSegment(
        id: 'other',
        seriesId: 'series',
        rule: rule(),
        schedule: row('otherbase', start),
        preparation: const PreparationEntity(preparationStepList: []),
        preparationId: 'definition',
        fromSlot: start,
        createdAt: now,
      );
      final proof = await scan(
        segments: [segment],
        excludedOthers: {
          'other': {start.toIso8601String()},
        },
      );
      expect(proof.conflicts, hasLength(1));
      expect(proof.conflicts.single.slot.ordinal, 2);
      expect(proof.conflicts.single.other.schedule.recurringSegmentId, 'other');
    },
  );
  test(
    'an excluded proposed slot still consumes count and never creates a replacement fourth occurrence',
    () async {
      final other = start.add(const Duration(days: 2));
      final proof = await scan(
        excluded: {start.toIso8601String()},
        stored: [TimeCorrectionBusyInterval(row('third', other), other, other)],
      );
      expect(proof.conflicts, isEmpty);
    },
  );
  test(
    'unbounded self overlap is marked persistent rather than hidden by finite preview',
    () async {
      final proof = await scan(
        targetRule: rule(count: null),
        preparation: const Duration(hours: 25),
      );
      expect(proof.conflicts, isNotEmpty);
      expect(proof.conflicts.any((e) => e.persistent), isTrue);
      expect(proof.through.isAfter(start.add(const Duration(days: 7))), isTrue);
    },
  );
  test(
    'exhausted shared work budget cannot return a partial conflict-free result',
    () async {
      final budget = BackupBudget()..visit(BackupLimits.work);
      await expectLater(
        scan(budget: budget),
        throwsA(isA<BackupProcessingFailure>()),
      );
    },
  );
  test(
    'materialized override occupies its slot instead of also generating its old base target',
    () async {
      final segment = RecurringSegment(
        id: 'other',
        seriesId: 'series',
        rule: rule(count: 1),
        schedule: row('otherbase', start),
        preparation: const PreparationEntity(preparationStepList: []),
        preparationId: 'definition',
        fromSlot: start,
        createdAt: now,
      );
      final target = start.add(const Duration(hours: 4));
      final moved = row('stable-id', target).copyWith(
        recurringSegmentId: 'other',
        recurringSlotKey: start.toIso8601String(),
        recurringOrdinal: 1,
        recurringOverrides: 'time',
      );
      final proof = await scan(
        segments: [segment],
        stored: [TimeCorrectionBusyInterval(moved, target, target)],
      );
      expect(proof.conflicts, isEmpty);
    },
  );
}
