import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/use-cases/get_adjacent_schedules_with_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_adjacent_schedule_with_preparation_use_case.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_date_time/input_models/schedule_date_input_model.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_date_time/input_models/schedule_time_input_model.dart';
import 'package:on_time_front/domain/entities/adjacent_schedules_with_preparation_entity.dart';
import 'package:on_time_front/presentation/shared/constants/constants.dart';

part 'schedule_date_time_state.dart';

@Injectable()
class ScheduleDateTimeCubit extends Cubit<ScheduleDateTimeState> {
  ScheduleDateTimeCubit(
    @factoryParam this.scheduleFormBloc,
    this._loadAdjacentSchedulesWithPreparationUseCase,
    this._getNextScheduleWithPreparationUseCase,
  ) : super(ScheduleDateTimeState()) {
    initialize();
  }

  final ScheduleFormBloc scheduleFormBloc;
  final LoadAdjacentScheduleWithPreparationUseCase
      _loadAdjacentSchedulesWithPreparationUseCase;
  final GetAdjacentSchedulesWithPreparationUseCase
      _getNextScheduleWithPreparationUseCase;

  void initialize() {
    final scheduleDateTimeState =
        ScheduleDateTimeState.fromScheduleFormState(scheduleFormBloc.state);
    emit(state.copyWith(
      scheduleDate: scheduleDateTimeState.scheduleDate,
      scheduleTime: scheduleDateTimeState.scheduleTime,
    ));
    scheduleFormBloc.add(ScheduleFormValidated(isValid: state.isValid));
  }

  Future<void> scheduleDateChanged(DateTime scheduleDate) async {
    final ScheduleDateInputModel scheduleDateInputModel =
        ScheduleDateInputModel.dirty(scheduleDate);
    emit(state.copyWith(scheduleDate: scheduleDateInputModel));

    // Always load nextSchedule when date changes
    if (scheduleDateInputModel.isValid) {
      scheduleFormBloc.add(ScheduleFormValidated(isValid: false));
      await _loadAdjacentSchedules(scheduleDate);
    }

    // Check for schedule overlap if time is already set
    if (scheduleDateInputModel.isValid && state.scheduleTime.isValid) {
      await checkScheduleOverlap();
    }
    scheduleFormBloc.add(ScheduleFormValidated(isValid: state.isValid));
  }

  Future<void> scheduleTimeChanged(DateTime scheduleTime) async {
    final ScheduleTimeInputModel scheduleTimeInputModel =
        ScheduleTimeInputModel.dirty(scheduleTime);
    emit(state.copyWith(scheduleTime: scheduleTimeInputModel));

    // Never load nextSchedule, only check overlap
    if (state.scheduleDate.isValid && scheduleTimeInputModel.isValid) {
      await checkScheduleOverlap();
    }
    scheduleFormBloc.add(ScheduleFormValidated(isValid: state.isValid));
  }

