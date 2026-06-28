import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';
import 'package:on_time_front/domain/use-cases/schedule_mutation_alarm_effects_coordinator.dart';

@Injectable()
class UpdateScheduleUseCase {
  final ScheduleRepository _scheduleRepository;
  final ScheduleMutationAlarmEffectsCoordinator _alarmEffectsCoordinator;

  UpdateScheduleUseCase(
    this._scheduleRepository,
    this._alarmEffectsCoordinator,
  );

  Future<void> call(
    ScheduleEntity schedule, {
    bool includePreparationSource = false,
  }) async {
    await _scheduleRepository.updateSchedule(
      schedule,
      includePreparationSource: includePreparationSource,
    );
    await _alarmEffectsCoordinator(
      operation: ScheduleMutationAlarmOperation.updated,
      scheduleId: schedule.id,
    );
  }
}
