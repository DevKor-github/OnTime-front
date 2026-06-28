import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_preparation_mode.dart';
import 'package:on_time_front/domain/use-cases/schedule_form_submission.dart';
import 'package:on_time_front/domain/use-cases/update_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/update_schedule_use_case.dart';
import 'package:uuid/uuid.dart';

@Injectable()
class UpdateScheduleFormSubmissionUseCase {
  final UpdateScheduleUseCase _updateScheduleUseCase;
  final UpdatePreparationByScheduleIdUseCase
  _updatePreparationByScheduleIdUseCase;
  final String Function() _newId;

  UpdateScheduleFormSubmissionUseCase(
    this._updateScheduleUseCase,
    this._updatePreparationByScheduleIdUseCase,
  ) : _newId = const Uuid().v7;

  UpdateScheduleFormSubmissionUseCase.withIdGenerator(
    this._updateScheduleUseCase,
    this._updatePreparationByScheduleIdUseCase, {
    required String Function() newId,
  }) : _newId = newId;

  Future<void> call(ScheduleFormSubmission submission) async {
    await _updateScheduleUseCase(submission.schedule);
    if (submission.preparationChanged) {
      await _updatePreparationByScheduleIdUseCase(
        _preparationForUpdate(submission),
        submission.schedule.id,
      );
    }
  }

  PreparationEntity _preparationForUpdate(ScheduleFormSubmission submission) {
    if (submission.originalPreparationMode !=
        SchedulePreparationMode.defaultPreparation) {
      return submission.preparation;
    }

    final orderedSteps = submission.preparation.ordered.preparationStepList;
    final newIds = List.generate(orderedSteps.length, (_) => _newId());
    final copiedSteps = <PreparationStepEntity>[
      for (var i = 0; i < orderedSteps.length; i++)
        PreparationStepEntity(
          id: newIds[i],
          preparationName: orderedSteps[i].preparationName,
          preparationTime: orderedSteps[i].preparationTime,
          nextPreparationId: i + 1 < newIds.length ? newIds[i + 1] : null,
        ),
    ];

    return PreparationEntity(preparationStepList: copiedSteps);
  }
}
