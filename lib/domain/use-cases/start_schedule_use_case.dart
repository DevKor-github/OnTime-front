import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';

@Injectable()
class StartScheduleUseCase {
  final ScheduleRepository _scheduleRepository;

  StartScheduleUseCase(this._scheduleRepository);

  Future<void> call(String scheduleId) async {
    await _scheduleRepository.startSchedule(scheduleId);
  }
}
