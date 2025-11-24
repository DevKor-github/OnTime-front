import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/use-cases/load_schedules_by_date_use_case.dart';

@Injectable()
class LoadSchedulesForMonthUseCase {
  final LoadSchedulesByDateUseCase _loadSchedulesByDateUseCase;

  LoadSchedulesForMonthUseCase(this._loadSchedulesByDateUseCase);

  Future<void> call(DateTime date) async {
    final startOfMonth = DateTime(date.year, date.month, 1);
    final endOfMonth = DateTime(date.year, date.month + 1, 0);

    await _loadSchedulesByDateUseCase(startOfMonth, endOfMonth);
  }
}
