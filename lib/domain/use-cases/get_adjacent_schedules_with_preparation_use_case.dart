import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/adjacent_schedules_with_preparation_entity.dart';
import 'package:on_time_front/domain/use-cases/get_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_schedules_by_date_use_case.dart';

@Injectable()
class GetAdjacentSchedulesWithPreparationUseCase {
  final GetSchedulesByDateUseCase _getSchedulesByDateUseCase;
  final GetPreparationByScheduleIdUseCase _getPreparationByScheduleIdUseCase;

  GetAdjacentSchedulesWithPreparationUseCase(
    this._getSchedulesByDateUseCase,
    this._getPreparationByScheduleIdUseCase,
  );

  /// Gets both the previous and next closest schedules relative to the given DateTime with preparation data from the stream.
  ///
  /// [selectedDateTime] - The date and time to search from
  /// [currentScheduleId] - Optional ID of the current schedule being edited (to exclude it)
  /// [startDate] - Start date for the search range
  /// [endDate] - End date for the search range
  ///
  /// Returns AdjacentSchedulesWithPreparationEntity containing both previous and next schedules (or null if not found).
  Future<AdjacentSchedulesWithPreparationEntity> call({
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

      // Filter schedules before selectedDateTime for previous schedule
      final previousSchedules = schedules.where((schedule) {
        final isNotCurrent = schedule.id != currentScheduleId;
        final isBeforeSelected =
            schedule.scheduleTime.isBefore(selectedDateTime);

        debugPrint(
            'Previous check - Schedule ${schedule.scheduleName}: scheduleTime=${schedule.scheduleTime}, selectedDateTime=$selectedDateTime');
        debugPrint(
            '  -> isNotCurrent=$isNotCurrent, isBeforeSelected=$isBeforeSelected');

        return isNotCurrent && isBeforeSelected;
      }).toList();

      debugPrint(
          'Filtered schedules count (next): ${filteredSchedules.length}');
      debugPrint(
          'Filtered schedules count (previous): ${previousSchedules.length}');
      debugPrint('================================');

      // Helper function to get preparation for a schedule
      // For overlap checking, we use the canonical preparation from the stream
      // (not locally stored timed preparations which are for tracking progress)
      Future<ScheduleWithPreparationEntity?> getScheduleWithPreparation(
          schedule) async {
        try {
          // Try to get preparation from stream with a longer timeout
          // Preparations should have been loaded by LoadAdjacentScheduleWithPreparationUseCase
          final preparationEntity =
              await _getPreparationByScheduleIdUseCase(schedule.id).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException(
                'Preparation not found in stream for schedule ${schedule.id} after 10 seconds. '
                'It may not have been loaded yet.',
              );
            },
          );
          final preparation =
              PreparationWithTimeEntity.fromPreparation(preparationEntity);

          // Create ScheduleWithPreparationEntity
          return ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
            schedule,
            preparation,
          );
        } catch (e) {
          // If preparation is not in stream, return null
          // This can happen if the preparation hasn't been loaded yet or doesn't exist
          debugPrint(
              'Preparation not found in stream for schedule ${schedule.id}: $e');
          return null;
        }
      }

      // Get next schedule
      ScheduleWithPreparationEntity? nextSchedule;
      if (filteredSchedules.isNotEmpty) {
        // Sort by scheduleTime and get the first one (closest)
        filteredSchedules
            .sort((a, b) => a.scheduleTime.compareTo(b.scheduleTime));
        nextSchedule =
            await getScheduleWithPreparation(filteredSchedules.first);
      }

      // Get previous schedule
      ScheduleWithPreparationEntity? previousSchedule;
      if (previousSchedules.isNotEmpty) {
        // Sort by scheduleTime descending and get the first one (closest before)
        previousSchedules
            .sort((a, b) => b.scheduleTime.compareTo(a.scheduleTime));
        previousSchedule =
            await getScheduleWithPreparation(previousSchedules.first);
      }

      return AdjacentSchedulesWithPreparationEntity(
        previousSchedule: previousSchedule,
        nextSchedule: nextSchedule,
      );
    } catch (e) {
      // On error, return empty result
      debugPrint('Error in GetNextScheduleWithPreparationUseCase: $e');
      return const AdjacentSchedulesWithPreparationEntity();
    }
  }
}
