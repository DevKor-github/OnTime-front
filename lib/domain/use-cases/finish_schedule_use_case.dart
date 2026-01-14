import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/error/failures.dart';
import 'package:on_time_front/core/error/result.dart';
import 'package:on_time_front/core/error/unit.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';

@Injectable()
class FinishScheduleUseCase {
  final ScheduleRepository _scheduleRepository;

  FinishScheduleUseCase(this._scheduleRepository);

  Future<Result<Unit, Failure>> call(String scheduleId, int latenessTime) async {
    return _scheduleRepository.finishSchedule(scheduleId, latenessTime);
  }
}
