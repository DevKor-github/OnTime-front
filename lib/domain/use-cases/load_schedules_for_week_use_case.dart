import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';

@Injectable()
class LoadSchedulesForWeekUseCase {
  final ScheduleRepository _scheduleRepository;
  LoadSchedulesForWeekUseCase(this._scheduleRepository);

  Future<void> call(DateTime date) async {
    final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
    final endOfWeek = startOfWeek.add(Duration(days: 7));

    await _scheduleRepository.getSchedulesByDate(startOfWeek, endOfWeek);
  }
}
