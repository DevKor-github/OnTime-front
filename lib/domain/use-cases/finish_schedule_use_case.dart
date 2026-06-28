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
    await _scheduleRepository.startSchedule(scheduleId);
    await _scheduleRepository.finishSchedule(scheduleId, latenessTime);
    await _alarmEffectsCoordinator(
      operation: ScheduleMutationAlarmOperation.finished,
      scheduleId: scheduleId,
    );
  }
}
