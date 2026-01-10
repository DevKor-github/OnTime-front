import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/use-cases/load_schedules_by_date_use_case.dart';

@Injectable()
class LoadSchedulesForWeekUseCase {
  final LoadSchedulesByDateUseCase _loadSchedulesByDateUseCase;

  LoadSchedulesForWeekUseCase(this._loadSchedulesByDateUseCase);

  Future<void> call(DateTime date) async {
    final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
    final endOfWeek = startOfWeek.add(Duration(days: 7));

    await _loadSchedulesByDateUseCase(startOfWeek, endOfWeek);
  }
}
