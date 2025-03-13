import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/input_models/preparation_name_input_model.dart';
import 'package:on_time_front/presentation/onboarding/preparation_time/input_models/preparation_time_input_model.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/bloc/preparation_form_bloc.dart';
import 'package:uuid/uuid.dart';

part 'preparation_step_form_state.dart';

class PreparationStepFormCubit extends Cubit<PreparationStepFormState> {
  PreparationStepFormCubit(
    super.initialState, {
    required this.preparationFormBloc,
  });

  final PreparationFormBloc preparationFormBloc;

  void nameChanged(String value) {
    final preparationName = PreparationNameInputModel.dirty(value);
    emit(state.copyWith(
        preparationName: preparationName, isValid: preparationName.isValid));
  }

  void timeChanged(Duration value) {
    final preparationTime = PreparationTimeInputModel.dirty(value);
    emit(state.copyWith(
        preparationTime: preparationTime, isValid: preparationTime.isValid));
  }

  void preparationStepSaved() {
    preparationFormBloc.add(PreparationFormPreparationStepCreated(
      preparationStep: state,
    ));
  }
}
