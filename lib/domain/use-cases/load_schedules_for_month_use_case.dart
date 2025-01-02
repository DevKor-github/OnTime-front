import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';

@Injectable()
class LoadSchedulesForMonthUseCase {
  final ScheduleRepository _scheduleRepository;

  LoadSchedulesForMonthUseCase(this._scheduleRepository);

  Future<void> execute(DateTime date) async {
    final startOfMonth = DateTime(date.year, date.month, 1);
    final endOfMonth = DateTime(date.year, date.month + 1, 0);

    await _scheduleRepository.getSchedulesByDate(startOfMonth, endOfMonth);
  }
}
