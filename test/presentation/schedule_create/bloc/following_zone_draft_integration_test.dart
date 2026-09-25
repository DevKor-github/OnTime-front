import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/data/repositories/recurring_schedule_repository_impl.dart';
import 'package:on_time_front/data/repositories/schedule_aggregate_repository_impl.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
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

class _Effects extends Fake
    implements ScheduleMutationAlarmEffectsCoordinator {}

void main() {
  for (final scenario in [
    (choice: RepeatedCivilTime.first, unavailable: false),
    (choice: RepeatedCivilTime.second, unavailable: false),
    (choice: RepeatedCivilTime.first, unavailable: true),
  ]) {
    final choice = scenario.choice;
    test(
      'actual override in Seoul loads following rule in New York with ${choice.name} fold and exact civil (unavailable: ${scenario.unavailable})',
      () async {
        final now = DateTime.utc(2026, 10, 1);
        final start = DateTime.utc(2026, 10, 31, 1, 30, 1, 123, 456);
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await db.userDao.putUser(
          const UserEntity(
            id: 'local-profile',
            spareTime: Duration.zero,
            note: '',
          ),
        );
        final recurring = RecurringScheduleRepositoryImpl(db, now: () => now);
        final aggregate = ScheduleAggregateRepositoryImpl(
          db,
          recurring,
          gate: LocalDataOperationGate(),
          now: () => now,
        );
        const prep = PreparationEntity(
          preparationStepList: [
            PreparationStepEntity(
              id: 'step',
              preparationName: 'Prepare',
              preparationTime: Duration(minutes: 10),
            ),
          ],
        );
        final base = ScheduleEntity(
          id: 'series',
          place: const PlaceEntity(id: 'p', placeName: 'Place'),
          scheduleName: 'Base schedule',
          scheduleTime: start,
          timeZoneId: 'America/New_York',
          occurrenceOffsetSeconds: -14400,
          moveTime: Duration.zero,
          isChanged: false,
          isStarted: false,
          scheduleSpareTime: Duration.zero,
          scheduleNote: '',
        );
        final rule = RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          start: start,
          timeZoneId: 'America/New_York',
          count: 3,
          repeatedTime: choice,
        );
        await recurring.create(base, prep, rule);
        final rows = (await db.scheduleDao.getScheduleList())
            .map((row) => row.toScheduleEntity())
            .toList();
        final original = rows.singleWhere((row) => row.scheduleTime.day == 1);
        final override = original.copyWith(
          timeZoneId: 'Asia/Seoul',
          occurrenceOffsetSeconds: 32400,
        );
        await recurring.updateOccurrence(
          original,
          override,
          prep,
          preparationChanged: false,
        );
        final beforeRows = await db.select(db.schedules).get();
        final beforeRevision =
            (await db.select(db.users).getSingle()).dataRevision;
        final load = LoadScheduleFormDraftUseCase.withOverrides(
          _UnusedLoad(),
          _UnusedPreparation(),
          _UnusedDefault(),
          _UnusedSchedule(),
          now: () => now,
          newId: () => 'unused',
          aggregate: aggregate,
        );
        if (scenario.unavailable) {
          final location = tz.timeZoneDatabase.locations.remove(
            'America/New_York',
          )!;
          addTearDown(() {
            tz.timeZoneDatabase.locations['America/New_York'] = location;
          });
        }
        final workflow = ScheduleSaveWorkflow(aggregate, _Effects());
        final bloc = ScheduleFormBloc(
          load,
          CreateScheduleFormSubmissionUseCase(workflow),
          UpdateScheduleFormSubmissionUseCase(workflow),
          aggregate: aggregate,
          now: () => now,
        );
        addTearDown(bloc.close);
        final loaded = bloc.stream
            .firstWhere((s) => s.status == ScheduleFormStatus.success)
            .timeout(const Duration(seconds: 10));
        bloc.add(
          ScheduleFormEditRequested(
            scheduleId: original.id,
            scope: RecurringEditScope.following,
          ),
        );
        await loaded;
        expect(bloc.state.timeZoneId, 'America/New_York');
        expect(
          bloc.state.scheduleTime,
          DateTime.utc(2026, 11, 1, 1, 30, 1, 123, 456),
        );
        expect(
          bloc.state.occurrenceOffsetSeconds,
          scenario.unavailable
              ? null
              : choice == RepeatedCivilTime.first
              ? -14400
              : -18000,
        );
        expect(bloc.state.recurrenceRule!.repeatedTime, choice);
        expect(bloc.state.originalSchedule!.timeZoneId, 'Asia/Seoul');
        expect(
          (await db.select(db.users).getSingle()).dataRevision,
          beforeRevision,
        );
        expect(await db.select(db.schedules).get(), beforeRows);
      },
    );
  }
}
