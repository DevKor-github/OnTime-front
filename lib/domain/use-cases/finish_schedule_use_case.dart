import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';

@Injectable()
class FinishScheduleUseCase {
  final ScheduleRepository _scheduleRepository;

  FinishScheduleUseCase(this._scheduleRepository);

  Future<void> call(String scheduleId, int latenessTime) async {
    await _scheduleRepository.finishSchedule(scheduleId, latenessTime);
  }
}
