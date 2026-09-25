import 'package:on_time_front/domain/entities/civil_date_time.dart';
// Structured synthetic QA evidence is intentionally emitted to captured logs.
// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/backup/backup_export_snapshot.dart';
import 'package:on_time_front/core/backup/backup_ingestion_store.dart';
import 'package:on_time_front/core/backup/backup_json_reader.dart';
import 'package:on_time_front/core/backup/backup_limits.dart';
import 'package:on_time_front/core/backup/backup_validated_ingestion.dart';
import 'package:on_time_front/core/backup/restore_staging.dart';
import 'package:on_time_front/core/utils/json_converters/duration_json_converters.dart';
import 'backup_validation_contract_test.dart' show validBackup;
import 'backup_validated_ingestion_test.dart' show recurringBackup;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'foreign civil gap preserves raw DB and portable reexport through candidate copy',
    () async {
      final input =
          jsonDecode(jsonEncode(validBackup())) as Map<String, dynamic>;
      input['schedules'][0]['civilTime'] = '2026-03-08T02:30:00.123456';
      input['schedules'][0]['timeZoneId'] = 'Asia/Seoul';
      final budget = BackupBudget();
      final raw = BackupIngestionStore.memoryForTesting(budget);
      addTearDown(raw.release);
      final node = await BackupJsonReader(
        raw,
        budget,
      ).read(Stream.value(utf8.encode(jsonEncode(input))));
      final content = await BackupValidatedIngestion.validateTestStore(
        raw,
        node,
        nowUtc: DateTime.utc(2026, 9, 24),
      );
      final candidate = AppDatabase.forTesting(NativeDatabase.memory());
      final active = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(candidate.close);
      addTearDown(active.close);
      await content.materialize(candidate, pendingCleanup: false);
      await content.validateReadBack(candidate, pendingCleanup: false);
      await copyPortableBackupRows(candidate, active, budget: BackupBudget());
      for (final database in [candidate, active]) {
        final stored =
            (await database
                    .customSelect('SELECT schedule_time FROM schedules')
                    .getSingle())
                .read<String>('schedule_time');
        expect(stored, '2026-03-08T02:30:00.123456');
        final snapshot = await BackupExportSnapshot.create(
          database,
          cutoff: DateTime.utc(2026, 9, 24),
          sourceAppVersion: 'test',
          sourcePlatform: 'test',
          budget: BackupBudget(),
          stagingFactory: () async {
            final db = AppDatabase.forTesting(NativeDatabase.memory());
            return RestoreStaging(db, db.close);
          },
        );
        try {
          final json = jsonDecode(
            utf8.decode(await snapshot.plaintext().expand((c) => c).toList()),
          );
          expect(json['schedules'][0]['civilTime'], stored);
          expect(json['schedules'][0]['occurrenceOffsetSeconds'], 32400);
        } finally {
          await snapshot.release();
        }
      }
      // A10 now reads the preserved wall fields through a neutral carrier.
      // The instant still requires the stored explicit offset.
      final typed =
          (await active.select(active.schedules).getSingle()).scheduleTime;
      expect(
        CivilDateTime.fromFields(typed),
        CivilDateTime.parse('2026-03-08T02:30:00.123456'),
      );
      expect(
        CivilDateTime.fromFields(typed).atOffset(32400),
        DateTime.utc(2026, 3, 7, 17, 30, 0, 123, 456),
      );
      print(
        'D05_RAW_CIVIL localHour=${typed.hour} zone=${typed.timeZoneName} rawHour=2',
      );
    },
  );
  test(
    'recurring civil slots, exclusion and explicit completion survive portable boundary',
    () async {
      final input = recurringBackup(ordinal: 2);
      const start = '2026-03-07T02:30:00';
      const slot = '2026-03-08T02:30:00';
      final schedule = input['schedules'][0];
      schedule.addAll({
        'civilTime': slot,
        'recurringSlotKey': slot,
        'timeZoneId': 'Asia/Seoul',
        'occurrenceOffsetSeconds': 32400,
        'finishedAt': '2026-03-07T17:30:00Z',
      });
      final segment = input['recurring']['segments'][0];
      segment['fromSlot'] = start;
      final rule = jsonDecode(segment['ruleJson']);
      rule['start'] = start;
      rule['zone'] = 'Asia/Seoul';
      segment['ruleJson'] = jsonEncode(rule);
      final base = jsonDecode(segment['scheduleJson']);
      base['time'] = start;
      base['zone'] = 'Asia/Seoul';
      base['offset'] = 32400;
      segment['scheduleJson'] = jsonEncode(base);
      input['recurring']['exclusions'].add({
        'segmentId': 'seg',
        'slotKey': '2026-03-09T02:30:00',
        'ordinal': 3,
      });
      final budget = BackupBudget();
      final raw = BackupIngestionStore.memoryForTesting(budget);
      addTearDown(raw.release);
      final node = await BackupJsonReader(
        raw,
        budget,
      ).read(Stream.value(utf8.encode(jsonEncode(input))));
      final content = await BackupValidatedIngestion.validateTestStore(
        raw,
        node,
        nowUtc: DateTime.utc(2026, 9, 24),
      );
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await content.materialize(db, pendingCleanup: true);
      await content.validateReadBack(db, pendingCleanup: true);
      final row =
          (await db
                  .customSelect(
                    'SELECT schedule_time,recurring_slot_key,finished_at FROM schedules',
                  )
                  .getSingle())
              .data;
      expect(row['schedule_time'], '2026-03-08T02:30:00.000');
      expect(row['recurring_slot_key'], slot);
      expect(
        row['finished_at'],
        DateTime.utc(2026, 3, 7, 17, 30).millisecondsSinceEpoch ~/ 1000,
      );
      final snapshot = await BackupExportSnapshot.create(
        db,
        cutoff: DateTime.utc(2026, 9, 24),
        sourceAppVersion: 'test',
        sourcePlatform: 'test',
        budget: BackupBudget(),
        stagingFactory: () async {
          final target = AppDatabase.forTesting(NativeDatabase.memory());
          return RestoreStaging(target, target.close);
        },
      );
      try {
        final exported = jsonDecode(
          utf8.decode(await snapshot.plaintext().expand((c) => c).toList()),
        );
        expect(exported['recurring'], input['recurring']);
        expect(
          exported['schedules'][0]['civilTime'],
          '2026-03-08T02:30:00.000',
        );
        expect(
          exported['schedules'][0]['finishedAt'],
          '2026-03-07T17:30:00.000Z',
        );
      } finally {
        await snapshot.release();
      }
    },
  );
  test(
    'civil converter preserves fields while countdown requires an explicit offset',
    () {
      const converter = CivilDateTimeSqlConverter();
      final actual = converter.fromSql('2026-09-24T09:00:00.000');
      final now = DateTime.utc(2026, 9, 23, 23);
      expect(actual.isUtc, true);
      expect(
        CivilDateTime.fromFields(actual).atOffset(32400).difference(now),
        const Duration(hours: 1),
      );
      expect(converter.toSql(actual), '2026-09-24T09:00:00.000');
    },
  );
}
