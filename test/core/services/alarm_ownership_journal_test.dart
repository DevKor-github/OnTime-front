import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/services/alarm_journal_store_native.dart';
import 'package:on_time_front/core/services/alarm_ownership_journal.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('ontime-journal-test-');
  });
  tearDown(() async => directory.delete(recursive: true));

  AlarmOwnershipJournal reopen({Future<void> Function(String)? checkpoint}) =>
      AlarmOwnershipJournal(
        FileAlarmJournalStore(() async => directory, checkpoint: checkpoint),
      );

  test(
    'independent file retains only cancellation identity across reopen',
    () async {
      final journal = reopen();
      await journal.remember([record('same', 11), record('same', 12)]);
      final raw = await File(
        '${directory.path}/ownership-v1.json',
      ).readAsString();
      for (final secret in [
        'PRIVATE TITLE',
        'PRIVATE PAYLOAD',
        'PRIVATE FINGERPRINT',
        '2030',
      ]) {
        expect(raw, isNot(contains(secret)));
      }
      final again = await reopen().read();
      expect(again.ownership.keys.toSet(), {
        'localNotification:11',
        'localNotification:12',
      });
      expect(again.ownership.values.every((entry) => entry.pending), true);
      expect(again.reset, ResetPhase.none);
      await reopen().remember([record('same', 11)], pending: false);
      await reopen().confirmedCancelled(record('same', 11));
      expect((await reopen().read()).ownership.keys, ['localNotification:12']);
    },
  );

  for (final point in ['written', 'verified', 'renamed', 'readBack']) {
    test(
      'interrupted replacement at $point reopens a complete committed generation',
      () async {
        await reopen().remember([record('old', 1)]);
        final interrupted = reopen(
          checkpoint: (stage) async {
            if (stage == point) throw StateError('simulated interruption');
          },
        );
        await expectLater(
          interrupted.remember([record('new', 2)]),
          throwsStateError,
        );
        final restored = await reopen().read();
        expect(
          restored.ownership.keys.toSet(),
          point == 'written' || point == 'verified'
              ? {'localNotification:1'}
              : {'localNotification:1', 'localNotification:2'},
        );
        // A subsequent complete write replaces any leftover staged generation.
        await reopen().remember([record('retry', 3)]);
        expect(
          (await reopen().read()).ownership.containsKey('localNotification:3'),
          true,
        );
      },
    );
  }

  test(
    'staged first write is preserved and never reported as an empty installation',
    () async {
      final interrupted = reopen(
        checkpoint: (stage) async {
          if (stage == 'written') throw StateError('stop before commit');
        },
      );
      await expectLater(
        interrupted.remember([record('first', 1)]),
        throwsStateError,
      );
      final staged = File('${directory.path}/ownership-v1.json.pending');
      final bytes = await staged.readAsBytes();
      final recovered = await reopen().read();
      expect(recovered.ownership.keys, ['localNotification:1']);
      expect(recovered.ownership.values.single.pending, true);
      expect(await staged.exists(), false);
      expect(
        await File('${directory.path}/ownership-v1.json').readAsBytes(),
        bytes,
      );
    },
  );

  test(
    'truncated staged first write is preserved and blocks new ownership',
    () async {
      final staged = File('${directory.path}/ownership-v1.json.pending');
      await staged.writeAsString('{truncated');
      await expectLater(
        reopen().read(),
        throwsA(isA<AlarmJournalUnavailable>()),
      );
      await expectLater(
        reopen().remember([record('new', 2)]),
        throwsA(isA<AlarmJournalUnavailable>()),
      );
      expect(await staged.readAsString(), '{truncated');
    },
  );

  for (final raw in [
    '{broken',
    '{"version":2}',
    '{"version":1,"ownership":[]}',
  ]) {
    test(
      'malformed or unsupported committed journal stays intact: $raw',
      () async {
        final file = File('${directory.path}/ownership-v1.json');
        await file.writeAsString(raw);
        await expectLater(
          reopen().read(),
          throwsA(isA<AlarmJournalUnavailable>()),
        );
        await expectLater(
          reopen().remember([record('new', 2)]),
          throwsA(isA<AlarmJournalUnavailable>()),
        );
        expect(await file.readAsString(), raw);
      },
    );
  }

  test('backup exclusion failure prevents creating ownership bytes', () async {
    final store = FileAlarmJournalStore(
      () async => directory,
      excludeFromBackup: (_) async => throw StateError('exclusion failed'),
    );
    await expectLater(
      AlarmOwnershipJournal(store).remember([record('a', 1)]),
      throwsStateError,
    );
    expect(await directory.list().toList(), isEmpty);
  });

  test('only a fully completed reset journal can be removed', () async {
    await reopen().remember([record('still-active', 1)]);
    await expectLater(
      reopen().removeCompleted(),
      throwsA(isA<AlarmJournalUnavailable>()),
    );
    expect((await reopen().read()).ownership, isNotEmpty);
    await reopen().confirmedCancelled(record('still-active', 1));
    await reopen().save(
      AlarmJournalSnapshot(
        reset: ResetPhase.complete,
        completed: ResetStep.values.toSet(),
      ),
    );
    await reopen().removeCompleted();
    expect(await directory.list().toList(), isEmpty);
  });

  test(
    'duplicate actual platform IDs are rejected instead of hiding ownership',
    () {
      final entry = AlarmOwnership(record('same', 1), pending: true).toJson();
      final raw = jsonEncode({
        'version': 1,
        'reset': 'none',
        'completed': [],
        'ownership': [
          entry,
          {...entry, 'scheduleId': 'another-label'},
        ],
      });
      expect(
        () => AlarmJournalSnapshot.decode(raw),
        throwsA(isA<AlarmJournalUnavailable>()),
      );
    },
  );

  test(
    'impossible completion states cannot be written over a valid journal',
    () async {
      final journal = reopen();
      await journal.remember([record('active', 1)]);
      final file = File('${directory.path}/ownership-v1.json');
      final original = await file.readAsBytes();
      for (final invalid in [
        AlarmJournalSnapshot(completed: {ResetStep.database}),
        AlarmJournalSnapshot(
          reset: ResetPhase.complete,
          completed: {ResetStep.database},
        ),
        AlarmJournalSnapshot(
          reset: ResetPhase.pending,
          completed: {ResetStep.deliveries},
          ownership: {
            'localNotification:1': AlarmOwnership(
              record('active', 1),
              pending: false,
            ),
          },
        ),
      ]) {
        await expectLater(
          journal.save(invalid),
          throwsA(isA<AlarmJournalUnavailable>()),
        );
        expect(await file.readAsBytes(), original);
      }
    },
  );
}

ScheduledAlarmRecord record(String scheduleId, int id) => ScheduledAlarmRecord(
  scheduleId: scheduleId,
  provider: AlarmProvider.localNotification,
  fallbackNotificationId: id,
  alarmTime: DateTime.utc(2030, 1, 1),
  preparationStartTime: DateTime.utc(2030, 1, 1),
  scheduleFingerprint: 'PRIVATE FINGERPRINT',
  scheduleTitle: 'PRIVATE TITLE',
  payload: const {'secret': 'PRIVATE PAYLOAD'},
);
