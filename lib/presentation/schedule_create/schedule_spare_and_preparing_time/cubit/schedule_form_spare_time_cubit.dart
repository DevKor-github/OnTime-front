import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/input_models/schedule_spare_time_input_model.dart';

part 'schedule_form_spare_time_state.dart';

class ScheduleFormSpareTimeCubit extends Cubit<ScheduleFormSpareTimeState> {
  ScheduleFormSpareTimeCubit({
    required this.scheduleFormBloc,
  }) : super(ScheduleFormSpareTimeState());

  final ScheduleFormBloc scheduleFormBloc;

  void initialize() {
    final schedulePlaceMovingTimeState =
        ScheduleFormSpareTimeState.fromScheduleFormState(
            scheduleFormBloc.state);
    emit(state.copyWith(
      spareTime: schedulePlaceMovingTimeState.spareTime,
    ));
    scheduleFormBloc.add(ScheduleFormValidated(isValid: state.isValid));
  }

  void spareTimeChanged(Duration value) {
    final spareTime = ScheduleSpareTimeInputModel.dirty(value);
    emit(state.copyWith(
      spareTime: spareTime,
    ));
    scheduleFormBloc.add(ScheduleFormValidated(isValid: state.isValid));
  }

  void scheduleSpareTimeSubmitted() {
    if (state.isValid) {
      scheduleFormBloc.add(ScheduleFormScheduleSpareTimeChanged(
        scheduleSpareTime: state.spareTime.value!,
      ));
    }
  }
}
