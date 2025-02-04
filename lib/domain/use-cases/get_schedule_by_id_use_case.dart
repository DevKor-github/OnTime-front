import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';

@Injectable()
class GetScheduleByIdUseCase {
  final ScheduleRepository _scheduleRepository;

  GetScheduleByIdUseCase(this._scheduleRepository);

  Future<ScheduleEntity> call(String id) {
    return _scheduleRepository.getScheduleById(id);
  }
}
