import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';
import 'package:on_time_front/domain/use-cases/schedule_mutation_alarm_effects_coordinator.dart';

@Injectable()
class CreateScheduleWithPlaceUseCase {
  final ScheduleRepository _scheduleRepository;
  final ScheduleMutationAlarmEffectsCoordinator _alarmEffectsCoordinator;

  CreateScheduleWithPlaceUseCase(
    this._scheduleRepository,
    this._alarmEffectsCoordinator,
  );

  Future<void> call(ScheduleEntity schedule) async {
    await _scheduleRepository.createSchedule(schedule);
    await _alarmEffectsCoordinator(
      operation: ScheduleMutationAlarmOperation.created,
      scheduleId: schedule.id,
    );
  }
}
