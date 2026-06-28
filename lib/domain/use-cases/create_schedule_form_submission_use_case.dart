import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/use-cases/create_custom_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/create_schedule_with_place_use_case.dart';
import 'package:on_time_front/domain/use-cases/schedule_analytics_tracker.dart';
import 'package:on_time_front/domain/use-cases/schedule_form_submission.dart';

@Injectable()
class CreateScheduleFormSubmissionUseCase {
  final CreateScheduleWithPlaceUseCase _createScheduleWithPlaceUseCase;
  final CreateCustomPreparationUseCase _createCustomPreparationUseCase;
  final ScheduleAnalyticsTracker _scheduleAnalyticsTracker;

  CreateScheduleFormSubmissionUseCase(
    this._createScheduleWithPlaceUseCase,
    this._createCustomPreparationUseCase,
    this._scheduleAnalyticsTracker,
  );

  Future<void> call(ScheduleFormSubmission submission) async {
    await _createScheduleWithPlaceUseCase(submission.schedule);
    if (submission.preparationChanged) {
      await _createCustomPreparationUseCase(
        submission.preparation,
        submission.schedule.id,
      );
    }
    await _scheduleAnalyticsTracker.trackScheduleCreated(
      schedule: submission.schedule,
      preparation: submission.preparation,
    );
  }
}
