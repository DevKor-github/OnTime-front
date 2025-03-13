import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_date_time/input_models/schedule_date_input_model.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_date_time/input_models/schedule_time_input_model.dart';

part 'schedule_date_time_state.dart';

class ScheduleDateTimeCubit extends Cubit<ScheduleDateTimeState> {
  ScheduleDateTimeCubit({
    required this.scheduleFormBloc,
  }) : super(ScheduleDateTimeState()) {
    initialize();
  }

  final ScheduleFormBloc scheduleFormBloc;

  void initialize() {
    final scheduleDateTimeState =
        ScheduleDateTimeState.fromScheduleFormState(scheduleFormBloc.state);
    emit(state.copyWith(
      scheduleDate: scheduleDateTimeState.scheduleDate,
      scheduleTime: scheduleDateTimeState.scheduleTime,
    ));
    scheduleFormBloc.add(ScheduleFormValidated(isValid: state.isValid));
  }

  void scheduleDateChanged(DateTime scheduleDate) {
    final ScheduleDateInputModel scheduleDateInputModel =
        ScheduleDateInputModel.dirty(scheduleDate);
    emit(state.copyWith(scheduleDate: scheduleDateInputModel));
    scheduleFormBloc.add(ScheduleFormValidated(isValid: state.isValid));
  }

  void scheduleTimeChanged(DateTime scheduleTime) {
    final ScheduleTimeInputModel scheduleTimeInputModel =
        ScheduleTimeInputModel.dirty(scheduleTime);
    emit(state.copyWith(scheduleTime: scheduleTimeInputModel));
    scheduleFormBloc.add(ScheduleFormValidated(isValid: state.isValid));
  }

  void scheduleDateTimeSubmitted() {
    if (state.scheduleDate.isValid && state.scheduleTime.isValid) {
      scheduleFormBloc.add(ScheduleFormScheduleDateTimeChanged(
        scheduleDate: state.scheduleDate.value!,
        scheduleTime: state.scheduleTime.value!,
      ));
    }
  }
}
