import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';
import 'package:on_time_front/domain/use-cases/schedule_mutation_alarm_effects_coordinator.dart';

@Injectable()
class DeleteScheduleUseCase {
  final ScheduleRepository _scheduleRepository;
  final ScheduleMutationAlarmEffectsCoordinator _alarmEffectsCoordinator;

  DeleteScheduleUseCase(
    this._scheduleRepository,
    this._alarmEffectsCoordinator,
  );

  Future<void> call(ScheduleEntity schedule) async {
    await _scheduleRepository.deleteSchedule(schedule);
    await _alarmEffectsCoordinator(
      operation: ScheduleMutationAlarmOperation.deleted,
      scheduleId: schedule.id,
    );
  }
}
