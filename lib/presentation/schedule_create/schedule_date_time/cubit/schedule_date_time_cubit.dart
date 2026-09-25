import 'package:on_time_front/core/time/time_zone_rules.dart';
import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/logging/app_logger.dart';
import 'package:on_time_front/core/time/civil_time_resolver.dart';
import 'package:on_time_front/domain/use-cases/get_adjacent_schedules_with_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_adjacent_schedule_with_preparation_use_case.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form_bloc.dart';
import 'package:on_time_front/domain/entities/adjacent_schedules_with_preparation_entity.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_date_time/input_models/schedule_date_input_model.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_date_time/input_models/schedule_time_input_model.dart';
import 'package:on_time_front/presentation/shared/constants/constants.dart';

part 'schedule_date_time_state.dart';

@Injectable()
class ScheduleDateTimeCubit extends Cubit<ScheduleDateTimeState> {
  ScheduleDateTimeCubit(
    @factoryParam this.scheduleFormBloc,
    this._loadAdjacentSchedulesWithPreparationUseCase,
    this._getNextScheduleWithPreparationUseCase,
  ) : super(ScheduleDateTimeState());

  final ScheduleFormBloc scheduleFormBloc;
  final LoadAdjacentScheduleWithPreparationUseCase
  _loadAdjacentSchedulesWithPreparationUseCase;
  final GetAdjacentSchedulesWithPreparationUseCase
  _getNextScheduleWithPreparationUseCase;

  int _selectionVersion = 0;

  bool Function() _captureSelection({bool advance = false}) {
    if (advance) _selectionVersion++;
    final revision = _selectionVersion;
    final owner = scheduleFormBloc.formOwner;
    final mutation = scheduleFormBloc.state.mutationId;
    return () =>
        !isClosed &&
        revision == _selectionVersion &&
        scheduleFormBloc.ownsForm(owner) &&
        scheduleFormBloc.state.mutationId == mutation;
  }

  void initialize() {
    final current = _captureSelection(advance: true);
    final scheduleDateTimeState = ScheduleDateTimeState.fromScheduleFormState(
      scheduleFormBloc.state,
    );
    emit(
      state.copyWith(
        isRecurring: scheduleDateTimeState.isRecurring,
        scheduleDate: scheduleDateTimeState.scheduleDate,
        scheduleTime: scheduleDateTimeState.scheduleTime,
        timeZoneId: scheduleDateTimeState.timeZoneId,
        timeZoneExplicitlySelected:
            scheduleDateTimeState.timeZoneExplicitlySelected,
        selectedOccurrenceOffsetSeconds:
            scheduleDateTimeState.selectedOccurrenceOffsetSeconds,
      ),
    );
    _resolveCivilTime();

    // Check for schedule overlap if both date and time are valid
    if (scheduleDateTimeState.scheduleDate.isValid &&
        scheduleDateTimeState.scheduleTime.isValid) {
      scheduleFormBloc.add(ScheduleFormValidated(isValid: false));
      // Load adjacent schedules first, then check overlap
      _loadAdjacentSchedules(scheduleDateTimeState.scheduleDate.value!).then((
        _,
      ) {
        if (current()) checkScheduleOverlap();
      });
    } else {
      scheduleFormBloc.add(ScheduleFormValidated(isValid: state.isValid));
    }
  }

  Future<void> scheduleDateChanged(DateTime scheduleDate) async {
    final current = _captureSelection(advance: true);
    final ScheduleDateInputModel scheduleDateInputModel =
        ScheduleDateInputModel.dirty(scheduleDate);
    emit(
      state.copyWith(
        scheduleDate: scheduleDateInputModel,
        civilTimeResolved: false,
        occurrenceOffsetOptions: const [],
        selectedOccurrenceOffsetSeconds: null,
      ),
    );
    _resolveCivilTime();

    // Always load nextSchedule when date changes
    if (scheduleDateInputModel.isValid) {
      scheduleFormBloc.add(ScheduleFormValidated(isValid: false));
      await _loadAdjacentSchedules(scheduleDate);
      if (!current()) return;
    }

    // Check for schedule overlap if time is already set
    if (scheduleDateInputModel.isValid && state.scheduleTime.isValid) {
      await checkScheduleOverlap();
      if (!current()) return;
    }
    scheduleFormBloc.add(ScheduleFormValidated(isValid: state.isValid));
  }

