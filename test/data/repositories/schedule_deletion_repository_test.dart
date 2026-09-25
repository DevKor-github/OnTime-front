import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/data/repositories/recurring_schedule_repository_impl.dart';
import 'package:on_time_front/data/repositories/schedule_aggregate_repository_impl.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_deletion.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';

void main() {
  late AppDatabase db;
  late LocalDataOperationGate gate;
  late RecurringScheduleRepositoryImpl recurring;
  late ScheduleAggregateRepositoryImpl aggregate;
  final now = DateTime.utc(2029);
  final start = DateTime.utc(2030, 1, 1, 10);
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    gate = LocalDataOperationGate();
    recurring = RecurringScheduleRepositoryImpl(db, now: () => now);
    aggregate = ScheduleAggregateRepositoryImpl(
      db,
      recurring,
      gate: gate,
      now: () => now,
    );
    await db.userDao.putUser(
      const UserEntity(id: 'local-profile', spareTime: Duration.zero, note: ''),
    );
  });
  tearDown(() async {
    await db.close();
    gate.dispose();
  });
  Future<int> revision() async =>
      (await db.select(db.users).getSingle()).dataRevision;
  Future<void> create([String id = 'one']) async {
    await db.scheduleDao.createSchedule(
      _schedule(id, start).toScheduleWithPlaceRow(),
    );
    await db.preparationScheduleDao.createPreparationSchedule(_prep(id), id);
  }

  Matcher rejected(ScheduleDeletionFailure failure) => throwsA(
    isA<ScheduleDeletionRejected>().having(
      (e) => e.failure,
      'failure',
      failure,
    ),
  );

  test(
    'confirmed intent commits once then reports current absence without another revision',
    () async {
      await create();
      final intent = await aggregate.readForDeletion('one');
      final before = await revision();
      final first = await aggregate.delete(intent);
      final repeated = await aggregate.delete(intent);
      expect(first.changed, isTrue);
      expect(first.alreadyAbsent, isFalse);
      expect(first.removedIds, {'one'});
      expect(repeated.changed, isFalse);
      expect(repeated.alreadyAbsent, isTrue);
      expect(repeated.removedIds, isEmpty);
      expect(await revision(), before + 1);
      expect(await aggregate.isDeletionCurrent(first), isTrue);
    },
  );

  test(
    'unrelated profile revision and schedule edit do not invalidate selected intent',
    () async {
      await create();
      await create('other');
      final intent = await aggregate.readForDeletion('one');
      await db.userDao.updateSpareTime(
        'local-profile',
        const Duration(minutes: 7),
      );
      await (db.update(db.schedules)..where((t) => t.id.equals('other'))).write(
        const SchedulesCompanion(scheduleName: Value('other edit')),
      );
      final before = await revision();
      expect((await aggregate.delete(intent)).changed, isTrue);
      expect(await revision(), before + 1);
      expect(
        (await db.scheduleDao.getScheduleById('other')).schedule.scheduleName,
        'other edit',
      );
    },
  );

  for (final mutation in ['edit', 'start', 'finish', 'ABA', 'step']) {
    test(
      '$mutation after confirmation rejects stale target and preserves current row',
      () async {
        await create();
        final intent = await aggregate.readForDeletion('one');
        final table = db.update(db.schedules)..where((t) => t.id.equals('one'));
        switch (mutation) {
          case 'edit':
            await table.write(
              const SchedulesCompanion(scheduleName: Value('edited')),
            );
          case 'start':
            await table.write(const SchedulesCompanion(isStarted: Value(true)));
          case 'finish':
            await table.write(
              const SchedulesCompanion(doneStatus: Value('normalEnd')),
            );
          case 'ABA':
            await table.write(
              const SchedulesCompanion(scheduleName: Value('changed')),
            );
            await table.write(
              const SchedulesCompanion(scheduleName: Value('one')),
            );
          case 'step':
            await (db.update(
              db.preparationSchedules,
            )..where((t) => t.scheduleId.equals('one'))).write(
              const PreparationSchedulesCompanion(
                preparationName: Value('edited step'),
              ),
            );
        }
        final before = await revision();
        await expectLater(
          aggregate.delete(intent),
          rejected(ScheduleDeletionFailure.conflict),
        );
        expect((await db.select(db.schedules).get()).length, 1);
        expect(await revision(), before);
      },
    );
  }

  test(
    'same ID recreation has a different incarnation and cannot consume old intent or retry receipt',
    () async {
      await create();
      final intent = await aggregate.readForDeletion('one');
      final receipt = await aggregate.delete(intent);
      await create();
      final recreated = await aggregate.readForDeletion('one');
      expect(
        recreated.snapshot.baseline.incarnation,
        isNot(intent.snapshot.baseline.incarnation),
      );
      await expectLater(
        aggregate.delete(intent),
        rejected(ScheduleDeletionFailure.conflict),
      );
      expect(await aggregate.isDeletionCurrent(receipt), isFalse);
    },
  );

  test(
    'replacement generation rejects an old intent before any deletion',
    () async {
      await create();
      final intent = await aggregate.readForDeletion('one');
      await gate.run(() async {}, replacesData: true);
      final before = await revision();
      await expectLater(
        aggregate.delete(intent),
        rejected(ScheduleDeletionFailure.conflict),
      );
      expect((await db.select(db.schedules).get()).length, 1);
      expect(await revision(), before);
    },
  );

  test(
    'different store identity rejects intent even with unchanged generation',
    () async {
      await create();
      final intent = await aggregate.readForDeletion('one');
      await (db.update(db.users)).write(
        const UsersCompanion(storeIncarnation: Value('new-installation')),
      );
      await expectLater(
        aggregate.delete(intent),
        rejected(ScheduleDeletionFailure.conflict),
      );
      expect((await db.select(db.schedules).get()).length, 1);
    },
  );

  for (final fault in ['step', 'schedule', 'place', 'revision']) {
    test(
      '$fault failure rolls back deletion and original intent can retry',
      () async {
        await create();
        final intent = await aggregate.readForDeletion('one');
        final before = await revision();
        final event = {
          'step': 'DELETE ON preparation_schedules',
          'schedule': 'DELETE ON schedules',
          'place': 'DELETE ON places',
          'revision': 'UPDATE OF data_revision ON users',
        }[fault];
        await db.customStatement(
          "CREATE TRIGGER reject_delete BEFORE $event BEGIN SELECT RAISE(ABORT, 'injected'); END",
        );
        await expectLater(aggregate.delete(intent), throwsA(anything));
        expect((await db.select(db.schedules).get()).length, 1);
        expect((await db.select(db.preparationSchedules).get()).length, 2);
        expect((await db.select(db.places).get()).length, 1);
        expect(await revision(), before);
        expect(
          (await aggregate.readForDeletion('one')).snapshot.baseline.version,
          intent.snapshot.baseline.version,
        );
        await db.customStatement('DROP TRIGGER reject_delete');
        expect((await aggregate.delete(intent)).changed, isTrue);
        expect(await revision(), before + 1);
      },
    );
  }

  for (final fault in ['unlink', 'exclusion', 'revision-after-exclusion']) {
    test(
      '$fault restores the complete affected SQLite graph after rollback',
      () async {
        var id = 'one';
        if (fault == 'unlink') {
          await create();
        } else {
          await recurring.create(
            _schedule('series', start),
            _prep('shared'),
            RecurrenceRule(
              frequency: RecurrenceFrequency.daily,
              start: start,
              timeZoneId: 'UTC',
              count: 3,
            ),
          );
          final original = (await db.scheduleDao.getScheduleList()).first
              .toScheduleEntity();
          await recurring.updateOccurrence(
            original,
            original.copyWith(scheduleName: 'Private override'),
            _prep('private'),
            preparationChanged: true,
          );
          id = original.id;
          await db.preparationScheduleDao.createPreparationSchedule(
            _prep('linked'),
            id,
          );
        }
        // Nonzero prior contributions need not have retained detail rows.
        await db
            .update(db.users)
            .write(
              const UsersCompanion(
                eligibleOutcomeCount: Value(3),
                onTimeOutcomeCount: Value(2),
              ),
            );
        final intent = await aggregate.readForDeletion(id);
        final before = await _deletionGraph(db);
        final beforeRevision = await revision();
        final trigger = switch (fault) {
          'unlink' =>
            'BEFORE UPDATE OF next_preparation_id ON preparation_schedules',
          'exclusion' => 'BEFORE INSERT ON recurring_schedule_exclusions',
          _ =>
            'BEFORE UPDATE OF data_revision ON users WHEN EXISTS (SELECT 1 FROM recurring_schedule_exclusions)',
        };
        await db.customStatement(
          "CREATE TRIGGER reject_delete_graph $trigger BEGIN SELECT RAISE(ABORT, 'injected graph rollback'); END",
        );
        await expectLater(aggregate.delete(intent), throwsA(anything));
        expect(await _deletionGraph(db), before);
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        expect(await revision(), beforeRevision);
        await db.customStatement('DROP TRIGGER reject_delete_graph');
        final retried = await aggregate.delete(intent);
        expect(retried.changed, isTrue);
        expect(await revision(), beforeRevision + 1);
        expect((await db.select(db.users).getSingle()).eligibleOutcomeCount, 3);
        expect((await db.select(db.users).getSingle()).onTimeOutcomeCount, 2);
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      },
    );
  }

  test(
    'file database reopen and materialization preserve the deleted slot and original count',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'u01-recurring-reopen-',
      );
      final file = File('${directory.path}/recurrence.sqlite');
      var disk = AppDatabase.forTesting(NativeDatabase(file));
      var opened = true;
      final diskGate = LocalDataOperationGate();
      try {
        await disk.userDao.putUser(
          const UserEntity(
            id: 'local-profile',
            spareTime: Duration.zero,
            note: '',
          ),
        );
        final writer = RecurringScheduleRepositoryImpl(disk, now: () => now);
        final aggregateWriter = ScheduleAggregateRepositoryImpl(
          disk,
          writer,
          gate: diskGate,
          now: () => now,
        );
        await writer.create(
          _schedule('persisted-series', start),
          _prep('persisted'),
          RecurrenceRule(
            frequency: RecurrenceFrequency.daily,
            start: start,
            timeZoneId: 'UTC',
            count: 5,
          ),
        );
        final initial =
            (await disk.scheduleDao.getScheduleList())
                .map((v) => v.toScheduleEntity())
                .toList()
              ..sort(
                (a, b) => a.recurringOrdinal!.compareTo(b.recurringOrdinal!),
              );
        expect(initial, hasLength(5));
        final target = initial[2];
        final remaining = initial.where((v) => v.id != target.id).toList();
        await aggregateWriter.delete(
          await aggregateWriter.readForDeletion(target.id),
        );
        final committedRevision =
            (await disk.select(disk.users).getSingle()).dataRevision;
        final ruleBefore =
            (await disk.select(disk.recurringScheduleSegments).getSingle())
                .ruleJson;
        await disk.close();
        opened = false;
        disk = AppDatabase.forTesting(NativeDatabase(file));
        opened = true;
        final reopened = RecurringScheduleRepositoryImpl(disk, now: () => now);
        await reopened.materialize(start, DateTime.utc(2032));
        final rows = (await disk.scheduleDao.getScheduleList())
            .map((v) => v.toScheduleEntity())
            .toList();
        expect(
          rows.map((v) => v.id).toSet(),
          remaining.map((v) => v.id).toSet(),
        );
        expect(
          rows.map((v) => v.recurringOrdinal).toSet(),
          remaining.map((v) => v.recurringOrdinal).toSet(),
        );
        expect(
          rows.any((v) => v.recurringSlotKey == target.recurringSlotKey),
          isFalse,
        );
        expect(rows, hasLength(4));
        final exclusion = await disk
            .select(disk.recurringScheduleExclusions)
            .getSingle();
        expect(exclusion.segmentId, target.recurringSegmentId);
        expect(exclusion.slotKey, target.recurringSlotKey);
        expect(exclusion.ordinal, target.recurringOrdinal);
        expect(
          (await disk.select(disk.recurringScheduleSegments).getSingle())
              .ruleJson,
          ruleBefore,
        );
        expect(
          (await disk.select(disk.users).getSingle()).dataRevision,
          committedRevision,
        );
        expect(
          await disk.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        if (opened) {
          await disk.close();
        }
        diskGate.dispose();
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'completed recurring occurrence is deleted once and exclusion prevents materialization',
    () async {
      await recurring.create(
        _schedule('series', start),
        _prep('series'),
        RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          start: start,
          timeZoneId: 'UTC',
          count: 3,
        ),
      );
      final rows = await db.scheduleDao.getScheduleList();
      final id = rows[1].schedule.id;
      await (db.update(db.schedules)..where((t) => t.id.equals(id))).write(
        const SchedulesCompanion(
          doneStatus: Value('normalEnd'),
          preparationFrozen: Value(true),
        ),
      );
      final intent = await aggregate.readForDeletion(id);
      final before = await revision();
      await aggregate.delete(intent);
      expect(await revision(), before + 1);
      await recurring.materialize(start, DateTime.utc(2031));
      expect(
        (await db.select(db.schedules).get()).map((row) => row.id),
        isNot(contains(id)),
      );
      expect(
        await db.select(db.recurringScheduleExclusions).get(),
        hasLength(1),
      );
      await aggregate.delete(intent);
      expect(await revision(), before + 1);
    },
  );

  test(
    'following confirmation rejects new materialized targets instead of widening deletion',
    () async {
      await recurring.create(
        _schedule('series', start),
        _prep('series'),
        RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          start: start,
          timeZoneId: 'UTC',
          count: 65,
        ),
      );
      final row = (await db.scheduleDao.getScheduleList()).first;
      final intent = await aggregate.readForDeletion(
        row.schedule.id,
        scope: RecurringEditScope.following,
      );
      expect(intent.targets, hasLength(60));
      await recurring.materialize(start, DateTime.utc(2031));
      await expectLater(
        aggregate.delete(intent),
        rejected(ScheduleDeletionFailure.conflict),
      );
      expect(await db.select(db.schedules).get(), hasLength(65));
    },
  );
}

