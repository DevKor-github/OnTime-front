import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/use-cases/create_custom_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/create_schedule_form_submission_use_case.dart';
import 'package:on_time_front/domain/use-cases/create_schedule_with_place_use_case.dart';
import 'package:on_time_front/domain/use-cases/schedule_analytics_tracker.dart';
import 'package:on_time_front/domain/use-cases/schedule_form_submission.dart';

class SpyCreateScheduleWithPlaceUseCase
    implements CreateScheduleWithPlaceUseCase {
  final createdSchedules = <ScheduleEntity>[];

  @override
  Future<void> call(ScheduleEntity schedule) async {
    createdSchedules.add(schedule);
  }
}

class SpyCreateCustomPreparationUseCase
    implements CreateCustomPreparationUseCase {
  final createdPreparations = <({PreparationEntity preparation, String id})>[];

  @override
  Future<void> call(
    PreparationEntity preparationEntity,
    String scheduleId,
  ) async {
    createdPreparations.add((preparation: preparationEntity, id: scheduleId));
  }
}

class SpyScheduleAnalyticsTracker implements ScheduleAnalyticsTracker {
  final createdSchedules =
      <({ScheduleEntity schedule, PreparationEntity preparation})>[];

  @override
  Future<void> trackScheduleCreated({
    required ScheduleEntity schedule,
    required PreparationEntity preparation,
  }) async {
    createdSchedules.add((schedule: schedule, preparation: preparation));
  }
}

void main() {
  test(
    'changed preparation creates schedule, saves custom preparation, and tracks create analytics',
    () async {
      final createScheduleUseCase = SpyCreateScheduleWithPlaceUseCase();
      final createCustomPreparationUseCase =
          SpyCreateCustomPreparationUseCase();
      final analyticsTracker = SpyScheduleAnalyticsTracker();
      final useCase = CreateScheduleFormSubmissionUseCase(
        createScheduleUseCase,
        createCustomPreparationUseCase,
        analyticsTracker,
      );
      final schedule = ScheduleEntity(
        id: 'schedule-1',
        place: PlaceEntity(id: 'place-1', placeName: 'Office'),
        scheduleName: 'Meeting',
        scheduleTime: DateTime(2027, 3, 20, 9),
        moveTime: const Duration(minutes: 30),
        isChanged: true,
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
          preparationChanged: true,
        ),
      );

      expect(createScheduleUseCase.createdSchedules, [schedule]);
      expect(createCustomPreparationUseCase.createdPreparations, [
        (preparation: preparation, id: 'schedule-1'),
      ]);
      expect(analyticsTracker.createdSchedules, [
        (schedule: schedule, preparation: preparation),
      ]);
    },
  );
}
