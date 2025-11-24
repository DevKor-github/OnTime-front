import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/use-cases/get_next_schedule_with_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_next_schedule_with_preparation_use_case.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_date_time/input_models/schedule_date_input_model.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_date_time/input_models/schedule_time_input_model.dart';

part 'schedule_date_time_state.dart';

@Injectable()
class ScheduleDateTimeCubit extends Cubit<ScheduleDateTimeState> {
  ScheduleDateTimeCubit(
    @factoryParam this.scheduleFormBloc,
    this._loadNextScheduleWithPreparationUseCase,
    this._getNextScheduleWithPreparationUseCase,
  ) : super(ScheduleDateTimeState()) {
    initialize();
  }

  final ScheduleFormBloc scheduleFormBloc;
  final LoadNextScheduleWithPreparationUseCase
      _loadNextScheduleWithPreparationUseCase;
  final GetNextScheduleWithPreparationUseCase
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
      await _loadNextSchedule(scheduleDate);
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

  Future<void> _loadNextSchedule(DateTime scheduleDate) async {
    try {
      // Calculate date range: selected day and next day
      final startDate =
          DateTime(scheduleDate.year, scheduleDate.month, scheduleDate.day);
      final endDate = startDate.add(const Duration(days: 2));

      // Load schedules from server
      await _loadNextScheduleWithPreparationUseCase(
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      debugPrint('Error loading next schedule: $e');
    }
  }

  Future<void> checkScheduleOverlap() async {
    if (state.scheduleDate.value == null || state.scheduleTime.value == null) {
      return;
    }

    emit(state.copyWith(clearOverlap: true));

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

      // Calculate date range: selected day and next day
      final startDate =
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      final endDate = startDate.add(const Duration(days: 2));

      // Find next schedule with preparation from stream (no loading, already loaded)
      debugPrint(
          'Checking overlap for: $selectedDateTime, currentScheduleId: $currentScheduleId');
      final nextSchedule = await _getNextScheduleWithPreparationUseCase(
        selectedDateTime: selectedDateTime,
        currentScheduleId: currentScheduleId,
        startDate: startDate,
        endDate: endDate,
      );

      debugPrint('Next schedule found: ${nextSchedule != null}');
      if (nextSchedule == null) {
        emit(state.copyWith(clearOverlap: true));
        return;
      }

      // Calculate preparation start time for next schedule
      // preparationStartTime = scheduleTime - moveTime - preparation.totalDuration - scheduleSpareTime
      final nextPreparationStartTime = nextSchedule.preparationStartTime;

      // Calculate time difference
      final timeDifference =
          nextPreparationStartTime.difference(selectedDateTime);
      final minutesDifference = timeDifference.inMinutes;

      debugPrint('=== Schedule Overlap Debug ===');
      debugPrint('Next schedule name: ${nextSchedule.scheduleName}');
      debugPrint('Next schedule time: ${nextSchedule.scheduleTime}');
      debugPrint(
          'Next schedule preparation start time: $nextPreparationStartTime');
      debugPrint('Next schedule moveTime: ${nextSchedule.moveTime}');
      debugPrint(
          'Next schedule preparation totalDuration: ${nextSchedule.preparation.totalDuration}');
      debugPrint('Next schedule spareTime: ${nextSchedule.scheduleSpareTime}');
      debugPrint('Selected datetime: $selectedDateTime');
      debugPrint('Time difference: $timeDifference');
      debugPrint('Minutes difference: $minutesDifference');
      debugPrint('=============================');

      // Show warning if positive time difference, error if already overlapping (<= 0)
      // Store timeDifference (can be positive for warning or negative/zero for error)
      // and isOverlapping flag (true if <= 0, false if > 0)
      if (minutesDifference > 0) {
        debugPrint('Showing warning with $minutesDifference minutes');
        emit(state.copyWith(
          overlapDuration: timeDifference,
          isOverlapping: false,
          nextScheduleName: nextSchedule.scheduleName,
        ));
      } else {
        // Already overlapping - show as error
        // Store absolute value for display purposes, but keep the sign information in isOverlapping
        debugPrint(
            'Showing error - already overlapping (minutesDifference: $minutesDifference)');
        emit(state.copyWith(
          overlapDuration: timeDifference.abs(),
          isOverlapping: true,
          nextScheduleName: nextSchedule.scheduleName,
        ));
      }
    } catch (e) {
      // On error, clear overlap
      debugPrint('Error checking schedule overlap: $e');
      emit(state.copyWith(clearOverlap: true));
    }
  }

  void scheduleDateTimeSubmitted() {
    if (state.scheduleDate.isValid &&
        state.scheduleTime.isValid &&
        state.isOverlapping == false) {
      scheduleFormBloc.add(ScheduleFormScheduleDateTimeChanged(
        scheduleDate: state.scheduleDate.value!,
        scheduleTime: state.scheduleTime.value!,
        timeLeftUntilNextSchedulePreparation: state.overlapDuration,
        nextScheduleName: state.nextScheduleName,
      ));
    }
  }
}
