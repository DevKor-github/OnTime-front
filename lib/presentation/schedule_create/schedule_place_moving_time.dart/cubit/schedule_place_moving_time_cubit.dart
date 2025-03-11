import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form/schedule_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_place_moving_time.dart/input_models/schedule_moving_time_input_model.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_place_moving_time.dart/input_models/schedule_place_input_model.dart';

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
    emit(state.copyWith(moveTime: moveTimeInputModel));
    scheduleFormBloc.add(ScheduleFormValidated(isValid: state.isValid));
  }
}
