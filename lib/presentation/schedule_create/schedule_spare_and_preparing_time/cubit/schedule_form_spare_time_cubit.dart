import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/input_models/schedule_spare_time_input_model.dart';
import 'package:on_time_front/presentation/shared/constants/constants.dart';

part 'schedule_form_spare_time_state.dart';

class ScheduleFormSpareTimeCubit extends Cubit<ScheduleFormSpareTimeState> {
  ScheduleFormSpareTimeCubit({
    required this.scheduleFormBloc,
  }) : super(ScheduleFormSpareTimeState());

  final ScheduleFormBloc scheduleFormBloc;

  /// Checks for schedule overlap and returns overlap duration and overlapping status
  /// Returns null overlapDuration if no overlap check is needed
  ({Duration? overlapDuration, bool isOverlapping}) _checkOverlap({
    required Duration totalPreparationTime,
    required Duration? moveTime,
    required Duration? spareTime,
  }) {
    final formState = scheduleFormBloc.state;
    final maxAvailableTime = formState.maxAvailableTime;

    if (maxAvailableTime == null ||
        formState.scheduleTime == null ||
        moveTime == null ||
        spareTime == null) {
      return (overlapDuration: null, isOverlapping: false);
    }

    // Calculate new time left: if preparationTime increases, time left decreases
    final newTimeLeft =
        maxAvailableTime - totalPreparationTime - moveTime - spareTime;
    final minutesDifference = newTimeLeft.inMinutes;

    if (minutesDifference <= 0) {
      // Already overlapping - show as error
      return (
        overlapDuration: newTimeLeft.abs(),
        isOverlapping: true,
      );
    } else if (minutesDifference < scheduleOverlapWarningThresholdMinutes) {
      // Show warning if there's still time left
      return (
        overlapDuration: newTimeLeft,
        isOverlapping: false,
      );
    } else {
      return (
        overlapDuration: null,
        isOverlapping: false,
      );
    }
  }

  void initialize() {
    final schedulePlaceMovingTimeState =
        ScheduleFormSpareTimeState.fromScheduleFormState(
            scheduleFormBloc.state);

    final formState = scheduleFormBloc.state;
    final overlapCheck = _checkOverlap(
      totalPreparationTime: schedulePlaceMovingTimeState.totalPreparationTime,
      moveTime: formState.moveTime,
      spareTime: schedulePlaceMovingTimeState.spareTime.value,
    );

    emit(state.copyWith(
      spareTime: schedulePlaceMovingTimeState.spareTime,
      preparation: schedulePlaceMovingTimeState.preparation,
      totalPreparationTime: schedulePlaceMovingTimeState.totalPreparationTime,
      overlapDuration: overlapCheck.overlapDuration,
      isOverlapping: overlapCheck.isOverlapping,
      clearOverlap: overlapCheck.overlapDuration == null,
    ));
    scheduleFormBloc.add(ScheduleFormValidated(isValid: state.isValid));
  }

  void spareTimeChanged(Duration value) {
    final spareTime = ScheduleSpareTimeInputModel.dirty(value);

    // Check for overlap using current form state values
    final formState = scheduleFormBloc.state;
    final overlapCheck = _checkOverlap(
      totalPreparationTime: formState.totalPreparationTime,
      moveTime: formState.moveTime,
      spareTime: value,
    );

    emit(state.copyWith(
      spareTime: spareTime,
      overlapDuration: overlapCheck.overlapDuration,
      isOverlapping: overlapCheck.isOverlapping,
      clearOverlap: overlapCheck.overlapDuration == null,
    ));

    scheduleFormBloc.add(ScheduleFormValidated(isValid: state.isValid));
  }

  void scheduleSpareTimeSubmitted() {
    if (state.spareTime.isValid && state.spareTime.value != null) {
      scheduleFormBloc.add(ScheduleFormScheduleSpareTimeChanged(
        scheduleSpareTime: state.spareTime.value!,
      ));
    }
    if (state.preparation != null) {
      scheduleFormBloc.add(ScheduleFormPreparationChanged(
        preparation: state.preparation!,
      ));
    }
  }

  void preparationChanged(PreparationEntity preparation) {
    final totalPreparationTime = preparation.totalDuration;

    // Check for overlap using current form state values
    final formState = scheduleFormBloc.state;
    final spareTime = state.spareTime.value ?? formState.scheduleSpareTime;
    final overlapCheck = _checkOverlap(
      totalPreparationTime: totalPreparationTime,
      moveTime: formState.moveTime,
      spareTime: spareTime,
    );

    emit(state.copyWith(
      preparation: preparation,
      totalPreparationTime: totalPreparationTime,
      overlapDuration: overlapCheck.overlapDuration,
      isOverlapping: overlapCheck.isOverlapping,
      clearOverlap: overlapCheck.overlapDuration == null,
    ));

    scheduleFormBloc.add(ScheduleFormValidated(isValid: state.isValid));
  }
}
