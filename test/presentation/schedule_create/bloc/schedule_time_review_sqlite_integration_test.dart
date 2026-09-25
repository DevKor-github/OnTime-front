// Production Bloc -> use cases -> workflow -> aggregate -> actual SQLite.
// Only platform time/id and post-commit OS effects are controlled here.
import 'dart:async';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/constants/local_profile.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/data/repositories/recurring_schedule_repository_impl.dart';
import 'package:on_time_front/data/repositories/schedule_aggregate_repository_impl.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_save.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/use-cases/create_schedule_form_submission_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_default_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_schedule_by_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_schedule_form_draft_use_case.dart';
import 'package:on_time_front/domain/use-cases/schedule_mutation_alarm_effects_coordinator.dart';
import 'package:on_time_front/domain/use-cases/schedule_save_workflow.dart';
import 'package:on_time_front/domain/use-cases/update_schedule_form_submission_use_case.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form_bloc.dart';

class _UnusedLoad extends Fake implements LoadPreparationByScheduleIdUseCase {}

class _UnusedPreparation extends Fake
    implements GetPreparationByScheduleIdUseCase {}

class _UnusedDefault extends Fake implements GetDefaultPreparationUseCase {}

class _UnusedSchedule extends Fake implements GetScheduleByIdUseCase {}

class _Effects extends Fake implements ScheduleMutationAlarmEffectsCoordinator {
  int calls = 0;
  bool succeeds = true;
  @override
  Future<bool> afterCommit() async {
    calls++;
    return succeeds;
  }
}

class _ReceiptBarrier extends QueryInterceptor {
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

class _Fixture {
  _Fixture({this.barrier});
  final _ReceiptBarrier? barrier;
  late AppDatabase db;
  late ScheduleAggregateRepositoryImpl repository;
  late ScheduleFormBloc bloc;
  final effects = _Effects();
  DateTime now = DateTime.utc(2026, 10, 1);
  String device = 'America/New_York';
  int ids = 0;

  Future<void> open() async {
    final executor = NativeDatabase.memory();
    db = AppDatabase.forTesting(
      barrier == null ? executor : executor.interceptWith(barrier!),
    );
    repository = ScheduleAggregateRepositoryImpl(
      db,
      RecurringScheduleRepositoryImpl(db, now: () => now),
      gate: LocalDataOperationGate(),
      now: () => now,
    );
    await db.userDao.putUser(
      const UserEntity(id: localProfileId, spareTime: Duration.zero, note: ''),
    );
    final load = LoadScheduleFormDraftUseCase.withOverrides(
      _UnusedLoad(),
      _UnusedPreparation(),
      _UnusedDefault(),
      _UnusedSchedule(),
      now: () => now,
      newId: () => 'synthetic-${++ids}',
      timeZoneId: () async => device,
      aggregate: repository,
    );
    final workflow = ScheduleSaveWorkflow(repository, effects);
    bloc = ScheduleFormBloc(
      load,
      CreateScheduleFormSubmissionUseCase(workflow),
      UpdateScheduleFormSubmissionUseCase(workflow),
      aggregate: repository,
      now: () => now,
    );
  }

