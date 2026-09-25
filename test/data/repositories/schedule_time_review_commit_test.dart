import 'dart:async';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/time/time_zone_rules.dart';
import 'package:on_time_front/data/repositories/recurring_schedule_repository_impl.dart';
import 'package:on_time_front/data/repositories/schedule_aggregate_repository_impl.dart';
import 'package:on_time_front/domain/entities/schedule_save.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/use-cases/schedule_form_submission.dart';
import 'package:timezone/timezone.dart' as tz;
import 'schedule_aggregate_repository_test.dart' show prep, schedule;

class _BeforeCommitReceipt extends QueryInterceptor {
  bool armed = false;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final result = await executor.runUpdate(statement, args);
    if (armed && statement.contains('last_mutation_id')) {
      armed = false;
      entered.complete();
      await release.future;
    }
    return result;
  }
}

void main() {
  for (final change in ['clock', 'rules', 'draft authority']) {
    test(
      'actual SQLite transaction rolls back when $change changes after receipt write',
      () async {
        final barrier = _BeforeCommitReceipt();
        final db = AppDatabase.forTesting(
          NativeDatabase.memory().interceptWith(barrier),
        );
        addTearDown(db.close);
        final gate = LocalDataOperationGate();
        var now = DateTime.utc(2029);
        var ownsDraft = true;
        final recurring = RecurringScheduleRepositoryImpl(db, now: () => now);
        final repository = ScheduleAggregateRepositoryImpl(
          db,
          recurring,
          gate: gate,
          now: () => now,
        );
        await db.userDao.putUser(
          const UserEntity(
            id: 'local-profile',
            spareTime: Duration.zero,
            note: '',
          ),
        );
        final baseline = await repository.newBaseline();
        final rules = TimeZoneRules.loadedIdentity;
        final reviewedAt = now;
        const syntheticZone = 'Test/U02_Commit_Barrier';
        addTearDown(() => tz.timeZoneDatabase.locations.remove(syntheticZone));
        final value = ScheduleFormSubmission(
          schedule: schedule(),
          preparation: prep(),
          preparationChanged: true,
          baseline: baseline,
          mutationId: 'reviewed-intent',
          validateTimeReview: () {
            if (!ownsDraft ||
                now != reviewedAt ||
                TimeZoneRules.loadedIdentity != rules) {
              throw const ScheduleSaveRejected(ScheduleSaveFailure.conflict);
            }
          },
        );
        barrier.armed = true;
        final saving = repository.save(value, editing: false);
        final failure = expectLater(
          saving,
          throwsA(isA<ScheduleSaveRejected>()),
        );
        await barrier.entered.future;
        if (change == 'clock') now = now.add(const Duration(days: 400));
        if (change == 'draft authority') ownsDraft = false;
        if (change == 'rules') {
          tz.timeZoneDatabase.locations[syntheticZone] = tz.Location(
            syntheticZone,
            [],
            [],
            [const tz.TimeZone(3600000, isDst: false, abbreviation: 'U02')],
          );
        }
        barrier.release.complete();
        await failure;
        expect(await db.select(db.schedules).get(), isEmpty);
        expect(await db.select(db.places).get(), isEmpty);
        expect(await db.select(db.preparationSchedules).get(), isEmpty);
        expect(
          (await db.select(db.users).getSingle()).dataRevision,
          baseline.revision,
        );
        tz.timeZoneDatabase.locations.remove(syntheticZone);
        now = reviewedAt;
        ownsDraft = true;
        await repository.save(value, editing: false);
        expect(await db.select(db.schedules).get(), hasLength(1));
        expect(
          (await db.select(db.users).getSingle()).dataRevision,
          baseline.revision + 1,
        );
      },
    );
  }

  test(
    'reviewed edit rejects profile revision changed after review; fresh review can save',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = ScheduleAggregateRepositoryImpl(
        db,
        RecurringScheduleRepositoryImpl(db, now: () => DateTime.utc(2029)),
        gate: LocalDataOperationGate(),
        now: () => DateTime.utc(2029),
      );
      await db.userDao.putUser(
        const UserEntity(
          id: 'local-profile',
          spareTime: Duration.zero,
          note: '',
        ),
      );
      await repository.save(
        ScheduleFormSubmission(
          schedule: schedule(),
          preparation: prep(),
          preparationChanged: true,
          baseline: await repository.newBaseline(),
          mutationId: 'create',
        ),
        editing: false,
      );
      final reviewed = await repository.readForEdit('one');
      final proposed = reviewed.schedule.copyWith(
        scheduleTime: DateTime.utc(2030, 1, 2, 10),
      );
      ScheduleFormSubmission submission(ScheduleEditBaseline baseline) =>
          ScheduleFormSubmission(
            schedule: proposed,
            preparation: reviewed.preparation,
            preparationChanged: false,
            originalSchedule: reviewed.schedule,
            baseline: baseline,
            mutationId: 'reviewed-edit',
            validateTimeReview: () {},
          );
      // The Bloc has checked the current baseline, then another settings write
      // commits before the aggregate transaction actually reads its profile.
      final justChecked = await repository.newBaseline();
      expect(justChecked.revision, reviewed.baseline.revision);
      await db.userDao.updateSpareTime(
        'local-profile',
        const Duration(minutes: 3),
      );
      final beforeRow = await db.select(db.schedules).getSingle();
      final beforeRevision =
          (await db.select(db.users).getSingle()).dataRevision;
      await expectLater(
        repository.save(submission(reviewed.baseline), editing: true),
        throwsA(
          isA<ScheduleSaveRejected>().having(
            (e) => e.failure,
            'failure',
            ScheduleSaveFailure.conflict,
          ),
        ),
      );
      expect(await db.select(db.schedules).getSingle(), beforeRow);
      expect(
        (await db.select(db.users).getSingle()).dataRevision,
        beforeRevision,
      );
      final rereviewed = await repository.readForEdit('one');
      final saved = await repository.save(
        submission(rereviewed.baseline),
        editing: true,
      );
      expect(saved.changed, isTrue);
      expect(
        (await repository.readForEdit('one')).schedule.scheduleTime,
        proposed.scheduleTime,
      );
      expect(
        (await db.select(db.users).getSingle()).dataRevision,
        beforeRevision + 1,
      );
    },
  );

  test(
    'ordinary name edit retains existing policy after unrelated profile revision',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = ScheduleAggregateRepositoryImpl(
        db,
        RecurringScheduleRepositoryImpl(db, now: () => DateTime.utc(2029)),
        gate: LocalDataOperationGate(),
        now: () => DateTime.utc(2029),
      );
      await db.userDao.putUser(
        const UserEntity(
          id: 'local-profile',
          spareTime: Duration.zero,
          note: '',
        ),
      );
      await repository.save(
        ScheduleFormSubmission(
          schedule: schedule(),
          preparation: prep(),
          preparationChanged: true,
          baseline: await repository.newBaseline(),
          mutationId: 'create',
        ),
        editing: false,
      );
      final original = await repository.readForEdit('one');
      await db.userDao.updateSpareTime(
        'local-profile',
        const Duration(minutes: 3),
      );
      final saved = await repository.save(
        ScheduleFormSubmission(
          schedule: original.schedule.copyWith(scheduleName: 'Renamed'),
          preparation: original.preparation,
          preparationChanged: false,
          originalSchedule: original.schedule,
          baseline: original.baseline,
          mutationId: 'rename',
        ),
        editing: true,
      );
      expect(saved.changed, isTrue);
      expect(
        (await repository.readForEdit('one')).schedule.scheduleName,
        'Renamed',
      );
    },
  );

  test(
    'lost successful response replays receipt without repeating expired time approval',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = ScheduleAggregateRepositoryImpl(
        db,
        RecurringScheduleRepositoryImpl(db, now: () => DateTime.utc(2029)),
        gate: LocalDataOperationGate(),
        now: () => DateTime.utc(2029),
      );
      await db.userDao.putUser(
        const UserEntity(
          id: 'local-profile',
          spareTime: Duration.zero,
          note: '',
        ),
      );
      final baseline = await repository.newBaseline();
      var approved = true, validations = 0;
      final value = ScheduleFormSubmission(
        schedule: schedule(),
        preparation: prep(),
        preparationChanged: true,
        baseline: baseline,
        mutationId: 'lost-response',
        validateTimeReview: () {
          validations++;
          if (!approved) {
            throw const ScheduleSaveRejected(ScheduleSaveFailure.conflict);
          }
        },
      );
      await repository.save(
        value,
        editing: false,
      ); // The response is intentionally not retained.
      final firstValidations = validations;
      approved = false;
      final replay = await repository.save(value, editing: false);
      expect(replay.changed, isFalse);
      expect(replay.mutationId, 'lost-response');
      expect(validations, firstValidations);
      expect(await db.select(db.schedules).get(), hasLength(1));
      expect(
        (await db.select(db.users).getSingle()).dataRevision,
        baseline.revision + 1,
      );
    },
  );
}
