import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_limits.dart';
import 'package:on_time_front/core/time/recurring_time_correction_mapping.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';

final start = DateTime.utc(2030, 1, 7, 10); // Monday.
ScheduleEntity row(
  String id,
  int ordinal, {
  String mask = '',
  String prep = 'shared',
  bool frozen = false,
  DateTime? civil,
  String zone = 'UTC',
}) => ScheduleEntity(
  id: id,
  place: const PlaceEntity(id: 'office', placeName: 'Office'),
  scheduleName: id,
  scheduleTime: civil ?? start.add(Duration(days: ordinal - 1)),
  timeZoneId: zone,
  occurrenceOffsetSeconds: 0,
  moveTime: Duration.zero,
  isChanged: true,
  isStarted: frozen,
  preparationFrozen: frozen,
  startedAt: frozen ? DateTime.utc(2029) : null,
  scheduleSpareTime: Duration.zero,
  scheduleNote: 'Keep $id',
  recurringSegmentId: 'segment',
  recurringSlotKey: (civil ?? start.add(Duration(days: ordinal - 1)))
      .toIso8601String(),
  recurringOrdinal: ordinal,
  recurringOverrides: mask,
  preparationDefinitionId: prep,
);
RecurringSegment segment({RecurrenceRule? rule}) => RecurringSegment(
  id: 'segment',
  seriesId: 'series',
  rule:
      rule ??
      RecurrenceRule(
        frequency: RecurrenceFrequency.daily,
        start: start,
        timeZoneId: 'UTC',
        count: 5,
      ),
  schedule: row('template', 1),
  preparation: const PreparationEntity(preparationStepList: []),
  preparationId: 'shared',
  fromSlot: rule?.start ?? start,
  createdAt: DateTime.utc(2029),
);
RecurrenceRule replacement({
  int? count = 2,
  DateTime? at,
  Set<int> days = const {2, 5},
}) => RecurrenceRule(
  frequency: RecurrenceFrequency.weekly,
  start: at ?? start,
  timeZoneId: 'UTC',
  weekdays: days,
  count: count,
);
Future<RecurringTimeCorrectionMapping> map({
  required List<ScheduleEntity> rows,
  List<TimeCorrectionExclusion> exclusions = const [],
  RecurrenceRule? rule,
  RecurringSegment? source,
  ScheduleEntity? anchor,
  bool explicit = true,
  BackupBudget? budget,
  Map<String, String> own = const {},
}) => RecurringTimeCorrectionMapper.build(
  anchor: anchor ?? rows.first,
  segments: [source ?? segment()],
  schedules: rows,
  exclusions: exclusions,
  occurrenceDefinitionOwners: own,
  requested: rule ?? replacement(),
  endExplicitlyChosen: explicit,
  nowUtc: DateTime.utc(2029),
  budget: budget ?? BackupBudget(),
);
void main() {
  test(
    'ordinary IDs map in stable order; unmatched override/tombstone survive separately',
    () async {
      final a = row('A', 1), b = row('B', 2), c = row('C', 3, mask: 'name');
      final exclusion = TimeCorrectionExclusion(
        'segment',
        start.add(const Duration(days: 3)).toIso8601String(),
        4,
      );
      final value = await map(
        rows: [c, b, a],
        anchor: a,
        exclusions: [exclusion],
      );
      final byId = {for (final entry in value.rows) entry.original.id: entry};
      expect(byId['A']!.slot!.civilTime, DateTime.utc(2030, 1, 8, 10));
      expect(byId['B']!.slot!.civilTime, DateTime.utc(2030, 1, 11, 10));
      expect(byId['C']!.detached, isTrue);
      expect(identical(byId['C']!.original, c), isTrue);
      expect(value.exclusions.single.slot, isNull);
      expect(identical(value.exclusions.single.original, exclusion), isTrue);
      expect(value.rule.count, 2);
    },
  );
  test(
    'protected days reserve slots before ordinary rows and excess rows detach',
    () async {
      final protected = row('run', 2, frozen: true),
          a = row('A', 1),
          c = row('C', 3);
      final value = await map(rows: [a, protected, c]);
      expect(value.protectedRows, [protected]);
      expect(
        value.protectedSlots.single.civilTime,
        DateTime.utc(2030, 1, 8, 10),
      );
      expect(value.rows.first.original.id, 'A');
      expect(value.rows.first.slot!.civilTime, DateTime.utc(2030, 1, 11, 10));
      expect(value.rows.last.original.id, 'C');
      expect(value.rows.last.detached, isTrue);
      expect(protected.recurringSegmentId, 'segment');
    },
  );
  test(
    'a matching tombstone consumes a new ordinal and keeps its original identity',
    () async {
      final a = row('A', 1), c = row('C', 3);
      final exclusion = TimeCorrectionExclusion(
        'segment',
        DateTime.utc(2030, 1, 8, 10).toIso8601String(),
        2,
      );
      final value = await map(rows: [a, c], exclusions: [exclusion]);
      expect(value.exclusions.single.slot!.ordinal, 1);
      expect(value.rows.first.slot!.ordinal, 2);
      expect(value.rows.last.detached, isTrue);
    },
  );
  test(
    'different series preparation detaches without cloning; occurrence-owned override maps',
    () async {
      final a = row('A', 1),
          b = row('B', 2, prep: 'different-shared'),
          c = row('C', 5, prep: 'own-C', mask: 'preparation');
      final value = await map(rows: [a, b, c], own: {'own-C': 'C'});
      final byId = {for (final entry in value.rows) entry.original.id: entry};
      expect(byId['B']!.detached, isTrue);
      expect(byId['B']!.original.preparationDefinitionId, 'different-shared');
      expect(byId['C']!.slot!.civilTime, DateTime.utc(2030, 1, 11, 10));
      expect(byId['C']!.original.preparationDefinitionId, 'own-C');
      expect(byId['A']!.slot!.civilTime, DateTime.utc(2030, 1, 8, 10));
    },
  );
  test('a finite remaining count includes the validated anchor', () async {
    final rows = [for (var i = 1; i <= 5; i++) row('$i', i)];
    final value = await map(
      rows: rows,
      anchor: rows[2],
      explicit: false,
      rule: replacement(count: 99, at: rows[2].scheduleTime, days: {3, 4, 5}),
    );
    expect(value.rule.count, 3);
    expect(value.automaticallyRetainedCount, isTrue);
    expect(value.rows.map((entry) => entry.original.id), ['3', '4', '5']);
  });
  test(
    'current gap counting cannot silently reuse a changed stored ordinal',
    () async {
      final oldRule = RecurrenceRule(
        frequency: RecurrenceFrequency.daily,
        start: DateTime.utc(2030, 3, 8, 2, 30),
        timeZoneId: 'America/New_York',
        count: 5,
      );
      final a = row(
        'anchor',
        4,
        civil: DateTime.utc(2030, 3, 11, 2, 30),
        zone: 'America/New_York',
      );
      await expectLater(
        map(
          rows: [a],
          source: segment(rule: oldRule),
          explicit: false,
          rule: replacement(at: a.scheduleTime),
        ),
        throwsA(isA<RecurringTimeCorrectionCountRequired>()),
      );
    },
  );
  test(
    'an unknown old zone requires explicit count but calendar constraints remain enforced',
    () async {
      final a = row('anchor', 1, zone: 'Unknown/A10');
      final source = segment(
        rule: RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          start: start,
          timeZoneId: 'Unknown/A10',
          count: 5,
        ),
      );
      await expectLater(
        map(rows: [a], source: source, explicit: false),
        throwsA(isA<RecurringTimeCorrectionCountRequired>()),
      );
      expect((await map(rows: [a], source: source)).rule.count, 2);
    },
  );
  test(
    'an unbounded new rule stops after the finite materialized mapping horizon',
    () async {
      final value = await map(
        rows: [row('A', 1), row('B', 2)],
        rule: replacement(count: null),
      );
      expect(value.rule.count, isNull);
      expect(value.rows.every((entry) => !entry.detached), isTrue);
      expect(value.workUnits, lessThan(100));
    },
  );
  for (final kind in [
    'duplicate slot',
    'reverse ordinal',
    'from',
    'count',
    'calendar',
  ]) {
    test('$kind remains a hard invariant', () async {
      final a = row('A', 1);
      final b = switch (kind) {
        'duplicate slot' => row('B', 2, civil: start),
        'reverse ordinal' => row(
          'B',
          1,
          civil: start.add(const Duration(days: 1)),
        ),
        'from' => row('B', 2, civil: start.subtract(const Duration(days: 1))),
        'count' => row('B', 6),
        _ => row('B', 2, civil: start.add(const Duration(hours: 1))),
      };
      await expectLater(
        map(rows: [a, b]),
        throwsA(
          isA<BackupProcessingFailure>().having(
            (e) => e.kind,
            'kind',
            BackupFailureKind.dataInvariant,
          ),
        ),
      );
    });
  }
  test('explicit count cannot bypass the shared work budget', () async {
    final budget = BackupBudget()..visit(BackupLimits.work - 1);
    await expectLater(
      map(rows: [row('A', 1), row('B', 2)], budget: budget),
      throwsA(
        isA<BackupProcessingFailure>().having(
          (e) => e.kind,
          'kind',
          BackupFailureKind.resourceLimit,
        ),
      ),
    );
  });
}
