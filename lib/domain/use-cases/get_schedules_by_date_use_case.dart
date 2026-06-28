import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';

@Injectable()
class GetSchedulesByDateUseCase {
  final ScheduleRepository _scheduleRepository;

  GetSchedulesByDateUseCase(this._scheduleRepository);

  Stream<List<ScheduleEntity>> call(DateTime startDate, DateTime endDate) {
    return _scheduleRepository.watchSchedulesByDate(startDate, endDate);
  }
}
