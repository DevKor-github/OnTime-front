import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';

class GetScheduleForWeek {
  final ScheduleRepository _scheduleRepository;

  GetScheduleForWeek(this._scheduleRepository);

  Future<List<ScheduleEntity>> execute(DateTime date) async {
    final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
    final endOfWeek = startOfWeek.add(Duration(days: 6));

    return await _scheduleRepository.getSchedulesByDate(startOfWeek, endOfWeek);
  }
}
