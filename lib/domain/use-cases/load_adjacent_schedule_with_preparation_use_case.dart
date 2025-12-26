import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/error/failures.dart';
import 'package:on_time_front/core/error/result.dart';
import 'package:on_time_front/core/error/unit.dart';
import 'package:collection/collection.dart';
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
  Future<Result<Unit, Failure>> call({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // Load schedules for the date range
    final loadSchedulesResult = await _loadSchedulesByDateUseCase(startDate, endDate);
    if (loadSchedulesResult.isFailure) return Err(loadSchedulesResult.failureOrNull!);

    // Get the schedules that were loaded
    final schedulesResult = await _getSchedulesByDateUseCase(startDate, endDate).first;
    if (schedulesResult.isFailure) return Err(schedulesResult.failureOrNull!);
    final schedules = schedulesResult.successOrNull ?? const [];

    // Load preparation for all schedules in the date range
    final loadPrepResults = await Future.wait(
      schedules.map((schedule) => _loadPreparationByScheduleIdUseCase(schedule.id)),
    );

    final firstFailure = loadPrepResults
        .where((r) => r.isFailure)
        .map((r) => r.failureOrNull)
        .whereType<Failure>()
        .firstOrNull;

    if (firstFailure != null) return Err(firstFailure);

    return Success(unit);
  }
}
