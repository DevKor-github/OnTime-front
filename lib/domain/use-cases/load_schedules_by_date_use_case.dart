import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/error/failures.dart';
import 'package:on_time_front/core/error/result.dart';
import 'package:on_time_front/core/error/unit.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';

@Injectable()
class LoadSchedulesByDateUseCase {
  final ScheduleRepository _scheduleRepository;

  LoadSchedulesByDateUseCase(this._scheduleRepository);

  /// Loads schedules for the given date range.
  /// This triggers fetching schedules from the remote data source
  /// and updating the local cache/stream.
  ///
  /// [startDate] - Start date of the range (inclusive)
  /// [endDate] - End date of the range (exclusive), or null for all schedules after startDate
  Future<Result<Unit, Failure>> call(DateTime startDate, DateTime? endDate) async {
    final result = await _scheduleRepository.getSchedulesByDate(startDate, endDate);
    return result.fold(
      onSuccess: (_) => Success(unit),
      onFailure: (f) => Err(f),
    );
  }
}
