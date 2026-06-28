import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_preparation_mode.dart';
import 'package:on_time_front/domain/use-cases/schedule_form_submission.dart';
import 'package:on_time_front/domain/use-cases/update_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/update_schedule_form_submission_use_case.dart';
import 'package:on_time_front/domain/use-cases/update_schedule_use_case.dart';

class SpyUpdateScheduleUseCase implements UpdateScheduleUseCase {
  final updatedSchedules = <ScheduleEntity>[];

  @override
  Future<void> call(
    ScheduleEntity schedule, {
    bool includePreparationSource = false,
  }) async {
    updatedSchedules.add(schedule);
  }
}

class SpyUpdatePreparationByScheduleIdUseCase
    implements UpdatePreparationByScheduleIdUseCase {
  final updatedPreparations = <({PreparationEntity preparation, String id})>[];

  @override
  Future<void> call(
    PreparationEntity preparationEntity,
    String scheduleId,
  ) async {
    updatedPreparations.add((preparation: preparationEntity, id: scheduleId));
  }
}

void main() {
  ScheduleEntity schedule({bool isChanged = false}) {
    return ScheduleEntity(
      id: 'schedule-1',
      place: PlaceEntity(id: 'place-1', placeName: 'Office'),
      scheduleName: 'Meeting',
      scheduleTime: DateTime(2027, 3, 20, 9),
      moveTime: const Duration(minutes: 30),
      isChanged: isChanged,
      isStarted: false,
      scheduleSpareTime: const Duration(minutes: 10),
      scheduleNote: '',
    );
  }

  test(
    'unchanged preparation updates the schedule without saving preparation',
    () async {
      final updateScheduleUseCase = SpyUpdateScheduleUseCase();
      final updatePreparationUseCase =
          SpyUpdatePreparationByScheduleIdUseCase();
      final useCase = UpdateScheduleFormSubmissionUseCase(
        updateScheduleUseCase,
        updatePreparationUseCase,
      );
      final targetSchedule = schedule();
      final preparation = PreparationEntity(
        preparationStepList: const [
          PreparationStepEntity(
            id: 'prep-1',
            preparationName: 'Shower',
            preparationTime: Duration(minutes: 10),
          ),
        ],
      );

      await useCase(
        ScheduleFormSubmission(
          schedule: targetSchedule,
          preparation: preparation,
          preparationChanged: false,
        ),
      );

      expect(updateScheduleUseCase.updatedSchedules, [targetSchedule]);
      expect(updatePreparationUseCase.updatedPreparations, isEmpty);
    },
  );

  test(
    'changed default preparation is copied with fresh ordered step IDs',
    () async {
      final updateScheduleUseCase = SpyUpdateScheduleUseCase();
      final updatePreparationUseCase =
          SpyUpdatePreparationByScheduleIdUseCase();
      final generatedIds = ['new-step-1', 'new-step-2'].iterator;
      final useCase = UpdateScheduleFormSubmissionUseCase.withIdGenerator(
        updateScheduleUseCase,
        updatePreparationUseCase,
        newId: () {
          generatedIds.moveNext();
          return generatedIds.current;
        },
      );
      const preparation = PreparationEntity(
        preparationStepList: [
          PreparationStepEntity(
            id: 'default-step-2',
            preparationName: 'Bathroom',
            preparationTime: Duration(minutes: 5),
          ),
          PreparationStepEntity(
            id: 'default-step-1',
            preparationName: 'Makeup',
            preparationTime: Duration(minutes: 20),
            nextPreparationId: 'default-step-2',
          ),
        ],
      );

      await useCase(
        ScheduleFormSubmission(
          schedule: schedule(isChanged: true),
          preparation: preparation,
          preparationChanged: true,
          originalPreparationMode: SchedulePreparationMode.defaultPreparation,
        ),
      );

      final updated =
          updatePreparationUseCase.updatedPreparations.single.preparation;
      final steps = updated.preparationStepList;
      expect(steps.map((step) => step.id), ['new-step-1', 'new-step-2']);
      expect(steps.map((step) => step.preparationName), ['Makeup', 'Bathroom']);
      expect(steps[0].nextPreparationId, 'new-step-2');
      expect(steps[1].nextPreparationId, isNull);
    },
  );

  test('changed custom preparation preserves step IDs', () async {
    final updateScheduleUseCase = SpyUpdateScheduleUseCase();
    final updatePreparationUseCase = SpyUpdatePreparationByScheduleIdUseCase();
    final useCase = UpdateScheduleFormSubmissionUseCase(
      updateScheduleUseCase,
      updatePreparationUseCase,
    );
    const preparation = PreparationEntity(
      preparationStepList: [
        PreparationStepEntity(
          id: 'custom-step-1',
          preparationName: 'Makeup',
          preparationTime: Duration(minutes: 20),
          nextPreparationId: 'custom-step-2',
        ),
        PreparationStepEntity(
          id: 'custom-step-2',
          preparationName: 'Bathroom',
          preparationTime: Duration(minutes: 5),
        ),
      ],
    );

    await useCase(
      ScheduleFormSubmission(
        schedule: schedule(isChanged: true),
        preparation: preparation,
        preparationChanged: true,
        originalPreparationMode: SchedulePreparationMode.custom,
      ),
    );

    final updated =
        updatePreparationUseCase.updatedPreparations.single.preparation;
    expect(updated.preparationStepList.map((step) => step.id), [
      'custom-step-1',
      'custom-step-2',
    ]);
    expect(updated.preparationStepList[0].nextPreparationId, 'custom-step-2');
    expect(updated.preparationStepList[1].nextPreparationId, isNull);
  });
}
