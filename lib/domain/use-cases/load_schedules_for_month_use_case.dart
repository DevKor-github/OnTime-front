import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/error/failures.dart';
import 'package:on_time_front/core/error/result.dart';
import 'package:on_time_front/core/error/unit.dart';
import 'package:on_time_front/domain/use-cases/load_schedules_by_date_use_case.dart';

@Injectable()
class LoadSchedulesForMonthUseCase {
  final LoadSchedulesByDateUseCase _loadSchedulesByDateUseCase;

  LoadSchedulesForMonthUseCase(this._loadSchedulesByDateUseCase);

  Future<Result<Unit, Failure>> call(DateTime date) async {
    final startOfMonth = DateTime(date.year, date.month, 1);
    final endOfMonth = DateTime(date.year, date.month + 1, 0);

    return _loadSchedulesByDateUseCase(startOfMonth, endOfMonth);
  }
}
