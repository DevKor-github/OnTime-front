import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/use-cases/load_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_schedules_by_date_use_case.dart';

@Injectable()
class LoadNextScheduleWithPreparationUseCase {
  final LoadSchedulesByDateUseCase _loadSchedulesByDateUseCase;
  final LoadPreparationByScheduleIdUseCase _loadPreparationByScheduleIdUseCase;

  LoadNextScheduleWithPreparationUseCase(
    this._loadSchedulesByDateUseCase,
    this._loadPreparationByScheduleIdUseCase,
  );

  /// Loads schedules and preparation data from the server for the given date range.
  /// This triggers fetching schedules and preparation from the remote data source
  /// and updating the local cache/stream.
  ///
  /// [startDate] - Start date for the search range
  /// [endDate] - End date for the search range
  /// [scheduleId] - Optional schedule ID to load preparation for
  Future<void> call({
    required DateTime startDate,
    required DateTime endDate,
    String? scheduleId,
  }) async {
    // Load schedules for the date range
    await _loadSchedulesByDateUseCase(startDate, endDate);

    // Load preparation for the specific schedule if provided
    if (scheduleId != null) {
      await _loadPreparationByScheduleIdUseCase(scheduleId);
    }
  }
}

