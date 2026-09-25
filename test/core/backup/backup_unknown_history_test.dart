// Owned plaintext snapshot adapter + actual SQLite materialization/readback.
// This does not prove ciphertext authentication, SQLCipher, service or OS UI.
import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_ingestion_store.dart';
import 'package:on_time_front/core/backup/backup_limits.dart';
import 'package:on_time_front/core/backup/backup_validated_ingestion.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/domain/entities/backup_operation.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';
import 'backup_validation_contract_test.dart' show validBackup;

const _removedZone = 'Old/Removed_Test_Zone';
final _now = DateTime.utc(2026, 9, 24);
Map<String, dynamic> _input() {
  final input = jsonDecode(jsonEncode(validBackup())) as Map<String, dynamic>;
  input['schedules'][0].addAll({
    'civilTime': '2020-01-01T09:00:00.123456',
    'timeZoneId': _removedZone,
    'occurrenceOffsetSeconds': 32400,
  });
  return input;
}

Future<BackupValidatedIngestion> _validate(Map<String, dynamic> input) =>
    BackupValidatedIngestion.validateOwnedSnapshot(
      plaintext: Stream.value(utf8.encode(jsonEncode(input))),
      budget: BackupBudget(),
      createStore: (budget) async =>
          BackupIngestionStore.memoryForTesting(budget),
      nowUtc: _now,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final scenario in [
    'past selected',
    'past null',
    'completed',
    'protected start',
  ]) {
    test(
      'owned snapshot preserves unknown-zone $scenario without granting a live run',
      () async {
        final input = _input();
        final source = input['schedules'][0] as Map<String, dynamic>;
        if (scenario == 'past null') source['occurrenceOffsetSeconds'] = null;
        if (scenario == 'completed' || scenario == 'protected start') {
          // Protected facts can precede the originally future commitment. This
          // must not be misclassified as an unstarted future unknown appointment.
          source['civilTime'] = '2030-01-01T09:00:00.123456';
          source['startedAt'] = '2026-09-23T00:00:00Z';
          source['preparationFrozen'] = true;
        }
        if (scenario == 'completed') {
          source['doneStatus'] = 'normalEnd';
          source['finishedAt'] = '2026-09-23T00:01:00Z';
        }
        final original = jsonEncode(input);
        final checked = await _validate(input);
        addTearDown(checked.release);
        expect(checked.preview.scheduleCount, 1);
        expect(checked.timezoneChangeCount, 0);
        expect(checked.preview.uncertainHistoryCount, 1);
        final notice = checked.preview.uncertainHistoryExamples.single;
        expect(notice.zone, _removedZone);
        expect(
          notice.reason,
          scenario == 'protected start'
              ? BackupHistoryUncertaintyReason.protectedStartZone
              : BackupHistoryUncertaintyReason.unavailableHistoricalZone,
        );
        final target = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(target.close);
        await checked.materialize(target, pendingCleanup: true);
        await checked.validateReadBack(target, pendingCleanup: true);
        final stored = await target.select(target.schedules).getSingle();
        expect(stored.id, source['id']);
        expect(stored.timeZoneId, _removedZone);
        expect(
          stored.occurrenceOffsetSeconds,
          source['occurrenceOffsetSeconds'],
        );
        expect(
          (await target
                  .customSelect('SELECT schedule_time FROM schedules')
                  .getSingle())
              .read<String>('schedule_time'),
          source['civilTime'],
        );
        expect(stored.isStarted, isFalse);
        expect(stored.preparationFrozen, source['preparationFrozen'] ?? false);
        expect(
          stored.startedAt?.toUtc(),
          source['startedAt'] == null
              ? null
              : DateTime.parse(source['startedAt'] as String),
        );
        expect(
          stored.finishedAt?.toUtc(),
          source['finishedAt'] == null
              ? null
              : DateTime.parse(source['finishedAt'] as String),
        );
        expect(stored.doneStatus, source['doneStatus']);
        expect(
          stored.requiresStartConfirmation,
          source['doneStatus'] == 'notEnded',
        );
        expect(jsonEncode(input), original);
      },
    );
  }
  for (final offset in [null, 32400]) {
    test(
      'future unstarted unknown zone remains rejected with offset $offset',
      () async {
        final input = _input();
        input['schedules'][0]['civilTime'] = '2030-01-01T09:00:00';
        input['schedules'][0]['occurrenceOffsetSeconds'] = offset;
        await expectLater(
          _validate(input),
          throwsA(isA<BackupProcessingFailure>()),
        );
      },
    );
  }

  final malformed = <String, void Function(Map<String, dynamic>)>{
    'zone scalar type': (input) => input['schedules'][0]['timeZoneId'] = 42,
    'oversized zone': (input) =>
        input['schedules'][0]['timeZoneId'] = 'z' * 513,
    'invalid civil calendar': (input) =>
        input['schedules'][0]['civilTime'] = '2020-02-30T09:00:00',
    'invalid selected offset': (input) =>
        input['schedules'][0]['occurrenceOffsetSeconds'] = 86401,
    'future frozen without start': (input) {
      input['schedules'][0]['civilTime'] = '2030-01-01T09:00:00';
      input['schedules'][0]['preparationFrozen'] = true;
    },
    'offsetless start instant': (input) {
      input['schedules'][0]['startedAt'] = '2020-01-01T00:00:00';
      input['schedules'][0]['preparationFrozen'] = true;
    },
    'offsetless finish instant': (input) {
      input['schedules'][0]['finishedAt'] = '2020-01-01T00:01:00';
      input['schedules'][0]['doneStatus'] = 'normalEnd';
    },
    'orphan preparation': (input) =>
        input['schedulePreparations']['not-a-schedule'] = [],
    'duplicate schedule identity': (input) => input['schedules'].add(
      Map<String, dynamic>.from(input['schedules'][0]),
    ),
  };
  for (final entry in malformed.entries) {
    test('unknown history does not excuse ${entry.key}', () async {
      // The known-zone control ensures the structural rejection is independently
      // real, rather than passing only because the current unknown-zone gate fails.
      for (final zone in ['UTC', _removedZone]) {
        final input = _input();
        input['schedules'][0]['timeZoneId'] = zone;
        if (zone == 'UTC') input['schedules'][0]['occurrenceOffsetSeconds'] = 0;
        entry.value(input);
        final original = jsonEncode(input);
        await expectLater(_validate(input), throwsFormatException);
        expect(jsonEncode(input), original);
      }
    });
  }
}
