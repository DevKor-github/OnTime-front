import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';

@injectable
class CreateScheduleWithPlaceUseCase {
  final ScheduleRepository _scheduleRepository;

  CreateScheduleWithPlaceUseCase(this._scheduleRepository);

  Future<void> call(ScheduleEntity schedule) async {
    await _scheduleRepository.createSchedule(schedule);
  }
}
