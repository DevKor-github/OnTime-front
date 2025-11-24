import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/repositories/timed_preparation_repository.dart';
import 'package:on_time_front/domain/use-cases/get_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_schedules_by_date_use_case.dart';

@Injectable()
class GetNextScheduleWithPreparationUseCase {
  final GetSchedulesByDateUseCase _getSchedulesByDateUseCase;
  final GetPreparationByScheduleIdUseCase _getPreparationByScheduleIdUseCase;
  final TimedPreparationRepository _timedPreparationRepository;

  GetNextScheduleWithPreparationUseCase(
    this._getSchedulesByDateUseCase,
    this._getPreparationByScheduleIdUseCase,
    this._timedPreparationRepository,
  );

  /// Gets the next closest schedule after the given DateTime with preparation data from the stream.
  ///
  /// [selectedDateTime] - The date and time to search from
  /// [currentScheduleId] - Optional ID of the current schedule being edited (to exclude it)
  /// [startDate] - Start date for the search range
  /// [endDate] - End date for the search range
  ///
  /// Returns the next ScheduleWithPreparationEntity, or null if none found.
  Future<ScheduleWithPreparationEntity?> call({
    required DateTime selectedDateTime,
    String? currentScheduleId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      // Get schedules from the stream
      final schedules =
          await _getSchedulesByDateUseCase(startDate, endDate).first;

      debugPrint('=== Schedule Filtering Debug ===');
      debugPrint('Selected datetime: $selectedDateTime');
      debugPrint('Current schedule ID (to exclude): $currentScheduleId');
      debugPrint('Date range: $startDate to $endDate');
      debugPrint('Total schedules found: ${schedules.length}');

      for (final schedule in schedules) {
        debugPrint(
            'Schedule: ${schedule.scheduleName} at ${schedule.scheduleTime}, doneStatus: ${schedule.doneStatus}, id: ${schedule.id}');
      }

      // Filter out the current schedule if editing, and find the next one after selectedDateTime
      // Note: We check all schedules in the future, regardless of doneStatus,
      // because we want to warn about overlaps even with completed schedules
      final filteredSchedules = schedules.where((schedule) {
        final isNotCurrent = schedule.id != currentScheduleId;
        final isAfterSelected = schedule.scheduleTime.isAfter(selectedDateTime);
        final timeComparison =
            schedule.scheduleTime.compareTo(selectedDateTime);

        debugPrint(
            'Schedule ${schedule.scheduleName}: scheduleTime=${schedule.scheduleTime}, selectedDateTime=$selectedDateTime');
        debugPrint(
            '  -> isNotCurrent=$isNotCurrent, isAfterSelected=$isAfterSelected, compareTo=$timeComparison (1=after, 0=same, -1=before), doneStatus=${schedule.doneStatus}');

        return isNotCurrent && isAfterSelected;
      }).toList();

      debugPrint('Filtered schedules count: ${filteredSchedules.length}');
      if (filteredSchedules.isEmpty) {
        debugPrint(
            'No schedules found after selected time - no overlap warning needed');
      }
      debugPrint('================================');

      if (filteredSchedules.isEmpty) {
        return null;
      }

      // Sort by scheduleTime and get the first one (closest)
      filteredSchedules
          .sort((a, b) => a.scheduleTime.compareTo(b.scheduleTime));
      final nextSchedule = filteredSchedules.first;

      // Get preparation data for the next schedule
      PreparationWithTimeEntity preparation;

      // First try to load locally stored timed preparation
      final localTimed = await _timedPreparationRepository
          .getTimedPreparation(nextSchedule.id);

      if (localTimed != null) {
        preparation = localTimed;
      } else {
        // Fallback to getting canonical preparation from stream
        // Note: Preparation should be loaded before calling this use case
        try {
          final preparationEntity =
              await _getPreparationByScheduleIdUseCase(nextSchedule.id).timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw TimeoutException(
                'Preparation not found in stream for schedule ${nextSchedule.id}',
              );
            },
          );
          preparation =
              PreparationWithTimeEntity.fromPreparation(preparationEntity);
        } catch (e) {
          // If preparation is not in stream, return null
          debugPrint(
              'Preparation not found in stream for schedule ${nextSchedule.id}: $e');
          return null;
        }
      }

      // Create ScheduleWithPreparationEntity
      return ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
        nextSchedule,
        preparation,
      );
    } catch (e) {
      // On error, return null
      return null;
    }
  }
}
