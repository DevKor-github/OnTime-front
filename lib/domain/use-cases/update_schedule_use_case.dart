import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';

@Injectable()
class UpdateScheduleUseCase {
  final ScheduleRepository _scheduleRepository;

  UpdateScheduleUseCase(this._scheduleRepository);

  Future<void> call(ScheduleEntity schedule) async {
    await _scheduleRepository.updateSchedule(schedule);
  }
}
