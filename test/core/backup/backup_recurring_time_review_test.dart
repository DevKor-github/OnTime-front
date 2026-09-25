import 'package:on_time_front/domain/recurrence/recurrence_engine.dart';
// Authenticated candidate + fresh whole-graph validation + real SQLite readback.
// This fixture is plaintext in-memory; SQLCipher/native proof is separate.
import 'dart:convert';
import 'dart:typed_data';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_crypto.dart';
import 'package:on_time_front/core/backup/backup_ingestion_store.dart';
import 'package:on_time_front/core/backup/backup_limits.dart';
import 'package:on_time_front/core/backup/backup_validated_ingestion.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/domain/entities/backup_operation.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';
import 'package:on_time_front/domain/entities/backup_recurring_time_review.dart';
import 'package:on_time_front/domain/entities/backup_restore_selection.dart';
import 'package:on_time_front/domain/entities/backup_time_review.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'package:on_time_front/domain/recurrence/recurring_time_correction.dart';
import '../../helpers/sodium_test_loader.dart';
import 'backup_validated_ingestion_test.dart' show recurringBackup;

class _Ready extends BackupRestoreInput {
  _Ready(this.data, this.db, this.lease);
  final BackupValidatedIngestion data;
  final AppDatabase db;
  final BackupProcessingLease lease;
  bool closed = false;
  @override
  BackupRestorePreview get preview => data.preview;
  @override
  Future<void> dispose() async {
    if (closed) return;
    await db.close();
    await data.release();
    lease.release();
    closed = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DateTime now;
  late BackupProcessingOwner processing;
  late BackupIngestionStore store;
  final owned = <BackupRestoreSelection>[];
  var readyCalls = 0;
  final crypto = BackupCrypto(sodiumLoader: loadSodiumForTest);
  setUp(() {
    now = DateTime.utc(2030);
    processing = BackupProcessingOwner();
    owned.clear();
    readyCalls = 0;
  });
  tearDown(() async {
    for (final input in owned.reversed) {
      await input.dispose();
    }
  });
  Map<String, dynamic> input({bool empty = false}) {
    final value = recurringBackup(year: 2031);
    final segment = value['recurring']['segments'][0];
    final rule =
        jsonDecode(segment['ruleJson'] as String) as Map<String, dynamic>;
    rule['zone'] = 'Removed/Zone';
    rule['count'] = 5;
    segment['ruleJson'] = jsonEncode(rule);
    final base =
        jsonDecode(segment['scheduleJson'] as String) as Map<String, dynamic>;
    base['zone'] = 'Removed/Zone';
    segment['scheduleJson'] = jsonEncode(base);
    value['schedules'][0]['timeZoneId'] = 'Removed/Zone';
    if (empty) value['schedules'] = [];
    return value;
  }

  Future<BackupTimeReviewInput> open(Map<String, dynamic> value) async {
    final bytes = await crypto.encrypt(
      plaintext: Uint8List.fromList(utf8.encode(jsonEncode(value))),
      password: 'recurrence review password',
    );
    final lease = processing.acquire();
    final selected = await BackupAuthenticatedTimeReview.decrypt(
      ciphertext: Stream.value(bytes),
      password: 'recurrence review password',
      crypto: crypto,
      budget: BackupBudget(lease: lease),
      createStore: (budget) async =>
          store = BackupIngestionStore.memoryForTesting(budget),
      now: () => now,
      ready: (data) async {
        readyCalls++;
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        try {
          await data.materialize(db, pendingCleanup: false);
          await data.validateReadBack(db, pendingCleanup: false);
        } catch (_) {
          await db.close();
          rethrow;
        }
        return _Ready(data, db, lease);
      },
    );
    owned.add(selected);
    return selected as BackupTimeReviewInput;
  }

  Future<BackupRecurringTimeDraft> draft(
    BackupTimeReviewInput owner, {
    bool whole = false,
    bool explicitEnd = true,
    int? count = 3,
    DateTime? start,
    String zone = 'UTC',
    RepeatedCivilTime? repeatedTime,
  }) async {
    final issue = (await owner.issues()).items.firstWhere(
      (i) => i.kind == BackupTimeFieldKind.recurrenceRule,
    );
    final summary = owner.summary;
    return BackupRecurringTimeDraft(
      identity: summary.identity,
      revision: summary.revision,
      rulesIdentity: summary.rulesIdentity,
      issueId: issue.id,
      rule: RecurrenceRule(
        frequency: RecurrenceFrequency.daily,
        start: start ?? DateTime.utc(2031, 1, 3, 9),
        timeZoneId: zone,
        repeatedTime: repeatedTime,
        count: count,
      ),
      endExplicitlyChosen: explicitEnd,
      replaceWholeSourceInterval: whole,
    );
  }

  BackupRecurringTimeReviewPort port(BackupTimeReviewInput owner) =>
      owner as BackupRecurringTimeReviewPort;
  BackupRecurringTimeChoice choice(
    BackupRecurringTimePlan plan, {
    bool? whole,
    Set<String>? detached,
    Set<String>? unmatched,
  }) => BackupRecurringTimeChoice(
    plan: plan,
    confirmedWholeSourceReplacement: whole ?? plan.replacesWholeSourceInterval,
    confirmedDetachedIds:
        detached ??
        {
          for (final r in plan.mapping.rows)
            if (r.detached) r.original.id,
        },
    confirmedUnmatchedExclusions:
        unmatched ??
        {
          for (final e in plan.mapping.exclusions)
            if (e.slot == null) '${e.original.segmentId}\n${e.original.slot}',
        },
    acknowledgedPossibleIds: plan.conflicts.possibleOverlaps
        .map((e) => e.id)
        .toSet(),
  );
  test(
    'zero materialized rows have no fabricated anchor and require explicit bounded end',
    () async {
      final owner = await open(input(empty: true));
      final api = port(owner);
      expect(
        (await api.recurrenceRule((await draft(owner)).issueId)).timeZoneId,
        'Removed/Zone',
      );
      await expectLater(
        api.reviewRecurrence(
          await draft(owner, explicitEnd: false, count: null),
        ),
        throwsA(isA<RecurringTimeCorrectionCountRequired>()),
      );
      final plan = await api.reviewRecurrence(await draft(owner));
      expect(plan.anchor.scheduleId, isNull);
      expect(plan.anchor.originalOrdinal, isNull);
      expect(plan.mapping.rows, isEmpty);
      expect(plan.closeAt, DateTime.utc(2031, 1, 1, 9));
      expect(readyCalls, 0);
      await api.chooseRecurrence(choice(plan));
      final ready = await owner.revalidate() as _Ready;
      owned.add(ready);
      expect(await ready.db.select(ready.db.schedules).get(), isEmpty);
      final segments = await ready.db
          .select(ready.db.recurringScheduleSegments)
          .get();
      expect(segments, hasLength(2));
      expect(
        segments.singleWhere((s) => s.id == 'seg').beforeSlot,
        '2031-01-01T09:00:00.000',
      );
      expect(segments.singleWhere((s) => s.id != 'seg').seriesId, 'series');
      expect(readyCalls, 1);
    },
  );
  test(
    'future unknown prefix requires separate whole-source acknowledgement and preserves stable row',
    () async {
      final original = input();
      final owner = await open(original);
      final api = port(owner);
      await expectLater(
        api.reviewRecurrence(await draft(owner)),
        throwsA(isA<BackupRecurringWholeReplacementRequired>()),
      );
      final plan = await api.reviewRecurrence(await draft(owner, whole: true));
      expect(plan.anchor.scheduleId, 's1');
      expect(plan.anchor.originalOrdinal, 3);
      expect(plan.anchor.originalSlot, DateTime.utc(2031, 1, 3, 9));
      expect(plan.closeAt, DateTime.utc(2031, 1, 1, 9));
      final revision = owner.summary.revision;
      await expectLater(
        api.chooseRecurrence(choice(plan, whole: false)),
        throwsA(isA<BackupTimeReviewStale>()),
      );
      expect(owner.summary.revision, revision);
      await api.chooseRecurrence(choice(plan));
      final ready = await owner.revalidate() as _Ready;
      owned.add(ready);
      final row = await ready.db.select(ready.db.schedules).getSingle();
      expect(row.id, 's1');
      expect(row.preparationDefinitionId, 'def');
      expect(row.recurringSegmentId, isNot('seg'));
      expect(row.recurringOrdinal, 1);
      expect(row.timeZoneId, 'UTC');
      final old =
          (await ready.db.select(ready.db.recurringScheduleSegments).get())
              .singleWhere((r) => r.id == 'seg');
      expect(old.ruleJson, original['recurring']['segments'][0]['ruleJson']);
      expect(old.beforeSlot, '2031-01-01T09:00:00.000');
      final oldNode = store.record('segment', 'seg')!['node'] as int;
      expect(store.originalTimeScalar(oldNode, 'beforeSlot'), isNull);
    },
  );
  test(
    'one plan cannot be replayed after candidate revision changes',
    () async {
      final owner = await open(input(empty: true));
      final api = port(owner);
      final plan = await api.reviewRecurrence(await draft(owner));
      await api.chooseRecurrence(choice(plan));
      await expectLater(
        api.chooseRecurrence(choice(plan)),
        throwsA(isA<BackupTimeReviewStale>()),
      );
      expect(readyCalls, 0);
    },
  );
  test(
    'known collision blocks candidate edit and cannot be labelled safe',
    () async {
      final value = input(empty: true);
      final other =
          recurringBackup(year: 2031)['schedules'][0] as Map<String, dynamic>;
      other.removeWhere(
        (key, _) =>
            key.startsWith('recurring') || key == 'preparationDefinitionId',
      );
      other['id'] = 'other';
      other['civilTime'] = '2031-01-03T09:00:00.000';
      value['schedules'] = [other];
      final owner = await open(value);
      final api = port(owner);
      final plan = await api.reviewRecurrence(await draft(owner));
      expect(plan.conflicts.conflicts, isNotEmpty);
      final revision = owner.summary.revision;
      await expectLater(
        api.chooseRecurrence(choice(plan)),
        throwsA(isA<BackupTimeChoiceConflict>()),
      );
      expect(owner.summary.revision, revision);
      expect(readyCalls, 0);
    },
  );
  test(
    'mapped materialized explicit spare contributes to its conflict interval',
    () async {
      final value = input();
      value['profile']['spareTimeMinutes'] = 60;
      value['schedules'][0]['spareTimeMinutes'] = 60;
      final raw = value['recurring']['segments'][0];
      final base =
          jsonDecode(raw['scheduleJson'] as String) as Map<String, dynamic>;
      base['spare'] = 60;
      raw['scheduleJson'] = jsonEncode(base);
      final other =
          recurringBackup(year: 2031)['schedules'][0] as Map<String, dynamic>;
      other.removeWhere(
        (key, _) =>
            key.startsWith('recurring') || key == 'preparationDefinitionId',
      );
      other['id'] = 'other';
      other['civilTime'] = '2031-01-03T08:30:00.000';
      other['spareTimeMinutes'] = 0;
      value['schedules'].add(other);
      final owner = await open(value);
      final api = port(owner);
      final plan = await api.reviewRecurrence(await draft(owner, whole: true));
      expect(
        plan.conflicts.conflicts.map((e) => e.other.schedule.id),
        contains('other'),
      );
      expect(
        plan.mapping.rows.single.original.scheduleSpareTime,
        const Duration(minutes: 60),
      );
      await expectLater(
        api.chooseRecurrence(choice(plan)),
        throwsA(isA<BackupTimeChoiceConflict>()),
      );
      expect(owner.summary.revision, plan.draft.revision);
      expect(readyCalls, 0);
    },
  );
  test(
    'protected start and matched tombstone keep originals while exclusions transfer to the new rule',
    () async {
      final value = input();
      final protected =
          jsonDecode(jsonEncode(value['schedules'][0])) as Map<String, dynamic>;
      protected.addAll({
        'id': 'protected',
        'civilTime': '2031-01-04T09:00:00.000',
        'recurringSlotKey': '2031-01-04T09:00:00.000',
        'recurringOrdinal': 4,
        'startedAt': '2029-12-31T09:00:00.000Z',
        'preparationFrozen': true,
      });
      value['schedules'].add(protected);
      value['recurring']['exclusions'] = [
        {
          'segmentId': 'seg',
          'slotKey': '2031-01-02T09:00:00.000',
          'ordinal': 2,
        },
      ];
      final owner = await open(value);
      final api = port(owner);
      final plan = await api.reviewRecurrence(
        await draft(owner, whole: true, start: DateTime.utc(2031, 1, 2, 9)),
      );
      expect(plan.mapping.protectedRows.map((r) => r.id), ['protected']);
      expect(plan.mapping.exclusions.single.slot!.ordinal, 1);
      await api.chooseRecurrence(choice(plan));
      final ready = await owner.revalidate() as _Ready;
      owned.add(ready);
      final rows = await ready.db.select(ready.db.schedules).get();
      final retained = rows.singleWhere((r) => r.id == 'protected');
      expect(retained.recurringSegmentId, 'seg');
      expect(retained.recurringOrdinal, 4);
      expect(retained.timeZoneId, 'Removed/Zone');
      expect(retained.occurrenceOffsetSeconds, 0);
      expect(retained.preparationFrozen, isTrue);
      expect(retained.startedAt!.toUtc(), DateTime.utc(2029, 12, 31, 9));
      final tombstones = await ready.db
          .select(ready.db.recurringScheduleExclusions)
          .get();
      expect(tombstones, hasLength(3));
      expect(tombstones.singleWhere((e) => e.segmentId == 'seg').ordinal, 2);
      expect(
        tombstones
            .where((e) => e.segmentId != 'seg')
            .map((e) => e.ordinal)
            .toSet(),
        {1, 3},
      );
    },
  );
  test(
    'unmatched original exclusion needs exact acknowledgement before any edit',
    () async {
      final value = input();
      value['recurring']['exclusions'] = [
        {
          'segmentId': 'seg',
          'slotKey': '2031-01-02T09:00:00.000',
          'ordinal': 2,
        },
      ];
      final owner = await open(value);
      final api = port(owner);
      final plan = await api.reviewRecurrence(await draft(owner, whole: true));
      expect(plan.mapping.exclusions.single.slot, isNull);
      final revision = owner.summary.revision;
      await expectLater(
        api.chooseRecurrence(choice(plan, unmatched: {})),
        throwsA(isA<BackupTimeReviewStale>()),
      );
      expect(owner.summary.revision, revision);
      await api.chooseRecurrence(choice(plan));
      final ready = await owner.revalidate() as _Ready;
      owned.add(ready);
      final original = await ready.db
          .select(ready.db.recurringScheduleExclusions)
          .getSingle();
      expect(original.segmentId, 'seg');
      expect(original.ordinal, 2);
    },
  );
  test(
    'an old slot with future time override is not omitted from whole source mapping',
    () async {
      final value = input();
      final raw = value['recurring']['segments'][0];
      final rule =
          jsonDecode(raw['ruleJson'] as String) as Map<String, dynamic>;
      rule['start'] = '2029-01-01T09:00:00.000';
      raw['ruleJson'] = jsonEncode(rule);
      raw['fromSlot'] = rule['start'];
      final base =
          jsonDecode(raw['scheduleJson'] as String) as Map<String, dynamic>;
      base['time'] = rule['start'];
      raw['scheduleJson'] = jsonEncode(base);
      value['schedules'][0].addAll({
        'recurringSlotKey': '2029-01-03T09:00:00.000',
        'civilTime': '2031-01-03T13:00:00.000',
        'timeZoneId': 'UTC',
        'recurringOverrides': 'time',
      });
      final owner = await open(value);
      final api = port(owner);
      final plan = await api.reviewRecurrence(await draft(owner, whole: true));
      expect(plan.mapping.rows.single.original.id, 's1');
      expect(plan.mapping.rows.single.detached, isTrue);
      expect(plan.unresolvedOverrides, isEmpty);
      await expectLater(
        api.chooseRecurrence(choice(plan, detached: {})),
        throwsA(isA<BackupTimeReviewStale>()),
      );
      await api.chooseRecurrence(choice(plan));
      final ready = await owner.revalidate() as _Ready;
      owned.add(ready);
      final row = await ready.db.select(ready.db.schedules).getSingle();
      expect(row.id, 's1');
      expect(row.recurringSegmentId, isNull);
      expect(row.preparationDefinitionId, 'def');
      expect(row.timeZoneId, 'UTC');
      expect(row.scheduleTime, DateTime.utc(2031, 1, 3, 13));
    },
  );
  test(
    'passing the first preparation boundary retires a reviewed plan without writes',
    () async {
      final owner = await open(input(empty: true));
      final api = port(owner);
      final plan = await api.reviewRecurrence(await draft(owner));
      final revision = owner.summary.revision;
      now = DateTime.utc(2032);
      await expectLater(
        api.chooseRecurrence(choice(plan)),
        throwsA(isA<BackupTimeReviewStale>()),
      );
      expect(owner.summary.revision, revision);
      expect(readyCalls, 0);
    },
  );
  test(
    'zero-row DST gap start skips the gap and survives full SQLite readback',
    () async {
      final owner = await open(input(empty: true));
      final api = port(owner);
      final plan = await api.reviewRecurrence(
        await draft(
          owner,
          start: DateTime.utc(2031, 3, 9, 2, 30),
          zone: 'America/New_York',
          count: 2,
        ),
      );
      expect(
        plan.mapping.firstSlot!.civilTime,
        DateTime.utc(2031, 3, 10, 2, 30),
      );
      expect(plan.mapping.firstSlot!.ordinal, 1);
      expect(plan.mapping.firstSlot!.offsetSeconds, -14400);
      expect(
        plan.mapping.firstSlot!.instantUtc,
        DateTime.utc(2031, 3, 10, 6, 30),
      );
      await api.chooseRecurrence(choice(plan));
      final ready = await owner.revalidate() as _Ready;
      owned.add(ready);
      final segment =
          (await ready.db.select(ready.db.recurringScheduleSegments).get())
              .singleWhere((e) => e.id != 'seg');
      final rule = jsonDecode(segment.ruleJson) as Map<String, dynamic>;
      final base = jsonDecode(segment.scheduleJson) as Map<String, dynamic>;
      expect(rule['start'], '2031-03-09T02:30:00.000');
      expect(rule['count'], 2);
      expect(base['zone'], 'America/New_York');
      expect(base['offset'], -14400);
      expect(await ready.db.select(ready.db.schedules).get(), isEmpty);
    },
  );
  test(
    'overlap requires an explicit side and second occurrence survives full validation',
    () async {
      final owner = await open(input(empty: true));
      final api = port(owner);
      await expectLater(
        api.reviewRecurrence(
          await draft(
            owner,
            start: DateTime.utc(2031, 11, 2, 1, 30),
            zone: 'America/New_York',
            count: 2,
          ),
        ),
        throwsA(isA<RepeatedTimeChoiceRequired>()),
      );
      final plan = await api.reviewRecurrence(
        await draft(
          owner,
          start: DateTime.utc(2031, 11, 2, 1, 30),
          zone: 'America/New_York',
          count: 2,
          repeatedTime: RepeatedCivilTime.second,
        ),
      );
      expect(
        plan.mapping.firstSlot!.instantUtc,
        DateTime.utc(2031, 11, 2, 6, 30),
      );
      expect(plan.mapping.firstSlot!.offsetSeconds, -18000);
      await api.chooseRecurrence(choice(plan));
      final ready = await owner.revalidate() as _Ready;
      owned.add(ready);
      final segment =
          (await ready.db.select(ready.db.recurringScheduleSegments).get())
              .singleWhere((e) => e.id != 'seg');
      expect(jsonDecode(segment.ruleJson)['repeatedTime'], 'second');
      expect(jsonDecode(segment.scheduleJson)['offset'], -18000);
    },
  );
  test(
    'rule review and cancellation do not edit the candidate graph',
    () async {
      final value = input();
      final owner = await open(value);
      final api = port(owner);
      final segmentNode = store.record('segment', 'seg')!['node'] as int;
      final rowNode = store.record('schedule', 's1')!['node'] as int;
      Object snapshot() => [
        store.fields(segmentNode, {
          'id',
          'fromSlot',
          'beforeSlot',
          'ruleJson',
          'scheduleJson',
          'preparationId',
        }),
        store.fields(rowNode, {
          'id',
          'civilTime',
          'timeZoneId',
          'occurrenceOffsetSeconds',
          'recurringSegmentId',
          'recurringSlotKey',
          'recurringOrdinal',
          'recurringOverrides',
          'preparationDefinitionId',
        }),
      ];
      final before = snapshot();
      await api.reviewRecurrence(await draft(owner, whole: true));
      expect(snapshot(), before);
      expect(readyCalls, 0);
    },
  );
}
