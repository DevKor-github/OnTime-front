import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/error/failures.dart';
import 'package:on_time_front/core/error/result.dart';
import 'package:on_time_front/core/error/unit.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';

@Injectable()
class CreateScheduleWithPlaceUseCase {
  final ScheduleRepository _scheduleRepository;

  CreateScheduleWithPlaceUseCase(this._scheduleRepository);

  Future<Result<Unit, Failure>> call(ScheduleEntity schedule) async {
    return _scheduleRepository.createSchedule(schedule);
  }
}
