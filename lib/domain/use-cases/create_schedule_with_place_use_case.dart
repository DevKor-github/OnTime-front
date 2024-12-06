import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';

class CreateScheduleWithPlaceUseCase {
  final ScheduleRepository _scheduleRepository;

  CreateScheduleWithPlaceUseCase(this._scheduleRepository);

  Future<void> call(ScheduleEntity schedule) async {
    await _scheduleRepository.createSchedule(schedule);
  }
}
