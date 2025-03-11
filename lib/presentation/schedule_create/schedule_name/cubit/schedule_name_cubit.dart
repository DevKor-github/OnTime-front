import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form/schedule_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_name/input_models/schedule_name_input_model.dart';

part 'schedule_name_state.dart';

class ScheduleNameCubit extends Cubit<ScheduleNameState> {
  ScheduleNameCubit({
    required this.scheduleFormBloc,
  }) : super(ScheduleNameState()) {
    initialize();
  }

  final ScheduleFormBloc scheduleFormBloc;

  void initialize() {
    final scheduleNameState =
        ScheduleNameState.fromScheduleFormState(scheduleFormBloc.state);
    emit(state.copyWith(
      scheduleName: scheduleNameState.scheduleName,
    ));
    scheduleFormBloc.add(ScheduleFormValidated(isValid: state.isValid));
  }

  void scheduleNameChanged(String scheduleName) {
    final ScheduleNameInputModel scheduleNameInputModel =
        ScheduleNameInputModel.dirty(scheduleName);
    emit(state.copyWith(
      scheduleName: scheduleNameInputModel,
    ));
    scheduleFormBloc.add(ScheduleFormValidated(isValid: state.isValid));
  }

  void scheduleNameSubmitted() {
    if (state.scheduleName.isValid) {
      scheduleFormBloc.add(ScheduleFormScheduleNameChanged(
        scheduleName: state.scheduleName.value,
      ));
    }
  }
}