  Future<void> _loadAdjacentSchedules(DateTime scheduleDate) async {
    try {
      // Calculate date range: previous day, selected day, and next day
      // This matches the range used in checkScheduleOverlap
      final dateRange = _getDateRange(scheduleDate);
      final startDate = dateRange.startDate;
      final endDate = dateRange.endDate;

      // Load schedules from server
      await _loadAdjacentSchedulesWithPreparationUseCase(
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      debugPrint('Error loading adjacent schedules: $e');
    }
  }

  Future<void> checkScheduleOverlap() async {
    if (state.scheduleDate.value == null || state.scheduleTime.value == null) {
      return;
    }

    emit(state.copyWith(clearOverlap: true, clearPreviousOverlap: true));

    try {
      // Combine date and time
      final selectedDate = state.scheduleDate.value!;
      final selectedTime = state.scheduleTime.value!;
      final selectedDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );

      // Get the current schedule form state to check if editing
      final formState = scheduleFormBloc.state;
      final currentScheduleId = formState.id;

      // Calculate date range: previous day, selected day, and next day
      // This matches the range used in _loadAdjacentSchedules
      final dateRange = _getDateRange(selectedDate);
      final startDate = dateRange.startDate;
      final endDate = dateRange.endDate;

      // Find adjacent schedules (previous and next) with preparation from stream
      debugPrint(
          'Checking overlap for: $selectedDateTime, currentScheduleId: $currentScheduleId');
      final AdjacentSchedulesWithPreparationEntity adjacentSchedules =
          await _getNextScheduleWithPreparationUseCase(
        selectedDateTime: selectedDateTime,
        currentScheduleId: currentScheduleId,
        startDate: startDate,
        endDate: endDate,
      );

      debugPrint(
          'Previous schedule found: ${adjacentSchedules.hasPrevious}, Next schedule found: ${adjacentSchedules.hasNext}');

      // Check overlap with next schedule
      if (adjacentSchedules.hasNext && adjacentSchedules.nextSchedule != null) {
        final nextSchedule = adjacentSchedules.nextSchedule!;

        // Calculate preparation start time for next schedule
        // preparationStartTime = scheduleTime - moveTime - preparation.totalDuration - scheduleSpareTime
        final nextPreparationStartTime = nextSchedule.preparationStartTime;

        // Calculate time difference
        final timeDifference =
            nextPreparationStartTime.difference(selectedDateTime);
        final minutesDifference = timeDifference.inMinutes;

        debugPrint('=== Next Schedule Overlap Debug ===');
        debugPrint('Next schedule name: ${nextSchedule.scheduleName}');
        debugPrint('Next schedule time: ${nextSchedule.scheduleTime}');
        debugPrint(
            'Next schedule preparation start time: $nextPreparationStartTime');
        debugPrint('Next schedule moveTime: ${nextSchedule.moveTime}');
        debugPrint(
            'Next schedule preparation totalDuration: ${nextSchedule.preparation.totalDuration}');
        debugPrint(
            'Next schedule spareTime: ${nextSchedule.scheduleSpareTime}');
        debugPrint('Selected datetime: $selectedDateTime');
        debugPrint('Time difference: $timeDifference');
        debugPrint('Minutes difference: $minutesDifference');
        debugPrint('===================================');

        // Show warning if positive time difference, error if already overlapping (<= 0)
        if (minutesDifference > 0) {
          debugPrint('Showing warning with $minutesDifference minutes');
          // User requested to show only error when overlap, no warning for next schedule
          emit(state.copyWith(
            clearOverlap: true,
          ));
        } else {
          // Already overlapping - show as error
          debugPrint(
              'Showing error - already overlapping (minutesDifference: $minutesDifference)');
          emit(state.copyWith(
            isOverlapping: true,
            nextScheduleName: nextSchedule.scheduleName,
            nextPreparationStartTime: nextPreparationStartTime,
          ));
        }
      } else {
        // No next schedule found, clear next overlap
        emit(state.copyWith(clearOverlap: true));
      }

      // Check overlap with previous schedule
      if (adjacentSchedules.hasPrevious &&
          adjacentSchedules.previousSchedule != null) {
        final previousSchedule = adjacentSchedules.previousSchedule!;

        // Calculate when previous schedule ends
        // Previous schedule ends at: scheduleTime (since preparation is before schedule time)
        final previousScheduleEndTime = previousSchedule.scheduleTime;

        // Calculate time difference
        // If negative, selected time is before previous schedule ends (overlapping)
        // If positive, selected time is after previous schedule ends (no overlap)
        final timeDifference =
            selectedDateTime.difference(previousScheduleEndTime);
        final minutesDifference = timeDifference.inMinutes;

        debugPrint('=== Previous Schedule Overlap Debug ===');
        debugPrint('Previous schedule name: ${previousSchedule.scheduleName}');
        debugPrint('Previous schedule time: ${previousSchedule.scheduleTime}');
        debugPrint(
            'Previous schedule totalDuration: ${previousSchedule.totalDuration}');
        debugPrint('Previous schedule end time: $previousScheduleEndTime');
        debugPrint('Selected datetime: $selectedDateTime');
        debugPrint('Time difference: $timeDifference');
        debugPrint('Minutes difference: $minutesDifference');
        debugPrint('======================================');

        // If minutesDifference < 0, it means selected time is before previous ends (overlapping)
        // If minutesDifference >= 0, it means selected time is after previous ends (no overlap)
        if (minutesDifference < 0) {
          // Selected time is before previous schedule ends - overlapping
          // This case should theoretically not happen if we assume preparation is before schedule time and we are creating a new schedule
          // But if it does, we treat it as available time being negative?
          // Or just show it as available time (which will be negative)
          debugPrint(
              'Showing error - overlapping with previous schedule (minutesDifference: $minutesDifference)');
          emit(state.copyWith(
            previousOverlapDuration:
                timeDifference, // Keep negative duration? Or abs?
            // If we remove isPreviousOverlapping, we just store the duration.
            // The state will decide if it's a warning based on duration value.
            // But wait, hasPreviousOverlapMessage logic:
            // return previousOverlapDuration!.inMinutes < 180;
            // If negative, it is < 180, so it returns true (warning).
            // But negative means overlap, which should be error?
            // The user said "impossible to overlap with previous schedule".
            // So we assume minutesDifference >= 0 always?
            // If so, we just handle the >= 0 case.
            previousScheduleName: previousSchedule.scheduleName,
          ));
        } else {
          // No overlap with previous schedule
          // Show warning only if available time is small (e.g., less than 3 hours)
          final isSmallTime =
              minutesDifference < scheduleOverlapWarningThresholdMinutes;

          if (isSmallTime) {
            debugPrint(
                'Showing warning - small available time from previous schedule (minutesDifference: $minutesDifference)');
            emit(state.copyWith(
              previousOverlapDuration: timeDifference,
              previousScheduleName: previousSchedule.scheduleName,
            ));
          } else {
            debugPrint(
                'Not showing warning - available time is large (minutesDifference: $minutesDifference)');
            emit(state.copyWith(
              previousOverlapDuration: timeDifference,
              previousScheduleName: previousSchedule.scheduleName,
              // clearPreviousOverlap: true, // Do not clear if we want to keep the value
            ));
          }
        }
      } else {
        // No previous schedule found, clear previous overlap
        emit(state.copyWith(
          clearPreviousOverlap: true,
        ));
      }
    } catch (e) {
      // On error, clear both overlaps
      debugPrint('Error checking schedule overlap: $e');
      emit(state.copyWith(clearOverlap: true, clearPreviousOverlap: true));
    }
  }

  void scheduleDateTimeSubmitted() {
    if (state.scheduleDate.isValid &&
        state.scheduleTime.isValid &&
        state.isOverlapping == false) {
      // If not overlapping, previousOverlapDuration holds the available time (if any)
      // If it is null, it means no previous schedule or cleared.
      // But wait, if we cleared it because it was large, we lost it?
      // In the previous step, I decided NOT to clear it if it is large, but just set it.
      // But then the warning would show.
      // I need to update ScheduleDateTimeState.hasPreviousOverlapMessage to only show if small.

      scheduleFormBloc.add(ScheduleFormScheduleDateTimeChanged(
        scheduleDate: state.scheduleDate.value!,
        scheduleTime: state.scheduleTime.value!,
        maxAvailableTime: state.previousOverlapDuration,
        previousScheduleName: state.previousScheduleName,
      ));
    }
  }

  ({DateTime startDate, DateTime endDate}) _getDateRange(DateTime date) {
    final baseDate = DateTime(date.year, date.month, date.day);
    return (
      startDate: baseDate.subtract(const Duration(days: 1)),
      endDate: baseDate.add(const Duration(days: 2)),
    );
  }
}
