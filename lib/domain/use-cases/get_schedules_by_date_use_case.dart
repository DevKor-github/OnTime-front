import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';

@Injectable()
class GetSchedulesByDateUseCase {
  final ScheduleRepository _scheduleRepository;

  GetSchedulesByDateUseCase(this._scheduleRepository);

  Stream<List<ScheduleEntity>> call(
      DateTime startDate, DateTime endDate) async* {
    final schedulesStream = _scheduleRepository.scheduleStream;
    await for (final schedules in schedulesStream) {
      final filteredSchedules = schedules
          .where((schedule) =>
              schedule.scheduleTime.compareTo(startDate) >= 0 &&
              schedule.scheduleTime.isBefore(endDate))
          .toList();
      filteredSchedules
          .sort((a, b) => a.scheduleTime.compareTo(b.scheduleTime));
      yield filteredSchedules;
    }
  }
}
