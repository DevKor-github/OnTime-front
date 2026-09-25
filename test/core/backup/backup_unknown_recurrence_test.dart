import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_ingestion_store.dart';
import 'package:on_time_front/core/backup/backup_limits.dart';
import 'package:on_time_front/core/backup/backup_validated_ingestion.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/domain/entities/backup_operation.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';

import 'backup_validated_ingestion_test.dart' show recurringBackup;

const zone = 'Old/Removed_Recurring_Zone';
final now = DateTime.utc(2026, 9, 24);

Map<String, dynamic> input({bool closed = false}) {
  final value = recurringBackup();
  value['schedules'][0]['timeZoneId'] = zone;
  final segment = value['recurring']['segments'][0];
  final rule = jsonDecode(segment['ruleJson'] as String);
  rule['zone'] = zone;
  if (closed) {
    segment['beforeSlot'] = '2025-01-03T09:00:00';
  } else {
    rule['until'] = '2025-01-03T00:00:00';
  }
  segment['ruleJson'] = jsonEncode(rule);
  final prototype = jsonDecode(segment['scheduleJson'] as String);
  prototype['zone'] = zone;
  segment['scheduleJson'] = jsonEncode(prototype);
  return value;
}

Future<BackupValidatedIngestion> validate(
  Map<String, dynamic> value, {
  DateTime? at,
}) => BackupValidatedIngestion.validateOwnedSnapshot(
  plaintext: Stream.value(utf8.encode(jsonEncode(value))),
  budget: BackupBudget(),
  createStore: (budget) async => BackupIngestionStore.memoryForTesting(budget),
  nowUtc: at ?? now,
);

void changeRule(
  Map<String, dynamic> value,
  void Function(Map<String, dynamic>) edit,
) {
  final segment = value['recurring']['segments'][0];
  final rule =
      jsonDecode(segment['ruleJson'] as String) as Map<String, dynamic>;
  edit(rule);
  segment['ruleJson'] = jsonEncode(rule);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final closed in [false, true]) {
    test(
      'unknown ${closed ? 'exclusive bound' : 'inclusive until'} proof changes exactly at its latest possible instant',
      () async {
        final value = input(closed: closed);
        final boundary = closed
            ? DateTime.utc(2025, 1, 4, 9)
            : DateTime.utc(2025, 1, 5);
        await expectLater(
          validate(
            value,
            at: boundary.subtract(const Duration(microseconds: 1)),
          ),
          throwsA(
            isA<BackupProcessingFailure>().having(
              (e) => e.kind,
              'not yet proved',
              BackupFailureKind.timeZoneChoiceRequired,
            ),
          ),
        );
        final checked = await validate(value, at: boundary);
        addTearDown(checked.release);
        expect(checked.preview.timezoneChangeCount, 0);
        expect(checked.preview.uncertainHistoryCount, greaterThan(0));
      },
    );
  }
  for (final closed in [false, true]) {
    test(
      'unknown historical ${closed ? 'closed retained tail' : 'inclusive until'} preserves source relations',
      () async {
        final value = input(closed: closed);
        final original = jsonEncode(value);
        final checked = await validate(value);
        addTearDown(checked.release);
        expect(checked.timezoneChangeCount, 0);
        expect(
          checked.preview.uncertainHistoryExamples.map((e) => e.reason),
          contains(BackupHistoryUncertaintyReason.historicalOrdinal),
        );
        final target = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(target.close);
        await checked.materialize(target, pendingCleanup: true);
        await checked.validateReadBack(target, pendingCleanup: true);
        final segment = await target
            .select(target.recurringScheduleSegments)
            .getSingle();
        expect(segment.ruleJson, value['recurring']['segments'][0]['ruleJson']);
        expect(
          segment.scheduleJson,
          value['recurring']['segments'][0]['scheduleJson'],
        );
        expect(
          segment.beforeSlot,
          value['recurring']['segments'][0]['beforeSlot'],
        );
        final row = await target.select(target.schedules).getSingle();
        expect(row.timeZoneId, zone);
        expect(row.occurrenceOffsetSeconds, 0);
        expect(row.recurringOrdinal, 3);
        expect(row.isStarted, isFalse);
        expect(jsonEncode(value), original);
      },
    );
  }
  for (final boundary in [
    'open',
    'future before',
    'future until',
    'count only',
  ]) {
    test(
      'unknown $boundary with no materialized row cannot become ready',
      () async {
        final value = input();
        value['schedules'] = <dynamic>[];
        value['schedulePreparations'] = <String, dynamic>{};
        changeRule(value, (rule) {
          rule['until'] = boundary == 'future until'
              ? '2030-01-03T00:00:00'
              : null;
          rule['count'] = boundary == 'count only' ? 3 : null;
        });
        if (boundary == 'future before') {
          value['recurring']['segments'][0]['beforeSlot'] =
              '2030-01-03T09:00:00';
        }
        await expectLater(
          validate(value),
          throwsA(
            isA<BackupProcessingFailure>().having(
              (e) => e.kind,
              'typed time review',
              BackupFailureKind.timeZoneChoiceRequired,
            ),
          ),
        );
      },
    );
  }
  test(
    'historical rule cannot hide its future unresolved time override',
    () async {
      final value = input();
      value['schedules'][0]['civilTime'] = '2030-01-03T09:00:00';
      value['schedules'][0]['recurringOverrides'] = 'time';
      await expectLater(
        validate(value),
        throwsA(
          isA<BackupProcessingFailure>().having(
            (e) => e.kind,
            'typed time review',
            BackupFailureKind.timeZoneChoiceRequired,
          ),
        ),
      );
    },
  );
  final invalid = <String, void Function(Map<String, dynamic>)>{
    'calendar membership': (value) =>
        changeRule(value, (rule) => rule['interval'] = 3),
    'ordinal upper bound': (value) =>
        value['schedules'][0]['recurringOrdinal'] = 4,
    'count upper bound': (value) =>
        changeRule(value, (rule) => rule['count'] = 2),
    'owner': (value) =>
        value['recurring']['definitions'][0]['ownerId'] = 'other-series',
    'duplicate combined slot': (value) => value['recurring']['exclusions'] = [
      {
        'segmentId': 'seg',
        'slotKey': value['schedules'][0]['recurringSlotKey'],
        'ordinal': 3,
      },
    ],
  };
  for (final entry in invalid.entries) {
    test('unknown preserved rule still rejects ${entry.key}', () async {
      // Count and until are mutually exclusive. Isolate the ordinal/count
      // constraint rather than letting the rule shape reject this first.
      final value = input(closed: entry.key == 'count upper bound');
      entry.value(value);
      await expectLater(
        validate(value),
        throwsA(
          isA<BackupProcessingFailure>().having(
            (e) => e.kind,
            'hard invariant',
            BackupFailureKind.dataInvariant,
          ),
        ),
      );
    });
  }
}
