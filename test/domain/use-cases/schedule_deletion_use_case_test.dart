import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/core/time/schedule_time_resolution.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/entities/timed_preparation_snapshot_entity.dart';
import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/services/alarm_journal_store_native.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/core/services/alarm_ownership_journal.dart';
import 'package:on_time_front/domain/entities/schedule_deletion.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
import '../../helpers/schedule_deletion_workflow_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DeletionWorkflowFixture f;
  late Directory directory;
  String? failingCheckpoint;
  Future<void> Function(String)? checkpointAction;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('u01-journal-');
    failingCheckpoint = null;
    checkpointAction = null;
    f = DeletionWorkflowFixture(
      journalStore: FileAlarmJournalStore(
        () async => directory,
        checkpoint: (stage) async {
          if (stage == failingCheckpoint) {
            throw const FileSystemException('injected persistence failure');
          }
          await checkpointAction?.call(stage);
        },
      ),
    );
    await f.open();
    await f.create();
    f.registry.records = [f.record('one', 11)];
  });
  tearDown(() async {
    await f.close();
    await directory.delete(recursive: true);
  });

  test(
    'prepare and abandoning confirmation have no DB/runtime/journal effects',
    () async {
      final revision = await f.revision();
      await f.deletion.prepare('one');
      expect(await f.revision(), revision);
      expect(await directory.list().toList(), isEmpty);
      expect(f.registry.writes, 0);
      expect(f.timed.cleared, isEmpty);
      expect(f.fallback.cancelled, isEmpty);
    },
  );

  for (final stage in ['written', 'readBack']) {
    test('actual file $stage failure cannot commit deletion', () async {
      final intent = await f.deletion.prepare('one');
      final revision = await f.revision();
      failingCheckpoint = stage;
      await expectLater(
        f.deletion.confirm(intent),
        throwsA(isA<FileSystemException>()),
      );
      expect(await f.db.select(f.db.schedules).get(), hasLength(1));
      expect(await f.revision(), revision);
      expect(f.timed.cleared, isEmpty);
      expect(f.fallback.cancelled, isEmpty);
    });
  }

  test(
    'pending provider keeps owner while committed row stays deleted and journal contains only identity',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      f.fallback.onCancel = (_) async {
        entered.complete();
        await release.future;
      };
      final intent = await f.deletion.prepare('one');
      ScheduleDeletionCommit? receipt;
      final future = f.deletion.confirm(
        intent,
        onCommitted: (value) => receipt = value,
      );
      // Observe completion immediately so an early failure cannot become an
      // unhandled error while the test is waiting for the provider barrier.
      final drained = future.then<void>(
        (_) {},
        onError: (Object _, StackTrace __) {},
      );
      Future<void>? queued;
      Future<void>? queuedDrained;
      try {
        expect(identical(future, f.deletion.confirm(intent)), isTrue);
        await Future.any<void>([
          entered.future,
          future.then<void>(
            (_) =>
                throw StateError('Deletion completed before provider barrier'),
          ),
        ]);
        expect(receipt?.changed, isTrue);
        expect(await f.db.select(f.db.schedules).get(), isEmpty);
        final raw = await File(
          '${directory.path}/ownership-v1.json',
        ).readAsString();
        expect(raw, contains('one'));
        expect(raw, isNot(contains('private')));
        var nextOwnerRan = false;
        queued = f.owner.run(f.owner.capture(), () async {
          nextOwnerRan = true;
        });
        queuedDrained = queued.then<void>(
          (_) {},
          onError: (Object _, StackTrace __) {},
        );
        await pumpEventQueue();
        expect(nextOwnerRan, isFalse);
        release.complete();
        expect((await future).cleanup, ScheduleDeletionCleanup.complete);
        await queued;
        expect(nextOwnerRan, isTrue);
        expect(f.fallback.cancelled, hasLength(1));
        expect((await f.owner.journal.read()).ownership, isEmpty);
      } finally {
        if (!release.isCompleted) release.complete();
        // Drain rather than replace a failed assertion with a secondary cleanup
        // error. The normal path above still asserts both operation outcomes.
        await drained;
        await queuedDrained;
      }
    },
  );

  test(
    'provider failure rehydrates actual file journal under new owner and retries cleanup only',
    () async {
      f.fallback.onCancel = (_) async {
        throw StateError('provider failed');
      };
      final intent = await f.deletion.prepare('one');
      final result = await f.deletion.confirm(
        intent,
        onCommitted: (_) => throw StateError('observer failed'),
      );
      expect(result.cleanup, ScheduleDeletionCleanup.pending);
      final revision = await f.revision();
      final rehydrated = AlarmOperationCoordinator(
        f.gate,
        journal: AlarmOwnershipJournal(
          FileAlarmJournalStore(() async => directory),
        ),
      );
      final sessions = f.makeSessions(rehydrated);
      addTearDown(() {
        sessions.dispose();
        rehydrated.dispose();
      });
      f.registry.records =
          []; // independent durable ownership survives lost registry projection
      f.fallback.onCancel = null;
      final newUseCase = f.makeDeletion(rehydrated, sessions);
      expect((await rehydrated.journal.read()).ownership, hasLength(1));
      final retried = await newUseCase.retryCleanup(result.commit);
      expect(retried.cleanup, ScheduleDeletionCleanup.complete);
      expect(await f.revision(), revision);
      expect(await f.db.select(f.db.schedules).get(), isEmpty);
      expect((await rehydrated.journal.read()).ownership, isEmpty);
    },
  );

  test(
    'a different confirmation already deleted the row: absence receipt does not claim a new commit',
    () async {
      final first = await f.deletion.prepare('one');
      final second = await f.deletion.prepare('one');
      await f.deletion.confirm(second);
      final revision = await f.revision();
      final result = await f.deletion.confirm(first);
      expect(result.commit.alreadyAbsent, isTrue);
      expect(result.commit.changed, isFalse);
      expect(await f.revision(), revision);
      expect(f.fallback.cancelled, hasLength(1));
    },
  );

  test(
    'following selected disappears before durable write ends: other occurrence ownership stays armed',
    () async {
      final start = DateTime.utc(2030, 1, 2, 10);
      await f.recurring.create(
        f.schedule('series').copyWith(scheduleTime: start),
        const PreparationEntity(
          preparationStepList: [
            PreparationStepEntity(
              id: 'series-step',
              preparationName: 'Prepare',
              preparationTime: Duration(minutes: 1),
            ),
          ],
        ),
        RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          start: start,
          timeZoneId: 'UTC',
          count: 3,
        ),
      );
      final rows =
          (await f.db.select(f.db.schedules).get())
              .where((v) => v.recurringSegmentId != null)
              .toList()
            ..sort((a, b) => a.scheduleTime.compareTo(b.scheduleTime));
      final selected = rows.first.id;
      final others = rows.skip(1).map((v) => v.id).toSet();
      f.registry.records = [
        for (var i = 0; i < rows.length; i++) f.record(rows[i].id, 30 + i),
      ];
      final intent = await f.deletion.prepare(
        selected,
        scope: RecurringEditScope.following,
      );
      final direct = await f.aggregate.readForDeletion(selected);
      var consumed = false;
      checkpointAction = (stage) async {
        if (stage == 'readBack' && !consumed) {
          consumed = true;
          await f.aggregate.delete(direct);
        }
      };
      final result = await f.deletion.confirm(intent);
      expect(result.commit.alreadyAbsent, isTrue);
      expect(result.commit.changed, isFalse);
      expect(
        (await f.db.select(f.db.schedules).get()).map((v) => v.id),
        containsAll(others),
      );
      expect(f.fallback.cancelled.map((v) => v.scheduleId), [selected]);
      final journal = await f.owner.journal.read();
      expect(
        journal.ownership.values.map((v) => v.record.scheduleId).toSet(),
        others,
      );
      expect(journal.ownership.values.every((v) => !v.pending), isTrue);
      expect(f.registry.records.every((v) => !v.cancellationPending), isTrue);
    },
  );

  for (final boundary in ['runtime', 'provider']) {
    test(
      'same generation same ID recreation during $boundary wait revokes later cleanup authority',
      () async {
        final entered = Completer<void>(), release = Completer<void>();
        if (boundary == 'runtime') {
          f.timed.onClear = (_) async {
            entered.complete();
            await release.future;
          };
        } else {
          f.fallback.onCancel = (_) async {
            entered.complete();
            await release.future;
          };
        }
        final intent = await f.deletion.prepare('one');
        final deleting = f.deletion.confirm(intent);
        final rejected = expectLater(
          deleting,
          throwsA(isA<AlarmOperationInvalidated>()),
        );
        final drained = rejected.then<void>(
          (_) {},
          onError: (Object _, StackTrace __) {},
        );
        try {
          await Future.any<void>([
            entered.future,
            deleting.then<void>(
              (_) => throw StateError(
                'Deletion completed before $boundary barrier',
              ),
            ),
          ]);
          await f.create();
          await f.early.markStarted(
            scheduleId: 'one',
            startedAt: DateTime.utc(2029),
          );
          final writes = f.registry.writes;
          final journalBefore = await File(
            '${directory.path}/ownership-v1.json',
          ).readAsString();
          release.complete();
          await rejected;
          expect(await f.db.select(f.db.schedules).get(), hasLength(1));
          expect(f.early.values, contains('one'));
          expect(f.registry.writes, writes);
          expect(
            await File('${directory.path}/ownership-v1.json').readAsString(),
            journalBefore,
          );
          if (boundary == 'runtime') expect(f.fallback.cancelled, isEmpty);
        } finally {
          if (!release.isCompleted) release.complete();
          await drained;
        }
      },
    );
  }

  test(
    'held same-intent receipt retries cleanup without another DB revision',
    () async {
      final intent = await f.deletion.prepare('one');
      final first = await f.deletion.confirm(intent);
      final revision = await f.revision();
      final second = await f.deletion.confirm(intent);
      expect(identical(first.commit, second.commit), isTrue);
      expect(await f.revision(), revision);
      expect(f.fallback.cancelled, hasLength(1));
    },
  );

  test(
    'unknown ownership remains unconfirmed despite known provider cancellation',
    () async {
      await f.owner.journal.save(AlarmJournalSnapshot(unknownOwnership: true));
      final result = await f.deletion.confirm(await f.deletion.prepare('one'));
      expect(result.cleanup, ScheduleDeletionCleanup.unconfirmed);
      expect(result.commit.changed, isTrue);
      expect((await f.owner.journal.read()).unknownOwnership, isTrue);
    },
  );

  test(
    'generation replacement after prepare rejects without persisting ownership',
    () async {
      final intent = await f.deletion.prepare('one');
      await f.gate.run(() async {}, replacesData: true);
      await expectLater(
        f.deletion.confirm(intent),
        throwsA(isA<ScheduleDeletionRejected>()),
      );
      expect(await f.db.select(f.db.schedules).get(), hasLength(1));
      expect(await directory.list().toList(), isEmpty);
    },
  );

  for (final recurring in [false, true]) {
    test(
      'valid durable early preparation blocks deletion with recurring=$recurring and isStarted=false',
      () async {
        var id = 'one';
        if (recurring) {
          final start = DateTime.utc(2030, 1, 2, 10);
          await f.recurring.create(
            f.schedule('series').copyWith(scheduleTime: start),
            const PreparationEntity(
              preparationStepList: [
                PreparationStepEntity(
                  id: 'series-step',
                  preparationName: 'Prepare',
                  preparationTime: Duration(minutes: 1),
                ),
              ],
            ),
            RecurrenceRule(
              frequency: RecurrenceFrequency.daily,
              start: start,
              timeZoneId: 'UTC',
              count: 2,
            ),
          );
          id = (await f.db.select(f.db.schedules).get())
              .firstWhere((row) => row.recurringSegmentId != null)
              .id;
        }
        final beforeRows = await f.db.select(f.db.schedules).get();
        final beforeRevision = await f.revision();
        final snapshot = await f.aggregate.readForEdit(id);
        final preparation = PreparationWithTimeEntity.fromPreparation(
          snapshot.preparation,
        );
        final value =
            ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
              snapshot.schedule,
              preparation,
              timeResolution: ScheduleTimeResolver.resolve(
                snapshot.schedule,
                nowUtc: f.now,
              ),
            );
        f.timed.snapshots[id] = TimedPreparationSnapshotEntity(
          preparation: preparation,
          savedAt: f.now,
          scheduleFingerprint: value.cacheFingerprint,
          startedAt: f.now,
        );
        await expectLater(
          f.deletion.prepare(id),
          throwsA(
            isA<ScheduleDeletionRejected>().having(
              (e) => e.failure,
              'failure',
              ScheduleDeletionFailure.protected,
            ),
          ),
        );
        expect(await f.db.select(f.db.schedules).get(), beforeRows);
        expect(await f.revision(), beforeRevision);
        expect(f.fallback.cancelled, isEmpty);
        expect(f.scheduler.cancelled, isEmpty);
        expect(f.timed.snapshots, contains(id));
        expect(await directory.list().toList(), isEmpty);
      },
    );
  }

  test(
    'native cancellation failure retains deletion and retries only old ownership',
    () async {
      f.registry.records = [
        ScheduledAlarmRecord(
          scheduleId: 'one',
          provider: AlarmProvider.androidAlarmManager,
          nativeAlarmId: 73,
          alarmTime: DateTime.utc(2030),
          preparationStartTime: DateTime.utc(2030),
          scheduleFingerprint: 'private native fingerprint',
          scheduleTitle: 'private native title',
          payload: const {'note': 'private native payload'},
        ),
      ];
      f.scheduler.onCancel = (_) async {
        throw StateError('native unavailable');
      };
      final result = await f.deletion.confirm(await f.deletion.prepare('one'));
      expect(result.cleanup, ScheduleDeletionCleanup.pending);
      expect(await f.db.select(f.db.schedules).get(), isEmpty);
      final revision = await f.revision();
      final ownership = (await f.owner.journal.read()).ownership.values.single;
      expect(ownership.pending, isTrue);
      expect(ownership.record.nativeAlarmId, 73);
      expect(
        await File('${directory.path}/ownership-v1.json').readAsString(),
        isNot(contains('private')),
      );
      f.scheduler.onCancel = null;
      final retried = await f.deletion.retryCleanup(result.commit);
      expect(retried.cleanup, ScheduleDeletionCleanup.complete);
      expect(await f.revision(), revision);
      expect(await f.db.select(f.db.schedules).get(), isEmpty);
      expect(f.scheduler.cancelled.map((record) => record.nativeAlarmId), [
        73,
        73,
      ]);
      expect(f.fallback.cancelled, isEmpty);
      expect((await f.owner.journal.read()).ownership, isEmpty);
    },
  );

  test(
    'started row and orphan early state are blocked without mutation',
    () async {
      await (f.db.update(f.db.schedules)..where((v) => v.id.equals('one')))
          .write(const SchedulesCompanion(isStarted: Value(true)));
      await expectLater(
        f.deletion.prepare('one'),
        throwsA(
          isA<ScheduleDeletionRejected>().having(
            (e) => e.failure,
            'failure',
            ScheduleDeletionFailure.protected,
          ),
        ),
      );
      await (f.db.update(f.db.schedules)..where((v) => v.id.equals('one')))
          .write(const SchedulesCompanion(isStarted: Value(false)));
      await f.early.markStarted(
        scheduleId: 'one',
        startedAt: DateTime.utc(2029),
      );
      await expectLater(
        f.deletion.prepare('one'),
        throwsA(
          isA<ScheduleDeletionRejected>().having(
            (e) => e.failure,
            'failure',
            ScheduleDeletionFailure.unavailable,
          ),
        ),
      );
      expect(await f.db.select(f.db.schedules).get(), hasLength(1));
      expect(await directory.list().toList(), isEmpty);
    },
  );
}
