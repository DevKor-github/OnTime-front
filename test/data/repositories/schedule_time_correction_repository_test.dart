import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/time/time_zone_rules.dart';
import 'package:on_time_front/data/repositories/recurring_schedule_repository_impl.dart';
import 'package:on_time_front/data/repositories/schedule_aggregate_repository_impl.dart';
import 'package:on_time_front/data/repositories/schedule_time_correction_repository_impl.dart';
import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_preparation_mode.dart';
import 'package:on_time_front/domain/entities/schedule_save.dart';
import 'package:on_time_front/domain/entities/schedule_time_correction.dart';
import 'package:on_time_front/domain/entities/schedule_time_resolution.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/use-cases/schedule_form_submission.dart';
import 'package:timezone/timezone.dart' as tz;

const _zone = 'Test/A10_Correction_Owned';

void main() {
  late Directory directory;
  late AppDatabase db;
  late LocalDataOperationGate gate;
  late ScheduleAggregateRepositoryImpl aggregates;
  late ScheduleTimeCorrectionRepositoryImpl repository;
  late DateTime now;
  late Map<String, tz.Location> originalRules;
  late tz.Location originalLocal;

  void rules(int seconds) {
    tz.timeZoneDatabase.locations[_zone] = tz.Location(
      _zone,
      <int>[],
      <int>[],
      [tz.TimeZone(seconds * 1000, isDst: false, abbreviation: 'QA')],
    );
  }

  Future<void> open() async {
    db = AppDatabase.forTesting(
      NativeDatabase(File('${directory.path}/app.sqlite')),
    );
    aggregates = ScheduleAggregateRepositoryImpl(
      db,
      RecurringScheduleRepositoryImpl(db, now: () => now),
      gate: gate,
      now: () => now,
    );
    repository = ScheduleTimeCorrectionRepositoryImpl(
      db,
      aggregates,
      gate: gate,
      now: () => now,
    );
  }

  setUp(() async {
    TimeZoneRules.ensureInitialized();
    originalRules = Map.of(tz.timeZoneDatabase.locations);
    originalLocal = tz.local;
    rules(0);
    now = DateTime.utc(2030, 1, 1, 8);
    gate = LocalDataOperationGate();
    directory = await Directory.systemTemp.createTemp('ontime-a10-correction-');
    await open();
    await db.userDao.putUser(
      const UserEntity(
        id: 'local-profile',
        spareTime: Duration.zero,
        note: 'Retain profile data',
        isOnboardingCompleted: true,
      ),
    );
  });

  tearDown(() async {
    await db.close();
    gate.dispose();
    await directory.delete(recursive: true);
    tz.timeZoneDatabase.locations
      ..clear()
      ..addAll(originalRules);
    tz.setLocalLocation(originalLocal);
  });

  Future<void> seed({DateTime? civil}) async {
    await aggregates.save(
      ScheduleFormSubmission(
        schedule: ScheduleEntity(
          id: 'appointment',
          place: const PlaceEntity(id: 'office', placeName: 'Original office'),
          scheduleName: 'Original appointment',
          scheduleTime: civil ?? DateTime.utc(2030, 1, 1, 10, 0, 3, 123, 456),
          timeZoneId: _zone,
          occurrenceOffsetSeconds: 0,
          moveTime: const Duration(minutes: 15),
          scheduleSpareTime: const Duration(minutes: 5),
          scheduleNote: 'Do not replace this note',
          isChanged: true,
          isStarted: false,
          preparationMode: SchedulePreparationMode.custom,
        ),
        preparation: const PreparationEntity(
          preparationStepList: [
            PreparationStepEntity(
              id: 'original-step',
              preparationName: 'Prepare',
              preparationTime: Duration(minutes: 10),
            ),
          ],
        ),
        preparationChanged: true,
        baseline: await aggregates.newBaseline(),
        mutationId: 'create-original',
      ),
      editing: false,
    );
    rules(3600);
  }

  Future<Map<String, Object?>> row() async =>
      (await db.customSelect('SELECT * FROM schedules').getSingle()).data;
  Future<Map<String, Object?>> profile() async =>
      (await db.customSelect('SELECT * FROM users').getSingle()).data;

  // Read all persistent user tables, including authority and receipt columns.
  Future<Map<String, List<String>>> databaseContents() async {
    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
        )
        .get();
    final result = <String, List<String>>{};
    for (final table in tables) {
      final name = table.read<String>('name');
      final rows = await db.customSelect('SELECT * FROM "$name"').get();
      result[name] = rows.map((r) => jsonEncode(r.data)).toList()..sort();
    }
    return result;
  }

  ScheduleTimeCorrectionCommand command(
    ScheduleTimeCorrectionReview review, {
    DateTime? civil,
    String zone = _zone,
    int offset = 3600,
    String mutation = 'correct-time',
  }) => ScheduleTimeCorrectionCommand(
    review: review,
    civil: CivilDateTime.fromFields(
      civil ?? review.snapshot.schedule.scheduleTime,
    ),
    timeZoneId: zone,
    offsetSeconds: offset,
    mutationId: mutation,
  );

  final rejected = throwsA(isA<ScheduleSaveRejected>());
  final conflict = throwsA(
    isA<ScheduleSaveRejected>().having(
      (error) => error.failure,
      'failure',
      ScheduleSaveFailure.conflict,
    ),
  );

  test(
    'review is read-only and correction changes only time and one atomic receipt',
    () async {
      now = DateTime.utc(2030, 1, 1, 7);
      await seed(civil: DateTime.utc(2030, 1, 1, 8, 20, 3, 123, 456));
      now = DateTime.utc(2030, 1, 1, 8);
      final before = await row();
      final beforeProfile = await profile();
      final contents = await databaseContents();
      final review = await repository.review('appointment');
      expect(review.resolution.status, ScheduleTimeResolutionStatus.changed);
      expect(
        review.snapshot.preparation.totalDuration,
        const Duration(minutes: 10),
      );
      expect(await databaseContents(), contents);
      // Ordinary editing stays protected because its old preparation start passed.
      await expectLater(
        aggregates.save(
          ScheduleFormSubmission(
            schedule: review.snapshot.schedule.copyWith(
              scheduleName: 'Forbidden rename',
            ),
            preparation: review.snapshot.preparation,
            preparationChanged: false,
            originalSchedule: review.snapshot.schedule,
            baseline: review.snapshot.baseline,
            mutationId: 'ordinary-edit',
          ),
          editing: true,
        ),
        rejected,
      );
      expect(await databaseContents(), contents);

      final target = DateTime.utc(2030, 1, 1, 11, 0, 3, 123, 456);
      final receipt = await repository.confirm(command(review, civil: target));
      expect(receipt.scheduleId, 'appointment');
      expect(receipt.changed, isTrue);
      expect(repository.isCurrent(receipt), isTrue);
      final after = await row();
      final snapshot = await aggregates.readForEdit('appointment');
      expect(snapshot.schedule.scheduleTime, target);
      expect(snapshot.schedule.occurrenceOffsetSeconds, 3600);
      expect(
        snapshot.schedule.occurrenceInstantUtc,
        DateTime.utc(2030, 1, 1, 10, 0, 3, 123, 456),
      );
      expect(snapshot.preparation, review.snapshot.preparation);
      final allowed = {
        'schedule_time',
        'time_zone_id',
        'occurrence_offset_seconds',
        'is_changed',
        'aggregate_version',
        'last_mutation_id',
        'last_mutation_digest',
        'last_mutation_version',
      };
      for (final key in before.keys.where((key) => !allowed.contains(key))) {
        expect(
          after[key],
          before[key],
          reason: 'Non-time field $key must survive',
        );
      }
      expect(
        after['aggregate_version'],
        (before['aggregate_version'] as int) + 1,
      );
      expect(after['last_mutation_id'], 'correct-time');
      expect(after['last_mutation_version'], after['aggregate_version']);
      expect(
        (await profile())['data_revision'],
        (beforeProfile['data_revision'] as int) + 1,
      );
      final afterContents = await databaseContents();
      for (final table in contents.keys.where(
        (t) => t != 'schedules' && t != 'users',
      )) {
        expect(
          afterContents[table],
          contents[table],
          reason: '$table is not a time correction target',
        );
      }
    },
  );

  test(
    'a revision write fault rolls back all tables and the same command can retry',
    () async {
      await seed();
      final intent = command(await repository.review('appointment'));
      final before = await databaseContents();
      await db.customStatement(
        "CREATE TRIGGER reject_correction_revision BEFORE UPDATE OF data_revision ON users BEGIN SELECT RAISE(ABORT, 'a10 correction revision failure'); END",
      );
      await expectLater(
        repository.confirm(intent),
        throwsA(
          predicate<Object>(
            (error) =>
                error.toString().contains('a10 correction revision failure'),
          ),
        ),
      );
      expect(await databaseContents(), before);
      await db.customStatement('DROP TRIGGER reject_correction_revision');
      expect((await repository.confirm(intent)).changed, isTrue);
      final committed = await databaseContents();
      expect((await repository.confirm(intent)).changed, isFalse);
      expect(await databaseContents(), committed);
    },
  );

  test(
    'concurrent and reopened retries preserve one version and original receipt',
    () async {
      await seed();
      final before = await row();
      final beforeProfile = await profile();
      final intent = command(await repository.review('appointment'));
      final receipts = await Future.wait([
        repository.confirm(intent),
        repository.confirm(intent),
      ]);
      expect(receipts.where((value) => value.changed), hasLength(1));
      expect(
        (await row())['aggregate_version'],
        (before['aggregate_version'] as int) + 1,
      );
      expect(
        (await profile())['data_revision'],
        (beforeProfile['data_revision'] as int) + 1,
      );
      final committed = await databaseContents();
      await db.close();
      await open();
      now = DateTime.utc(
        2031,
      ); // An exact committed retry cannot create another run or rewrite history.
      expect((await repository.confirm(intent)).changed, isFalse);
      expect(await databaseContents(), committed);
    },
  );

  test(
    'one mutation cannot authorize a different payload or ordinary edit',
    () async {
      await seed();
      final review = await repository.review('appointment');
      final intent = command(review);
      await repository.confirm(intent);
      final before = await databaseContents();
      await expectLater(
        repository.confirm(
          command(review, civil: DateTime.utc(2030, 1, 1, 12)),
        ),
        conflict,
      );
      final current = await aggregates.readForEdit('appointment');
      await expectLater(
        aggregates.save(
          ScheduleFormSubmission(
            schedule: current.schedule.copyWith(
              scheduleName: 'Different operation',
            ),
            preparation: current.preparation,
            preparationChanged: false,
            originalSchedule: current.schedule,
            baseline: current.baseline,
            mutationId: intent.mutationId,
          ),
          editing: true,
        ),
        conflict,
      );
      expect(await databaseContents(), before);
    },
  );

  for (final race in [
    'version',
    'incarnation',
    'store',
    'generation',
    'material',
    'rules',
    'clock rewind',
    'preparation deadline',
    'occurrence deadline',
  ]) {
    test(
      '$race invalidates review without overwriting concurrent data',
      () async {
        await seed(civil: DateTime.utc(2030, 1, 1, 10));
        final intent = command(await repository.review('appointment'));
        switch (race) {
          case 'version':
            await db.customStatement(
              'UPDATE schedules SET aggregate_version=aggregate_version+1',
            );
          case 'incarnation':
            await db.customStatement(
              "UPDATE schedules SET aggregate_incarnation='replacement-incarnation'",
            );
          case 'store':
            await db.customStatement(
              "UPDATE users SET store_incarnation='replacement-store'",
            );
          case 'generation':
            await gate.run(() async {}, replacesData: true);
          case 'material':
            await db.transaction(() async {
              await db.preparationScheduleDao.createPreparationSchedule(
                const PreparationEntity(
                  preparationStepList: [
                    PreparationStepEntity(
                      id: 'new-step',
                      preparationName: 'Longer preparation',
                      preparationTime: Duration(minutes: 90),
                    ),
                  ],
                ),
                'appointment',
              );
              await db.userDao.markDurableDataChanged('local-profile');
            });
          case 'rules':
            rules(7200);
          case 'clock rewind':
            now = now.subtract(const Duration(microseconds: 1));
          case 'preparation deadline':
            now = DateTime.utc(2030, 1, 1, 8, 30);
          case 'occurrence deadline':
            now = DateTime.utc(2030, 1, 1, 9);
        }
        final current = await databaseContents();
        await expectLater(repository.confirm(intent), rejected);
        expect(await databaseContents(), current);
      },
    );
  }

  for (final invalid in [
    'unknown zone',
    'wrong offset',
    'gap',
    'past target',
    'blank mutation',
  ]) {
    test('$invalid is refused without replacing the reviewed row', () async {
      await seed();
      final review = await repository.review('appointment');
      final intent = switch (invalid) {
        'unknown zone' => command(review, zone: 'Missing/Zone'),
        'wrong offset' => command(review, offset: 7200),
        'gap' => command(
          review,
          civil: DateTime.utc(2030, 3, 10, 2, 30),
          zone: 'America/New_York',
          offset: -18000,
        ),
        'past target' => command(
          review,
          civil: DateTime.utc(2029),
          zone: 'UTC',
          offset: 0,
        ),
        _ => command(review, mutation: ''),
      };
      final before = await databaseContents();
      await expectLater(repository.confirm(intent), rejected);
      expect(await databaseContents(), before);
    });
  }

  test(
    'a diagnostic review cannot forge correction authority for a resolved row',
    () async {
      await seed();
      rules(0);
      final review = await repository.review('appointment');
      expect(review.resolution.status, ScheduleTimeResolutionStatus.resolved);
      final forged = ScheduleTimeCorrectionReview(
        snapshot: review.snapshot,
        resolution: ScheduleTimeResolution(
          status: ScheduleTimeResolutionStatus.changed,
        ),
        ruleIdentity: review.ruleIdentity,
        validationNowUtc: review.validationNowUtc,
      );
      final before = await databaseContents();
      await expectLater(
        repository.confirm(command(forged, zone: 'UTC', offset: 0)),
        rejected,
      );
      expect(await databaseContents(), before);
    },
  );

  for (final gateState in ['recovery', 'invalidated']) {
    test(
      '$gateState blocks a previously valid command without changing data',
      () async {
        await seed();
        final intent = command(await repository.review('appointment'));
        if (gateState == 'recovery') {
          gate.setRecoveryPending(true);
        } else {
          gate.invalidate();
        }
        final before = await databaseContents();
        await expectLater(repository.confirm(intent), rejected);
        expect(await databaseContents(), before);
      },
    );
  }

  for (final problem in ['unknown', 'gap', 'overlap']) {
    test(
      '$problem requires an explicit valid occurrence and then saves that exact choice',
      () async {
        now = DateTime.utc(2026, 1, 1);
        await seed();
        // Representative admitted legacy active rows. These raw fixtures are not
        // claimed to be produced by the normal new-schedule form.
        final oldCivil = problem == 'gap'
            ? DateTime.utc(2026, 3, 8, 2, 30)
            : problem == 'overlap'
            ? DateTime.utc(2026, 11, 1, 1, 30)
            : DateTime.utc(2030, 1, 1, 10);
        final oldZone = problem == 'unknown'
            ? 'Missing/Zone'
            : 'America/New_York';
        await db.customStatement(
          'UPDATE schedules SET schedule_time=?, time_zone_id=?, occurrence_offset_seconds=NULL',
          [CivilDateTime.fromFields(oldCivil).toCivilIso8601String(), oldZone],
        );
        final review = await repository.review('appointment');
        expect(review.resolution.status, switch (problem) {
          'unknown' => ScheduleTimeResolutionStatus.unknownZone,
          'gap' => ScheduleTimeResolutionStatus.nonexistent,
          _ => ScheduleTimeResolutionStatus.ambiguous,
        });
        expect(review.blockedBy, isNull);
        final target = problem == 'gap'
            ? DateTime.utc(2026, 3, 8, 3, 30)
            : oldCivil;
        final offset = problem == 'unknown'
            ? 0
            : problem == 'gap'
            ? -14400
            : -18000;
        await repository.confirm(
          command(
            review,
            civil: target,
            zone: problem == 'unknown' ? 'UTC' : 'America/New_York',
            offset: offset,
          ),
        );
        final saved = (await aggregates.readForEdit('appointment')).schedule;
        expect(saved.scheduleTime, target);
        expect(saved.occurrenceOffsetSeconds, offset);
        expect(saved.occurrenceInstantUtc, switch (problem) {
          'unknown' => DateTime.utc(2030, 1, 1, 10),
          'gap' => DateTime.utc(2026, 3, 8, 7, 30),
          _ => DateTime.utc(2026, 11, 1, 6, 30),
        });
        expect(saved.isStarted, isFalse);
        expect(saved.startedAt, isNull);
      },
    );
  }

  for (final facts in [
    'frozen',
    'started',
    'completed',
    'scored',
    'past explicit',
    'past null',
  ]) {
    test(
      '$facts remains protected even if the review claims a repairable time',
      () async {
        await seed();
        // Defensive persisted facts, including independently protected legacy
        // markers; no claim that an incomplete marker set is a valid backup.
        switch (facts) {
          case 'frozen':
            await db.customStatement(
              'UPDATE schedules SET preparation_frozen=1',
            );
          case 'started':
            await db.customStatement(
              'UPDATE schedules SET is_started=1, preparation_frozen=1, started_at=?',
              [now.millisecondsSinceEpoch ~/ 1000],
            );
          case 'completed':
            await db.customStatement(
              "UPDATE schedules SET done_status='normalEnd', finished_at=?",
              [now.millisecondsSinceEpoch ~/ 1000],
            );
          case 'scored':
            await db.customStatement(
              'UPDATE schedules SET score_contribution_recorded=1',
            );
          case 'past explicit':
            now = DateTime.utc(2031);
          case 'past null':
            await db.customStatement(
              'UPDATE schedules SET occurrence_offset_seconds=NULL',
            );
            now = DateTime.utc(2031);
        }
        final review = await repository.review('appointment');
        expect(review.blockedBy, ScheduleSaveFailure.protected);
        final forged = ScheduleTimeCorrectionReview(
          snapshot: review.snapshot,
          resolution: ScheduleTimeResolution(
            status: ScheduleTimeResolutionStatus.changed,
          ),
          ruleIdentity: review.ruleIdentity,
          validationNowUtc: review.validationNowUtc,
        );
        final before = await databaseContents();
        await expectLater(
          repository.confirm(
            command(forged, civil: DateTime.utc(2032), zone: 'UTC', offset: 0),
          ),
          rejected,
        );
        expect(await databaseContents(), before);
      },
    );
  }

  test(
    'a committed receipt loses authority on recovery or data replacement',
    () async {
      await seed();
      final receipt = await repository.confirm(
        command(await repository.review('appointment')),
      );
      expect(repository.isCurrent(receipt), isTrue);
      gate.setRecoveryPending(true);
      expect(repository.isCurrent(receipt), isFalse);
      gate.setRecoveryPending(false);
      expect(repository.isCurrent(receipt), isTrue);
      await gate.run(() async {}, replacesData: true);
      expect(repository.isCurrent(receipt), isFalse);
    },
  );
}
