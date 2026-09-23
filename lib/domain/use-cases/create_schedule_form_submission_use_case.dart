import 'package:on_time_front/domain/use-cases/recurring_schedules_use_case.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/use-cases/create_custom_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/create_schedule_with_place_use_case.dart';
import 'package:on_time_front/domain/use-cases/schedule_form_submission.dart';

@Injectable()
class CreateScheduleFormSubmissionUseCase {
  final CreateScheduleWithPlaceUseCase _createScheduleWithPlaceUseCase;
  final CreateCustomPreparationUseCase _createCustomPreparationUseCase;

  CreateScheduleFormSubmissionUseCase(
    this._createScheduleWithPlaceUseCase,
    this._createCustomPreparationUseCase, {
    RecurringSchedulesUseCase? recurringSchedules,
  }) : _recurring = recurringSchedules;

  final RecurringSchedulesUseCase? _recurring;

  Future<void> call(ScheduleFormSubmission submission) async {
    if (submission.recurrenceRule != null) {
      await _recurring!.save(submission);
      return;
    }
    await _createScheduleWithPlaceUseCase(submission.schedule);
    if (submission.preparationChanged) {
      await _createCustomPreparationUseCase(
        submission.preparation,
        submission.schedule.id,
      );
    }
  }
}