  Future<void> scheduleTimeChanged(DateTime scheduleTime) async {
    final current = _captureSelection(advance: true);
    final ScheduleTimeInputModel scheduleTimeInputModel =
        ScheduleTimeInputModel.dirty(scheduleTime);
    emit(
      state.copyWith(
        scheduleTime: scheduleTimeInputModel,
        civilTimeResolved: false,
        occurrenceOffsetOptions: const [],
        selectedOccurrenceOffsetSeconds: null,
      ),
    );
    _resolveCivilTime();

    // Never load nextSchedule, only check overlap
    if (state.scheduleDate.isValid && scheduleTimeInputModel.isValid) {
      scheduleFormBloc.add(ScheduleFormValidated(isValid: false));
      await checkScheduleOverlap();
      if (!current()) return;
    }
    scheduleFormBloc.add(ScheduleFormValidated(isValid: state.isValid));
  }

  void setRecurring(bool enabled) {
    _selectionVersion++;
    emit(
      state.copyWith(
        isRecurring: enabled,
        clearOverlap: enabled,
        clearPreviousOverlap: enabled,
      ),
    );
    if (!enabled) {
      checkScheduleOverlap();
    }
    validateCurrentSelection();
  }

  void validateCurrentSelection() {
    scheduleFormBloc.add(ScheduleFormValidated(isValid: state.isValid));
  }

  void occurrenceOffsetSelected(int offsetSeconds) {
    if (!state.occurrenceOffsetOptions.contains(offsetSeconds)) return;
    _selectionVersion++;
    emit(state.copyWith(selectedOccurrenceOffsetSeconds: offsetSeconds));
    checkScheduleOverlap();
    scheduleFormBloc.add(ScheduleFormValidated(isValid: state.isValid));
  }

  Future<void> timeZoneSelected(String zone) async {
    if (!TimeZoneRules.contains(zone)) return;
    final current = _captureSelection(advance: true);
    emit(
      state.copyWith(
        timeZoneId: zone,
        timeZoneExplicitlySelected: true,
        selectedOccurrenceOffsetSeconds: null,
        civilTimeResolved: false,
        occurrenceOffsetOptions: const [],
        clearOverlap: true,
        clearPreviousOverlap: true,
      ),
    );
    _resolveCivilTime();
    await checkScheduleOverlap();
    if (current()) validateCurrentSelection();
  }

  void _resolveCivilTime() {
    final selected = state.selectedScheduleDateTime;
    if (selected == null || !TimeZoneRules.contains(state.timeZoneId)) {
      emit(
        state.copyWith(
          civilTimeResolved: false,
          occurrenceOffsetOptions: const [],
          selectedOccurrenceOffsetSeconds: null,
        ),
      );
      return;
    }

    final options = CivilTimeResolver.resolve(
      selected,
      state.timeZoneId,
    ).map((occurrence) => occurrence.offsetSeconds).toList();
    final existing = state.selectedOccurrenceOffsetSeconds;
    final selectedOffset = options.contains(existing)
        ? existing
        : (existing == null && options.length == 1 ? options.single : null);
    emit(
      state.copyWith(
        civilTimeResolved: true,
        occurrenceOffsetOptions: options,
        selectedOccurrenceOffsetSeconds: selectedOffset,
      ),
    );
  }

