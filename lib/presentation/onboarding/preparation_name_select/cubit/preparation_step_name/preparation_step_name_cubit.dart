import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/cubit/preparation_name/preparation_name_cubit.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/input_models/preparation_name_input_model.dart';
import 'package:uuid/uuid.dart';

part 'preparation_step_name_state.dart';

class PreparationStepNameCubit extends Cubit<PreparationStepNameState> {
  PreparationStepNameCubit(
    super.initialState, {
    required this.preparationNameCubit,
  });

  final PreparationNameCubit preparationNameCubit;

  void nameChanged(String value) {
    final preparationName = PreparationNameInputModel.dirty(value);
    emit(state.copyWith(
        preparationName: preparationName, isValid: preparationName.isValid));
  }

  void selectionToggled() {
    emit(state.copyWith(
      isSelected: !state.isSelected,
    ));
  }

  void preparationStepSaved() {
    preparationNameCubit.preparationStepSaved(state);
  }
}