ScheduleEntity _schedule(String id, DateTime at) => ScheduleEntity(
  id: id,
  place: PlaceEntity(id: 'place-$id', placeName: 'Place'),
  scheduleName: id,
  scheduleTime: at,
  timeZoneId: 'UTC',
  occurrenceOffsetSeconds: 0,
  moveTime: Duration.zero,
  isChanged: true,
  isStarted: false,
  scheduleSpareTime: Duration.zero,
  scheduleNote: '',
);
PreparationEntity _prep(String id) => PreparationEntity(
  preparationStepList: [
    PreparationStepEntity(
      id: '$id-step-1',
      preparationName: 'First',
      preparationTime: const Duration(minutes: 1),
    ),
    PreparationStepEntity(
      id: '$id-step-2',
      preparationName: 'Second',
      preparationTime: const Duration(minutes: 1),
    ),
  ],
);

Future<Map<String, Object?>> _deletionGraph(AppDatabase db) async {
  final rows = <String, Object?>{};
  for (final table in [
    'users',
    'schedules',
    'preparation_schedules',
    'places',
    'preparation_definitions',
    'preparation_definition_steps',
    'recurring_schedule_segments',
    'recurring_schedule_exclusions',
  ]) {
    rows[table] =
        (await db.customSelect('SELECT * FROM $table ORDER BY rowid').get())
            .map((row) => row.data)
            .toList();
  }
  return rows;
}
