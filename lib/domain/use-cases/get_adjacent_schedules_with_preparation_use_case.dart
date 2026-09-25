import 'package:on_time_front/core/time/schedule_time_resolution.dart';
import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/logging/app_logger.dart';
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
  /// [selectedDateTime] - The selected UTC occurrence instant to search from
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
      final loaded = await _getSchedulesByDateUseCase(
        CivilDateTime.fromFields(
          startDate,
        ).toUtcCarrier().subtract(const Duration(days: 2)),
        CivilDateTime.fromFields(
          endDate,
        ).toUtcCarrier().add(const Duration(days: 2)),
      ).first;
      final now = DateTime.now().toUtc();
      final schedules = <ScheduleEntity>[];
      final instants = <String, DateTime>{};
      final resolutions = <String, ScheduleTimeResolution>{};
      for (final value in loaded) {
        if (value.retainedRecurringReference) continue;
        final time = ScheduleTimeResolver.resolve(value, nowUtc: now);
        if (time.instantUtc == null) continue;
        schedules.add(value);
        instants[value.id] = time.instantUtc!;
        resolutions[value.id] = time;
      }

      AppLogger.debug(
        'Schedule filtering selectedDateTime=$selectedDateTime '
        'currentScheduleId=$currentScheduleId '
        'startDate=$startDate endDate=$endDate '
        'totalSchedules=${schedules.length}',
      );

      // Filter out the current schedule if editing, and find the next one after selectedDateTime
      // Note: We check all schedules in the future, regardless of doneStatus,
      // because we want to warn about overlaps even with completed schedules
      final filteredSchedules = schedules.where((schedule) {
        final isNotCurrent = schedule.id != currentScheduleId;
        final isAfterSelected = !instants[schedule.id]!.isBefore(
          selectedDateTime.toUtc(),
        );
        final timeComparison = instants[schedule.id]!.compareTo(
          selectedDateTime,
        );

        AppLogger.debug(
          'Next schedule filter scheduleId=${schedule.id} '
          'scheduleTime=${schedule.scheduleTime} '
          'selectedDateTime=$selectedDateTime '
          'isNotCurrent=$isNotCurrent isAfterSelected=$isAfterSelected '
          'compareTo=$timeComparison doneStatus=${schedule.doneStatus}',
        );

        return isNotCurrent && isAfterSelected;
      }).toList();

      // Filter schedules before selectedDateTime for previous schedule
      final previousSchedules = schedules.where((schedule) {
        final isNotCurrent = schedule.id != currentScheduleId;
        final isBeforeSelected = instants[schedule.id]!.isBefore(
          selectedDateTime,
        );

        AppLogger.debug(
          'Previous schedule filter scheduleId=${schedule.id} '
          'scheduleTime=${schedule.scheduleTime} '
          'selectedDateTime=$selectedDateTime '
          'isNotCurrent=$isNotCurrent isBeforeSelected=$isBeforeSelected',
        );

        return isNotCurrent && isBeforeSelected;
      }).toList();

      AppLogger.debug(
        'Filtered schedules nextCount=${filteredSchedules.length} '
        'previousCount=${previousSchedules.length}',
      );

      // Helper function to get preparation for a schedule
      // For overlap checking, we use the canonical preparation from the stream
      // (not locally stored timed preparations which are for tracking progress)
      Future<ScheduleWithPreparationEntity?> getScheduleWithPreparation(
        schedule,
      ) async {
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
          final preparation = PreparationWithTimeEntity.fromPreparation(
            preparationEntity,
          );

          // Create ScheduleWithPreparationEntity
          return ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
            schedule,
            preparation,
            timeResolution: resolutions[schedule.id]!,
          );
        } catch (e) {
          // If preparation is not in stream, return null
          // This can happen if the preparation hasn't been loaded yet or doesn't exist
          AppLogger.debug(
            'Preparation not found in stream for schedule ${schedule.id}: $e',
          );
          return null;
        }
      }

      // Get next schedule
      ScheduleWithPreparationEntity? nextSchedule;
      if (filteredSchedules.isNotEmpty) {
        // Sort by scheduleTime and get the first one (closest)
        filteredSchedules.sort(
          (a, b) => instants[a.id]!.compareTo(instants[b.id]!),
        );
        nextSchedule = await getScheduleWithPreparation(
          filteredSchedules.first,
        );
      }

      // Get previous schedule
      ScheduleWithPreparationEntity? previousSchedule;
      if (previousSchedules.isNotEmpty) {
        // Sort by scheduleTime descending and get the first one (closest before)
        previousSchedules.sort(
          (a, b) => instants[b.id]!.compareTo(instants[a.id]!),
        );
        previousSchedule = await getScheduleWithPreparation(
          previousSchedules.first,
        );
      }

      return AdjacentSchedulesWithPreparationEntity(
        previousSchedule: previousSchedule,
        nextSchedule: nextSchedule,
      );
    } catch (e) {
      // On error, return empty result
      AppLogger.debug('Error in GetNextScheduleWithPreparationUseCase: $e');
      return const AdjacentSchedulesWithPreparationEntity();
    }
  }
}
