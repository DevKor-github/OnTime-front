import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/error/failures.dart';
import 'package:on_time_front/core/error/result.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';

@Injectable()
class GetScheduleByIdUseCase {
  final ScheduleRepository _scheduleRepository;

  GetScheduleByIdUseCase(this._scheduleRepository);

  Future<Result<ScheduleEntity, Failure>> call(String id) {
    return _scheduleRepository.getScheduleById(id);
  }
}
