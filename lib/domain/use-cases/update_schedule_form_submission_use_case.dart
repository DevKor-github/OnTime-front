import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/use-cases/schedule_form_submission.dart';
import 'package:on_time_front/domain/use-cases/update_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/update_schedule_use_case.dart';

@Injectable()
class UpdateScheduleFormSubmissionUseCase {
  final UpdateScheduleUseCase _updateScheduleUseCase;
  final UpdatePreparationByScheduleIdUseCase
  _updatePreparationByScheduleIdUseCase;

  UpdateScheduleFormSubmissionUseCase(
    this._updateScheduleUseCase,
    this._updatePreparationByScheduleIdUseCase,
  );

  Future<void> call(ScheduleFormSubmission submission) async {
    await _updateScheduleUseCase(submission.schedule);
    if (submission.preparationChanged) {
      await _updatePreparationByScheduleIdUseCase(
        submission.preparation,
        submission.schedule.id,
      );
    }
  }
}
