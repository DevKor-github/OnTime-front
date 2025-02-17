import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/cubit/preparation_step_name/preparation_step_name_cubit.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/input_models/preparation_name_input_model.dart';

part 'preparation_name_state.dart';

class PreparationNameCubit extends Cubit<PreparationNameState> {
  PreparationNameCubit()
      : super(PreparationNameState(
            preparationStepList: onBoardingPreparationSuggestion));

  void preparationStepSaved(PreparationStepNameState state) {
    if (this.state.status == PreparationNameStatus.adding) {
      final preparationStepList = [
        ...this.state.preparationStepList,
        state,
      ];
      emit(this.state.copyWith(
            preparationStepList: preparationStepList,
            status: PreparationNameStatus.initial,
          ));
    } else {
      final preparationStepList = this
          .state
          .preparationStepList
          .map((preparationStep) =>
              preparationStep.preparationId == state.preparationId
                  ? state
                  : preparationStep)
          .toList();
      emit(this.state.copyWith(
            preparationStepList: preparationStepList,
          ));
    }
  }
}
