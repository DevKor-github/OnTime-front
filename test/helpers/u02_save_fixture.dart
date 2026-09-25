import 'package:on_time_front/domain/use-cases/delete_schedule_use_case.dart';
import 'package:on_time_front/domain/entities/schedule_deletion.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
// Production Bloc -> use cases -> workflow -> aggregate -> actual SQLite.
// Controls platform time/id, OS effects, and optional post-commit response loss.
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
import 'package:on_time_front/domain/repositories/schedule_aggregate_repository.dart';
import 'package:on_time_front/domain/use-cases/create_schedule_form_submission_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_default_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_schedule_by_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_schedule_form_draft_use_case.dart';
import 'package:on_time_front/domain/use-cases/schedule_mutation_alarm_effects_coordinator.dart';
import 'package:on_time_front/domain/use-cases/schedule_save_workflow.dart';
import 'package:on_time_front/domain/use-cases/schedule_form_submission.dart';
import 'package:on_time_front/domain/use-cases/update_schedule_form_submission_use_case.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form_bloc.dart';

import 'package:on_time_front/domain/repositories/schedule_repository.dart';
import 'package:on_time_front/domain/use-cases/recurring_schedules_use_case.dart';

class _UnusedSchedules extends Fake implements ScheduleRepository {}

class _UnusedLoad extends Fake implements LoadPreparationByScheduleIdUseCase {}

class _UnusedPreparation extends Fake
    implements GetPreparationByScheduleIdUseCase {}

class _UnusedDefault extends Fake implements GetDefaultPreparationUseCase {}

class _UnusedSchedule extends Fake implements GetScheduleByIdUseCase {}

class U02AlarmEffects extends Fake
    implements ScheduleMutationAlarmEffectsCoordinator {
  int calls = 0;
  bool succeeds = true;
  @override
  Future<bool> afterCommit() async {
    calls++;
    return succeeds;
  }
}

class U02SaveFixture {
  U02SaveFixture({this.loseFirstSaveResponseOnce = false});

  bool loseFirstSaveResponseOnce;
  final gate = LocalDataOperationGate();
  late RecurringScheduleRepositoryImpl recurring;
  late AppDatabase db;
  late ScheduleAggregateRepositoryImpl aggregate;
  late ScheduleFormBloc bloc;
  final effects = U02AlarmEffects();
  DateTime now = DateTime.utc(2026, 10, 1);
  String device = 'America/New_York';
  int ids = 0;

  Future<void> open() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    recurring = RecurringScheduleRepositoryImpl(db, now: () => now);
    aggregate = ScheduleAggregateRepositoryImpl(
      db,
      recurring,
      gate: gate,
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
      aggregate: aggregate,
    );
    final workflow = ScheduleSaveWorkflow(
      _ResponseLossAggregate(aggregate, () {
        final loseResponse = loseFirstSaveResponseOnce;
        loseFirstSaveResponseOnce = false;
        return loseResponse;
      }),
      effects,
    );
    bloc = ScheduleFormBloc(
      load,
      CreateScheduleFormSubmissionUseCase(workflow),
      UpdateScheduleFormSubmissionUseCase(workflow),
      aggregate: aggregate,
      recurringSchedules: RecurringSchedulesUseCase(
        recurring,
        _UnusedSchedules(),
        effects,
        _UnusedDeletion(),
      ),
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
    await bloc.close();
    await db.close();
  }
}

// The real transaction completes before this optional transport-style failure.
// A retry still reaches the production writer and its persisted receipt lookup.
class _ResponseLossAggregate implements ScheduleAggregateRepository {
  _ResponseLossAggregate(this.delegate, this.consumeResponseLoss);

  final ScheduleAggregateRepository delegate;
  final bool Function() consumeResponseLoss;

  @override
  Future<ScheduleDeletionIntent> readForDeletion(
    String id, {
    RecurringEditScope scope = RecurringEditScope.occurrence,
  }) => delegate.readForDeletion(id, scope: scope);

  @override
  Future<ScheduleDeletionCommit> delete(ScheduleDeletionIntent intent) =>
      delegate.delete(intent);

  @override
  Future<bool> isDeletionCurrent(ScheduleDeletionCommit commit) =>
      delegate.isDeletionCurrent(commit);

  @override
  Future<ScheduleEditBaseline> newBaseline() => delegate.newBaseline();

  @override
  Future<({ScheduleEditBaseline baseline, PreparationEntity preparation})>
  newDraft() => delegate.newDraft();

  @override
  Future<ScheduleEditSnapshot> readForEdit(String id) =>
      delegate.readForEdit(id);

  @override
  bool isCurrent(ScheduleSaveReceipt receipt) => delegate.isCurrent(receipt);

  @override
  Future<ScheduleSaveReceipt> save(
    ScheduleFormSubmission submission, {
    required bool editing,
  }) async {
    final receipt = await delegate.save(submission, editing: editing);
    if (consumeResponseLoss()) {
      throw StateError('Synthetic response loss after committed save');
    }
    return receipt;
  }
}

class _UnusedDeletion extends Fake implements DeleteScheduleUseCase {}