  Future<void> send(
    ScheduleFormEvent event,
    bool Function(ScheduleFormState) accepts,
  ) async {
    final result = bloc.stream
        .firstWhere(accepts)
        .timeout(const Duration(seconds: 10));
    bloc.add(event);
    await result;
    // Let the event handler's finally retire its pending owner before next input.
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> draft(int offset) async {
    await send(
      const ScheduleFormCreateRequested(),
      (s) => s.status == ScheduleFormStatus.success,
    );
    await send(
      const ScheduleFormScheduleNameChanged(
        scheduleName: 'Synthetic fold appointment',
      ),
      (s) => s.scheduleName != null,
    );
    await send(
      const ScheduleFormPlaceNameChanged(placeName: 'Synthetic place'),
      (s) => s.placeName != null,
    );
    await send(
      const ScheduleFormMoveTimeChanged(moveTime: Duration.zero),
      (s) => s.moveTime != null,
    );
    await send(
      ScheduleFormPreparationChanged(
        preparation: PreparationEntity(
          preparationStepList: const [
            PreparationStepEntity(
              id: 'fixture-step',
              preparationName: 'Prepare',
              preparationTime: Duration(minutes: 10),
            ),
          ],
        ),
      ),
      (s) => s.totalPreparationTime == const Duration(minutes: 10),
    );
    final civil = DateTime.utc(2026, 11, 1, 1, 30, 1, 123, 456);
    await send(
      ScheduleFormScheduleDateTimeChanged(
        scheduleDate: civil,
        scheduleTime: civil,
        timeZoneId: 'America/New_York',
        timeZoneExplicitlySelected: true,
        occurrenceOffsetSeconds: offset,
      ),
      (s) => s.scheduleTime == civil && s.occurrenceOffsetSeconds == offset,
    );
  }

  Future<int> revision() async =>
      (await db.select(db.users).getSingle()).dataRevision;
  Future<void> close() async {
    if (barrier != null && !barrier!.release.isCompleted) {
      barrier!.release.complete();
    }
    await bloc.close();
    await db.close();
  }
}

void main() {
  for (final offset in [-14400, -18000]) {
    test(
      'actual form saves explicit fold $offset once, cancel writes nothing, edit reload preserves civil',
      () async {
        final f = _Fixture();
        await f.open();
        addTearDown(f.close);
        await f.draft(offset);
        final civil = f.bloc.state.scheduleTime;
        final before = await f.revision();
        await f.send(
          const ScheduleFormCreated(),
          (s) => s.submissionStatus == ScheduleFormSubmissionStatus.timeReview,
        );
        final firstReview = f.bloc.state.timeReview!;
        expect(
          firstReview.resolution.instantUtc,
          DateTime.utc(2026, 11, 1, offset == -14400 ? 5 : 6, 30, 1, 123, 456),
        );
        expect(await f.db.select(f.db.schedules).get(), isEmpty);
        expect(f.effects.calls, 0);
        await f.send(
          const ScheduleFormReviewDismissed(),
          (s) => s.submissionStatus == ScheduleFormSubmissionStatus.idle,
        );
        expect(f.bloc.state.scheduleTime, civil);
        expect(await f.revision(), before);
        expect(f.effects.calls, 0);
        await f.send(
          const ScheduleFormCreated(),
          (s) => s.submissionStatus == ScheduleFormSubmissionStatus.timeReview,
        );
        final review = f.bloc.state.timeReview!;
        expect(identical(review, firstReview), isFalse);
        await f.send(
          ScheduleFormTimeReviewConfirmed(review),
          (s) => s.submissionStatus == ScheduleFormSubmissionStatus.success,
        );
        final id = f.bloc.state.id;
        expect(await f.db.select(f.db.schedules).get(), hasLength(1));
        expect(await f.revision(), before + 1);
        expect(f.effects.calls, 1);
        f.device = 'Asia/Tokyo';
        await f.send(
          ScheduleFormEditRequested(scheduleId: id),
          (s) => s.status == ScheduleFormStatus.success,
        );
        expect(f.bloc.state.scheduleTime, civil);
        expect(f.bloc.state.timeZoneId, 'America/New_York');
        expect(f.bloc.state.occurrenceOffsetSeconds, offset);
        expect(await f.revision(), before + 1);
        expect(f.effects.calls, 1);
      },
    );
  }

  test(
    'real Bloc authority crossing preparation start after SQL receipt write rolls back all data and effects',
    () async {
      final barrier = _ReceiptBarrier();
      final f = _Fixture(barrier: barrier);
      await f.open();
      addTearDown(f.close);
      await f.draft(-14400);
      final before = await f.revision();
      await f.send(
        const ScheduleFormCreated(),
        (s) => s.submissionStatus == ScheduleFormSubmissionStatus.timeReview,
      );
      final review = f.bloc.state.timeReview!;
      barrier.armed = true;
      final failed = f.send(
        ScheduleFormTimeReviewConfirmed(review),
        (s) => s.submissionStatus == ScheduleFormSubmissionStatus.failure,
      );
      await barrier.entered.future.timeout(const Duration(seconds: 10));
      f.now = review.preparationStartUtc;
      barrier.release.complete();
      await failed;
      expect(f.bloc.state.saveFailure, ScheduleSaveFailure.conflict);
      expect(await f.db.select(f.db.schedules).get(), isEmpty);
      expect(await f.db.select(f.db.places).get(), isEmpty);
      expect(await f.db.select(f.db.preparationSchedules).get(), isEmpty);
      expect(await f.revision(), before);
      expect(f.effects.calls, 0);
      // Restore a valid synthetic clock and require a fresh user review.
      f.now = DateTime.utc(2026, 10, 1);
      await f.send(
        const ScheduleFormCreated(),
        (s) => s.submissionStatus == ScheduleFormSubmissionStatus.timeReview,
      );
      final fresh = f.bloc.state.timeReview!;
      expect(identical(fresh, review), isFalse);
      await f.send(
        ScheduleFormTimeReviewConfirmed(fresh),
        (s) => s.submissionStatus == ScheduleFormSubmissionStatus.success,
      );
      expect(await f.db.select(f.db.schedules).get(), hasLength(1));
      expect(await f.revision(), before + 1);
      expect(f.effects.calls, 1);
    },
  );

  test(
    'double confirmation plus delivery retry commits one row and one revision',
    () async {
      final f = _Fixture();
      await f.open();
      addTearDown(f.close);
      await f.draft(-18000);
      final before = await f.revision();
      await f.send(
        const ScheduleFormCreated(),
        (s) => s.submissionStatus == ScheduleFormSubmissionStatus.timeReview,
      );
      final review = f.bloc.state.timeReview!;
      f.effects.succeeds = false;
      final pending = f.send(
        ScheduleFormTimeReviewConfirmed(review),
        (s) =>
            s.submissionStatus == ScheduleFormSubmissionStatus.deliveryPending,
      );
      f.bloc.add(ScheduleFormTimeReviewConfirmed(review));
      await pending;
      expect(await f.db.select(f.db.schedules).get(), hasLength(1));
      expect(await f.revision(), before + 1);
      expect(f.effects.calls, 1);
      f.effects.succeeds = true;
      await f.send(
        const ScheduleFormCreated(),
        (s) => s.submissionStatus == ScheduleFormSubmissionStatus.success,
      );
      expect(await f.db.select(f.db.schedules).get(), hasLength(1));
      expect(await f.revision(), before + 1);
      expect(f.effects.calls, 2);
    },
  );
}
