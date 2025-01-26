import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';

@Injectable()
class DeleteScheduleUseCase {
  final ScheduleRepository _scheduleRepository;

  DeleteScheduleUseCase(this._scheduleRepository);

  Future<void> call(ScheduleEntity schedule) async {
    return _scheduleRepository.deleteSchedule(schedule);
  }
}
