import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/use-cases/get_schedules_by_date_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_schedules_by_date_use_case.dart';

@Injectable()
class LoadAdjacentScheduleWithPreparationUseCase {
  final LoadSchedulesByDateUseCase _loadSchedulesByDateUseCase;
  final GetSchedulesByDateUseCase _getSchedulesByDateUseCase;
  final LoadPreparationByScheduleIdUseCase _loadPreparationByScheduleIdUseCase;

  LoadAdjacentScheduleWithPreparationUseCase(
    this._loadSchedulesByDateUseCase,
    this._getSchedulesByDateUseCase,
    this._loadPreparationByScheduleIdUseCase,
  );

  /// Loads schedules and preparation data from the server for the given date range.
  /// This triggers fetching schedules and preparation from the remote data source
  /// and updating the local cache/stream.
  ///
  /// [startDate] - Start date for the search range
  /// [endDate] - End date for the search range
  Future<void> call({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // Load schedules for the date range
    await _loadSchedulesByDateUseCase(startDate, endDate);

    // Get the schedules that were loaded
    final schedules =
        await _getSchedulesByDateUseCase(startDate, endDate).first;

    // Load preparation for all schedules in the date range
    await Future.wait(
      schedules
          .map((schedule) => _loadPreparationByScheduleIdUseCase(schedule.id)),
    );
  }
}
