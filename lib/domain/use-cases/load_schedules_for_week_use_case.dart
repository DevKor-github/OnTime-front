import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/error/failures.dart';
import 'package:on_time_front/core/error/result.dart';
import 'package:on_time_front/core/error/unit.dart';
import 'package:on_time_front/domain/use-cases/load_schedules_by_date_use_case.dart';

@Injectable()
class LoadSchedulesForWeekUseCase {
  final LoadSchedulesByDateUseCase _loadSchedulesByDateUseCase;

  LoadSchedulesForWeekUseCase(this._loadSchedulesByDateUseCase);

  Future<Result<Unit, Failure>> call(DateTime date) async {
    final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
    final endOfWeek = startOfWeek.add(Duration(days: 7));

    return _loadSchedulesByDateUseCase(startOfWeek, endOfWeek);
  }
}