  Future<void> _loadAdjacentSchedules(DateTime scheduleDate) async {
    try {
      // Calculate date range: previous day, selected day, and next day
      // This matches the range used in checkScheduleOverlap
      final dateRange = _getDateRange(scheduleDate);
      final startDate = dateRange.startDate;
      final endDate = dateRange.endDate;

      // Load adjacent schedules from the encrypted local database.
      await _loadAdjacentSchedulesWithPreparationUseCase(
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      AppLogger.debug('Error loading adjacent schedules: $e');
    }
  }

  Future<void> checkScheduleOverlap() async {
    final current = _captureSelection();
    if (state.isRecurring) {
      emit(state.copyWith(clearOverlap: true, clearPreviousOverlap: true));
      validateCurrentSelection();
      return;
    }
    if (state.scheduleDate.value == null || state.scheduleTime.value == null) {
      scheduleFormBloc.add(ScheduleFormValidated(isValid: state.isValid));
      return;
    }

    emit(state.copyWith(clearOverlap: true, clearPreviousOverlap: true));

    try {
      // Combine date and time
      final selectedDate = state.scheduleDate.value!;
      final offset = state.selectedOccurrenceOffsetSeconds;
      if (offset == null) {
        validateCurrentSelection();
        return;
      }
      final selectedDateTime = CivilDateTime.fromFields(
        state.selectedScheduleDateTime!,
      ).atOffset(offset);

      // Get the current schedule form state to check if editing
      final formState = scheduleFormBloc.state;
      final currentScheduleId = formState.id;

      // Calculate date range: previous day, selected day, and next day
      // This matches the range used in _loadAdjacentSchedules
      final dateRange = _getDateRange(selectedDate);
      final startDate = dateRange.startDate;
      final endDate = dateRange.endDate;

      // Find adjacent schedules (previous and next) with preparation from stream
      AppLogger.debug(
        'Checking overlap for: $selectedDateTime, currentScheduleId: $currentScheduleId',
      );
      final AdjacentSchedulesWithPreparationEntity adjacentSchedules =
          await _getNextScheduleWithPreparationUseCase(
            selectedDateTime: selectedDateTime,
            currentScheduleId: currentScheduleId,
            startDate: startDate,
            endDate: endDate,
          );
      if (!current()) return;

      AppLogger.debug(
        'Previous schedule found: ${adjacentSchedules.hasPrevious}, Next schedule found: ${adjacentSchedules.hasNext}',
      );

      // Check overlap with next schedule
      if (adjacentSchedules.hasNext && adjacentSchedules.nextSchedule != null) {
        final nextSchedule = adjacentSchedules.nextSchedule!;

        // Calculate preparation start time for next schedule
        // preparationStartTime = scheduleTime - moveTime - preparation.totalDuration - scheduleSpareTime
        final nextPreparationStartTime = nextSchedule.preparationStartTime;

        // Calculate time difference
        final timeDifference = nextPreparationStartTime.difference(
          selectedDateTime,
        );
        final minutesDifference = timeDifference.inMinutes;

        AppLogger.debug(
          'Next schedule overlap check '
          'scheduleId=${nextSchedule.id} '
          'scheduleTime=${nextSchedule.scheduleTime} '
          'preparationStartTime=$nextPreparationStartTime '
          'moveMinutes=${nextSchedule.moveTime.inMinutes} '
          'preparationMinutes=${nextSchedule.preparation.totalDuration.inMinutes} '
          'spareMinutes=${nextSchedule.scheduleSpareTime?.inMinutes} '
          'selectedDateTime=$selectedDateTime '
          'minutesDifference=$minutesDifference',
        );

        // Show warning if positive time difference, error if already overlapping (<= 0)
        if (minutesDifference > 0) {
          AppLogger.debug('Showing warning with $minutesDifference minutes');
          // User requested to show only error when overlap, no warning for next schedule
          emit(state.copyWith(clearOverlap: true));
        } else {
          // Already overlapping - show as error
          AppLogger.debug(
            'Showing error - already overlapping (minutesDifference: $minutesDifference)',
          );
          emit(
            state.copyWith(
              isOverlapping: true,
              nextScheduleName: nextSchedule.scheduleName,
              nextPreparationStartTime: nextPreparationStartTime,
            ),
          );
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
        final previousScheduleEndTime = previousSchedule.occurrenceInstantUtc;

        // Calculate time difference
        // If negative, selected time is before previous schedule ends (overlapping)
        // If positive, selected time is after previous schedule ends (no overlap)
        final timeDifference = selectedDateTime.difference(
          previousScheduleEndTime,
        );
        final minutesDifference = timeDifference.inMinutes;

        AppLogger.debug(
          'Previous schedule overlap check '
          'scheduleId=${previousSchedule.id} '
          'scheduleTime=${previousSchedule.scheduleTime} '
          'totalMinutes=${previousSchedule.totalDuration.inMinutes} '
          'selectedDateTime=$selectedDateTime '
          'minutesDifference=$minutesDifference',
        );

        // If minutesDifference < 0, it means selected time is before previous ends (overlapping)
        // If minutesDifference >= 0, it means selected time is after previous ends (no overlap)
        if (minutesDifference < 0) {
          // Selected time is before previous schedule ends - overlapping
          // This case should theoretically not happen if we assume preparation is before schedule time and we are creating a new schedule
          // But if it does, we treat it as available time being negative?
          // Or just show it as available time (which will be negative)
          AppLogger.debug(
            'Showing error - overlapping with previous schedule (minutesDifference: $minutesDifference)',
          );
          emit(
            state.copyWith(
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
            ),
          );
        } else {
          // No overlap with previous schedule
          // Show warning only if available time is small (e.g., less than 3 hours)
          final isSmallTime =
              minutesDifference < scheduleOverlapWarningThresholdMinutes;

          if (isSmallTime) {
            AppLogger.debug(
              'Showing warning - small available time from previous schedule (minutesDifference: $minutesDifference)',
            );
            emit(
              state.copyWith(
                previousOverlapDuration: timeDifference,
                previousScheduleName: previousSchedule.scheduleName,
              ),
            );
          } else {
            AppLogger.debug(
              'Not showing warning - available time is large (minutesDifference: $minutesDifference)',
            );
            emit(
              state.copyWith(
                previousOverlapDuration: timeDifference,
                previousScheduleName: previousSchedule.scheduleName,
                // clearPreviousOverlap: true, // Do not clear if we want to keep the value
              ),
            );
          }
        }
      } else {
        // No previous schedule found, clear previous overlap
        emit(state.copyWith(clearPreviousOverlap: true));
      }
    } catch (e) {
      if (!current()) return;
      // Only the current selection can change its overlap state.
      AppLogger.debug('Error checking schedule overlap: $e');
      emit(state.copyWith(clearOverlap: true, clearPreviousOverlap: true));
    }

    scheduleFormBloc.add(ScheduleFormValidated(isValid: state.isValid));
  }

  bool scheduleDateTimeSubmitted() {
    if (state.isValid) {
      // If not overlapping, previousOverlapDuration holds the available time (if any)
      // If it is null, it means no previous schedule or cleared.
      // But wait, if we cleared it because it was large, we lost it?
      // In the previous step, I decided NOT to clear it if it is large, but just set it.
      // But then the warning would show.
      // I need to update ScheduleDateTimeState.hasPreviousOverlapMessage to only show if small.

      scheduleFormBloc.add(
        ScheduleFormScheduleDateTimeChanged(
          timeZoneId: state.timeZoneId,
          timeZoneExplicitlySelected: state.timeZoneExplicitlySelected,
          scheduleDate: state.scheduleDate.value!,
          scheduleTime: state.scheduleTime.value!,
          occurrenceOffsetSeconds: state.selectedOccurrenceOffsetSeconds ?? 0,
          maxAvailableTime: state.isRecurring
              ? null
              : state.previousOverlapDuration,
          previousScheduleName: state.isRecurring
              ? null
              : state.previousScheduleName,
        ),
      );
      return true;
    }

    scheduleFormBloc.add(ScheduleFormValidated(isValid: false));
    return false;
  }

  ({DateTime startDate, DateTime endDate}) _getDateRange(DateTime date) {
    final baseDate = DateTime.utc(date.year, date.month, date.day);
    return (
      startDate: baseDate.subtract(const Duration(days: 1)),
      endDate: baseDate.add(const Duration(days: 2)),
    );
  }
}
