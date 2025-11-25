import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_place_moving_time.dart/input_models/schedule_moving_time_input_model.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_place_moving_time.dart/input_models/schedule_place_input_model.dart';
import 'package:on_time_front/presentation/shared/constants/constants.dart';

part 'schedule_place_moving_time_state.dart';

class SchedulePlaceMovingTimeCubit extends Cubit<SchedulePlaceMovingTimeState> {
  SchedulePlaceMovingTimeCubit({required this.scheduleFormBloc})
      : super(SchedulePlaceMovingTimeState()) {
    initialize();
  }

  final ScheduleFormBloc scheduleFormBloc;

  void initialize() {
    final schedulePlaceMovingTimeState =
        SchedulePlaceMovingTimeState.fromScheduleFormState(
            scheduleFormBloc.state);
    emit(state.copyWith(
      placeName: schedulePlaceMovingTimeState.placeName,
      moveTime: schedulePlaceMovingTimeState.moveTime,
    ));
    scheduleFormBloc.add(ScheduleFormValidated(isValid: state.isValid));
  }

  void placeNameChanged(String placeName) {
    final SchedulePlaceInputModel placeNameInputModel =
        SchedulePlaceInputModel.dirty(placeName);
    emit(state.copyWith(placeName: placeNameInputModel));
    scheduleFormBloc.add(ScheduleFormValidated(isValid: state.isValid));
  }

  void moveTimeChanged(Duration moveTime) {
    final ScheduleMovingTimeInputModel moveTimeInputModel =
        ScheduleMovingTimeInputModel.dirty(moveTime);

    // Check for overlap if maxAvailableTime exists
    final formState = scheduleFormBloc.state;
    final maxAvailableTime = formState.maxAvailableTime;
    final oldMoveTime = formState.moveTime ?? Duration.zero;

    Duration? overlapDuration;
    bool isOverlapping = false;

    if (maxAvailableTime != null && formState.scheduleTime != null) {
      // Calculate the change in moveTime
      final moveTimeDifference = moveTime - oldMoveTime;

      // Calculate new time left: if moveTime increases, time left decreases
      final newTimeLeft = maxAvailableTime - moveTimeDifference;
      final minutesDifference = newTimeLeft.inMinutes;

      if (minutesDifference <= 0) {
        // Already overlapping - show as error
        overlapDuration = newTimeLeft.abs();
        isOverlapping = true;
      } else if (minutesDifference < scheduleOverlapWarningThresholdMinutes) {
        // Show warning if there's still time left
        overlapDuration = newTimeLeft;
        isOverlapping = false;
      } else {
        overlapDuration = null;
        isOverlapping = false;
      }
    }

    emit(state.copyWith(
      moveTime: moveTimeInputModel,
      overlapDuration: overlapDuration,
      isOverlapping: isOverlapping,
      clearOverlap: overlapDuration == null,
    ));

    scheduleFormBloc.add(ScheduleFormValidated(isValid: state.isValid));
  }

  void schedulePlaceMovingTimeSubmitted() {
    if (state.placeName.isValid && state.moveTime.isValid) {
      scheduleFormBloc
          .add(ScheduleFormMoveTimeChanged(moveTime: state.moveTime.value));
      scheduleFormBloc
          .add(ScheduleFormPlaceNameChanged(placeName: state.placeName.value));
    }
  }
}
