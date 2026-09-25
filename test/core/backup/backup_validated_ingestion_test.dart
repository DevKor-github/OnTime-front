import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_ingestion_store.dart';
import 'package:on_time_front/core/backup/backup_json_reader.dart';
import 'package:on_time_front/core/backup/backup_limits.dart';
import 'package:on_time_front/core/backup/backup_validated_ingestion.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';
import 'package:on_time_front/core/backup/backup_recurrence_scan.dart';
import 'backup_validation_contract_test.dart' show validBackup;

Future<BackupValidatedIngestion> validate(
  Map<String, dynamic> value, {
  BackupBudget? budget,
  DateTime? now,
  BackupOffsetLookup offsetLookup = backupOffsets,
}) async {
  final store = BackupIngestionStore.memoryForTesting(budget ?? BackupBudget());
  addTearDown(store.release);
  final bytes = utf8.encode(jsonEncode(value));
  final root = await BackupJsonReader(
    store,
    store.budget,
  ).read(Stream.value(bytes));
  return BackupValidatedIngestion.validateTestStore(
    store,
    root,
    nowUtc: now ?? DateTime.utc(2026, 9, 24),
    offsetLookup: offsetLookup,
  );
}

Map<String, dynamic> recurringBackup({int year = 2025, int ordinal = 3}) {
  final input = jsonDecode(jsonEncode(validBackup())) as Map<String, dynamic>;
  input['formatVersion'] = 2;
  final time = DateTime.utc(year, 1, 3, 9).toIso8601String();
  final start = DateTime.utc(year, 1, 1, 9).toIso8601String();
  final schedule = input['schedules'][0] as Map<String, dynamic>;
  schedule.addAll({
    'civilTime': time,
    'timeZoneId': 'UTC',
    'occurrenceOffsetSeconds': 0,
    'recurringSegmentId': 'seg',
    'recurringSlotKey': time,
    'recurringOrdinal': ordinal,
    'preparationDefinitionId': 'def',
    'recurringOverrides': '',
  });
  input['recurring'] = {
    'definitions': [
      {
        'id': 'def',
        'ownerId': 'series',
        'scope': 'recurring',
        'name': 'Prep',
        'createdAt': DateTime.utc(2024).millisecondsSinceEpoch,
      },
    ],
    'steps': [
      {
        'id': 'step',
        'definitionId': 'def',
        'name': 'Step',
        'minutes': 0,
        'position': 0,
      },
    ],
    'segments': [
      {
        'id': 'seg',
        'seriesId': 'series',
        'preparationId': 'def',
        'fromSlot': start,
        'beforeSlot': null,
        'createdAt': DateTime.utc(2024).millisecondsSinceEpoch,
        'preparationNotBefore': null,
        'ruleJson': jsonEncode({
          'frequency': 'daily',
          'start': start,
          'zone': 'UTC',
          'interval': 1,
          'weekdays': [],
          'monthly': 'dayOfMonth',
          'monthDay': 1,
          'ordinal': 1,
          'monthWeekday': 1,
          'until': null,
          'count': null,
          'repeatedTime': null,
        }),
        'scheduleJson': jsonEncode({
          'id': 'series',
          'placeId': 'p1',
          'place': 'Office',
          'name': 'Meeting',
          'time': start,
          'zone': 'UTC',
          'offset': 0,
          'move': 0,
          'spare': 0,
          'note': '',
        }),
      },
    ],
    'exclusions': <dynamic>[],
  };
  return input;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'candidate transaction rolls back all portable rows on a later insert failure',
    () async {
      final input =
          jsonDecode(jsonEncode(validBackup())) as Map<String, dynamic>;
      final second = jsonDecode(jsonEncode(input['schedules'][0]));
      second['id'] = 'second';
      input['schedules'].add(second);
      final checked = await validate(input);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customStatement(
        "CREATE TRIGGER fail_second BEFORE INSERT ON schedules WHEN NEW.id='second' BEGIN SELECT RAISE(ABORT,'injected late candidate failure'); END",
      );
      await expectLater(
        checked.materialize(db, pendingCleanup: false),
        throwsA(isA<Exception>()),
      );
      for (final table in [
        'users',
        'places',
        'schedules',
        'preparation_users',
      ]) {
        expect(
          (await db
                  .customSelect('SELECT count(*) AS n FROM $table')
                  .getSingle())
              .read<int>('n'),
          0,
        );
      }
      await db.customStatement('DROP TRIGGER fail_second');
      await checked.materialize(db, pendingCleanup: false);
      await checked.validateReadBack(db, pendingCleanup: false);
      expect(await db.select(db.schedules).get(), hasLength(2));
    },
  );
  test(
    'forward top-level order validates then materializes original records',
    () async {
      final input =
          jsonDecode(jsonEncode(validBackup())) as Map<String, dynamic>;
      final reversed = Map<String, dynamic>.fromEntries(
        input.entries.toList().reversed,
      );
      final checked = await validate(reversed);
      final target = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(target.close);
      await checked.materialize(target, pendingCleanup: true);
      await checked.validateReadBack(target, pendingCleanup: true);
      expect(checked.preview.scheduleCount, 1);
      expect((await target.select(target.schedules).getSingle()).id, 's1');
      final user = await target.select(target.users).getSingle();
      expect(user.dataRevision, 2);
      expect(user.restoreCleanupPending, isTrue);
      expect(
        (await target.select(target.preparationUsers).getSingle())
            .preparationTime,
        0,
      );
    },
  );
  test('same place identity with conflicting content is rejected', () async {
    final input = jsonDecode(jsonEncode(validBackup())) as Map<String, dynamic>;
    input['schedules'].add({
      ...input['schedules'][0],
      'id': 's2',
      'place': {'id': 'p1', 'name': 'Other'},
    });
    await expectLater(validate(input), throwsFormatException);
  });
  test('duplicate schedule input counts before duplicate rejection', () async {
    final input = jsonDecode(jsonEncode(validBackup())) as Map<String, dynamic>;
    input['schedules'].add(<String, dynamic>{...input['schedules'][0]});
    final budget = BackupBudget();
    await expectLater(validate(input, budget: budget), throwsFormatException);
    expect(budget.schedules, 2);
  });
  for (final civil in ['2025-11-02T01:30:00', '2025-03-09T02:30:00']) {
    test('old null-offset history preserves uncertainty for $civil', () async {
      final input =
          jsonDecode(jsonEncode(validBackup())) as Map<String, dynamic>;
      input['schedules'][0]['civilTime'] = civil;
      input['schedules'][0]['timeZoneId'] = 'America/New_York';
      input['schedules'][0]['occurrenceOffsetSeconds'] = null;
      final checked = await validate(input);
      expect(checked.uncertainHistoryCount, 1);
      expect(checked.timezoneChangeCount, 0);
      final target = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(target.close);
      await checked.materialize(target, pendingCleanup: false);
      expect(
        (await target.select(target.schedules).getSingle())
            .occurrenceOffsetSeconds,
        isNull,
      );
    });
  }
  for (final civil in ['2027-11-07T01:30:00', '2027-03-14T02:30:00']) {
    test(
      'future gap or unresolved overlap blocks preview for $civil',
      () async {
        final input =
            jsonDecode(jsonEncode(validBackup())) as Map<String, dynamic>;
        input['schedules'][0]['civilTime'] = civil;
        input['schedules'][0]['timeZoneId'] = 'America/New_York';
        input['schedules'][0]['occurrenceOffsetSeconds'] = null;
        await expectLater(
          validate(input),
          throwsA(
            isA<BackupProcessingFailure>().having(
              (e) => e.kind,
              'kind',
              BackupFailureKind.timeZoneChoiceRequired,
            ),
          ),
        );
      },
    );
  }
  test(
    'huge legal legacy duration is not silently given a new UI limit',
    () async {
      final input =
          jsonDecode(jsonEncode(validBackup())) as Map<String, dynamic>;
      input['schedules'][0]['moveTimeMinutes'] = 50000;
      expect((await validate(input)).preview.scheduleCount, 1);
    },
  );
  test(
    'recurring original records pass per-segment bounded validation',
    () async {
      final checked = await validate(recurringBackup());
      final target = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(target.close);
      await checked.materialize(target, pendingCleanup: false);
      await checked.validateReadBack(target, pendingCleanup: false);
      expect(
        (await target.select(target.schedules).getSingle()).recurringOrdinal,
        3,
      );
    },
  );
  test(
    'calendar ordinal upper bound rejects even historic UTC input',
    () async {
      await expectLater(
        validate(recurringBackup(ordinal: 4)),
        throwsFormatException,
      );
    },
  );
  test(
    'schedule and exclusion cannot claim the same normalized civil slot',
    () async {
      final input = recurringBackup();
      input['recurring']['exclusions'].add({
        'segmentId': 'seg',
        'slotKey': '2025-01-03T09:00:00',
        'ordinal': 3,
      });
      await expectLater(validate(input), throwsFormatException);
    },
  );
  test(
    'historic current-rule ordinal mismatch preserves original and reports uncertainty',
    () async {
      List<int> changed(DateTime civil, String zone, BackupBudget budget) {
        budget.visit();
        return civil.day == 1 ? [] : [0];
      }

      final checked = await validate(recurringBackup(), offsetLookup: changed);
      expect(checked.uncertainHistoryCount, 1);
      final target = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(target.close);
      await checked.materialize(target, pendingCleanup: false);
      expect(
        (await target.select(target.schedules).getSingle()).recurringOrdinal,
        3,
      );
    },
  );
  test(
    'future current-rule ordinal mismatch blocks without rewriting',
    () async {
      List<int> changed(DateTime civil, String zone, BackupBudget budget) {
        budget.visit();
        return civil.day == 1 ? [] : [0];
      }

      await expectLater(
        validate(recurringBackup(year: 2027), offsetLookup: changed),
        throwsA(
          isA<BackupProcessingFailure>().having(
            (e) => e.kind,
            'kind',
            BackupFailureKind.timeZoneChoiceRequired,
          ),
        ),
      );
    },
  );
  test('legacy per-step safe duration sum cannot overflow', () async {
    final input = jsonDecode(jsonEncode(validBackup())) as Map<String, dynamic>;
    input['defaultPreparation'] = [
      {
        'id': 'a',
        'name': 'A',
        'minutes': 0x7fffffffffffffff ~/ 60000000,
        'nextId': 'b',
      },
      {'id': 'b', 'name': 'B', 'minutes': 1, 'nextId': null},
    ];
    await expectLater(validate(input), throwsFormatException);
  });
  test(
    'checked sum and year boundary reject before target database exists',
    () async {
      final input =
          jsonDecode(jsonEncode(validBackup())) as Map<String, dynamic>;
      input['schedules'][0]['moveTimeMinutes'] = 0x7fffffffffffffff ~/ 60000000;
      input['schedules'][0]['spareTimeMinutes'] = 1;
      await expectLater(validate(input), throwsFormatException);
    },
  );
  test(
    '1000 definition steps are effective even when schedule preparation is empty',
    () async {
      final input = recurringBackup(year: 2);
      input['recurring']['steps'] = [
        for (var i = 0; i < 1000; i++)
          {
            'id': 'step-$i',
            'definitionId': 'def',
            'name': 'Step',
            'minutes': 1440,
            'position': i,
          },
      ];
      // 1000 individually legal days exceed year 0002's distance from year 0001.
      await expectLater(validate(input), throwsFormatException);
      final legal = recurringBackup();
      legal['recurring']['steps'] = input['recurring']['steps'];
      expect((await validate(legal)).preview.scheduleCount, 1);
    },
  );
  test('checked legacy lead subtraction cannot wrap below year one', () async {
    final input = validBackup();
    input['schedules'][0]['civilTime'] = '0001-01-02T09:00:00Z';
    input['schedules'][0]['moveTimeMinutes'] = 0x7fffffffffffffff ~/ 60000000;
    await expectLater(validate(input), throwsFormatException);
  });
  test(
    'historic null instant and ordinal mismatch count once with bounded examples',
    () async {
      final input = recurringBackup();
      input['schedules'][0]['occurrenceOffsetSeconds'] = null;
      List<int> changed(DateTime c, String z, BackupBudget b) {
        b.visit();
        return c.day == 1 ? [] : [0];
      }

      final checked = await validate(input, offsetLookup: changed);
      expect(checked.preview.uncertainHistoryCount, 1);
      expect(checked.preview.uncertainHistoryExamples, hasLength(1));
      expect(checked.preview.uncertainHistoryExamples.single.name, 'Meeting');
    },
  );
  test(
    'multiple original segments retain independent bounded ordinal and exclusion relations',
    () async {
      final first = recurringBackup();
      final second = recurringBackup(year: 2024);
      final segment = second['recurring']['segments'][0];
      segment['id'] = 'seg2';
      segment['seriesId'] = 'series';
      segment['preparationId'] = 'def2';
      segment['beforeSlot'] = '2025-01-01T09:00:00Z';
      final base = jsonDecode(segment['scheduleJson']);
      base['id'] = 'series';
      segment['scheduleJson'] = jsonEncode(base);
      final def = second['recurring']['definitions'][0];
      def['id'] = 'def2';
      def['ownerId'] = 'series';
      final step = second['recurring']['steps'][0];
      step['id'] = 'step2';
      step['definitionId'] = 'def2';
      final schedule = second['schedules'][0];
      schedule['id'] = 's2';
      schedule['recurringSegmentId'] = 'seg2';
      schedule['preparationDefinitionId'] = 'def2';
      first['schedules'].add(schedule);
      for (final kind in ['definitions', 'steps', 'segments']) {
        first['recurring'][kind].addAll(second['recurring'][kind]);
      }
      first['recurring']['exclusions'].add({
        'segmentId': 'seg2',
        'slotKey': '2024-01-02T09:00:00Z',
        'ordinal': 2,
      });
      final checked = await validate(first);
      final target = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(target.close);
      await checked.materialize(target, pendingCleanup: false);
      await checked.validateReadBack(target, pendingCleanup: false);
      expect(checked.preview.scheduleCount, 2);
      expect(
        await target.select(target.recurringScheduleSegments).get(),
        hasLength(2),
      );
    },
  );
}
