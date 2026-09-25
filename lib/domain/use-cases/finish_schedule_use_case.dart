import 'package:on_time_front/domain/entities/schedule_start_rejected.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';
import 'package:on_time_front/domain/use-cases/schedule_mutation_alarm_effects_coordinator.dart';

@Injectable()
class FinishScheduleUseCase {
  final ScheduleRepository _scheduleRepository;
  final ScheduleMutationAlarmEffectsCoordinator _alarmEffectsCoordinator;

  FinishScheduleUseCase(
    this._scheduleRepository,
    this._alarmEffectsCoordinator,
  );

  Future<void> call(String scheduleId, int latenessTime) async {
    try {
      await _scheduleRepository.startSchedule(scheduleId);
    } on ScheduleStartRejected {
      // Repeated finish remains idempotent; start itself rejects ended runs.
    }
    await _scheduleRepository.finishSchedule(scheduleId, latenessTime);
    await _alarmEffectsCoordinator(
      operation: ScheduleMutationAlarmOperation.finished,
      scheduleId: scheduleId,
    );
  }
}
