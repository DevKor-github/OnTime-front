import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
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
      final schedule = ScheduleEntity(
        id: 'schedule-1',
        place: PlaceEntity(id: 'place-1', placeName: 'Office'),
        scheduleName: 'Meeting',
        scheduleTime: DateTime(2027, 3, 20, 9),
        moveTime: const Duration(minutes: 30),
        isChanged: false,
        isStarted: false,
        scheduleSpareTime: const Duration(minutes: 10),
        scheduleNote: '',
      );
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
          schedule: schedule,
          preparation: preparation,
          preparationChanged: false,
        ),
      );

      expect(updateScheduleUseCase.updatedSchedules, [schedule]);
      expect(updatePreparationUseCase.updatedPreparations, isEmpty);
    },
  );
}
