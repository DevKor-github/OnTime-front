import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:on_time_front/presentation/onboarding/cubit/onboarding/onboarding_cubit.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/cubit/preparation_step_name/preparation_step_name_cubit.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/input_models/preparation_name_input_model.dart';

part 'preparation_name_state.dart';

class PreparationNameCubit extends Cubit<PreparationNameState> {
  PreparationNameCubit({
    required this.onboardingCubit,
  }) : super(PreparationNameState()) {
    initialize();
  }

  final OnboardingCubit onboardingCubit;

  void initialize() {
    List<PreparationStepNameState> preparationStepList =
        onboardingCubit.state.preparationStepList.map(
      (e) {
        return PreparationStepNameState(
          preparationId: e.id,
          preparationName: PreparationNameInputModel.dirty(e.preparationName),
          isSelected: true,
        );
      },
    ).toList();
    if (preparationStepList.isEmpty) {
      preparationStepList = onBoardingPreparationSuggestion;
    }
    emit(state.copyWith(
      status: PreparationNameStatus.initial,
      isValid: false,
      preparationStepList: preparationStepList,
    ));
  }

  void preparationStepSaved(PreparationStepNameState stepState) {
    if (state.status == PreparationNameStatus.adding) {
      final List<PreparationStepNameState> preparationStepList;
      if (stepState.preparationName.isValid) {
        preparationStepList = [
          ...state.preparationStepList,
          stepState,
        ];
      } else {
        preparationStepList = state.preparationStepList;
      }
      final isValid = _validate(preparationStepList);
      emit(state.copyWith(
        preparationStepList: preparationStepList,
        status: PreparationNameStatus.initial,
        isValid: isValid,
      ));
      onboardingCubit.onboardingFormValidated(isValid: isValid);
    }
  }

  void preparationStepNameChanged({
    required int index,
    required String value,
  }) {
    final preparationStepList =
        List<PreparationStepNameState>.from(state.preparationStepList);
    final preparationStep = preparationStepList[index];
    final updatedPreparationStep = preparationStep.copyWith(
      preparationName: PreparationNameInputModel.dirty(value),
    );
    preparationStepList[index] = updatedPreparationStep;

    final isValid = _validate(preparationStepList);
    emit(
      state.copyWith(
          preparationStepList: preparationStepList, isValid: isValid),
    );
    onboardingCubit.onboardingFormValidated(isValid: isValid);
  }

  void preparationStepSelectionChanged({
    required int index,
  }) {
    final preparationStepList =
        List<PreparationStepNameState>.from(state.preparationStepList);
    final preparationStep = preparationStepList[index];
    final updatedPreparationStep = preparationStep.copyWith(
      isSelected: !preparationStep.isSelected,
    );
    preparationStepList[index] = updatedPreparationStep;

    final isValid = _validate(preparationStepList);
    emit(state.copyWith(
      preparationStepList: preparationStepList,
      isValid: isValid,
    ));
    onboardingCubit.onboardingFormValidated(isValid: isValid);
  }

  void preparationStepCreateRequested() {
    emit(state.copyWith(status: PreparationNameStatus.adding));
  }

  void preparationSaved() {
    final List<OnboardingPreparationStepState>
        onboardingPreparationStepStateList = [];
    final selectedList = state.preparationStepList
        .where((element) => element.isSelected)
        .toList();
    final onboardingState = onboardingCubit.state;
    int j = 0;
    for (int i = 0; i < selectedList.length; i++) {
      while (j < onboardingState.preparationStepList.length &&
          onboardingState.preparationStepList[j].id !=
              selectedList[i].preparationId) {
        j++;
      }
      if (j == onboardingState.preparationStepList.length) {
        onboardingPreparationStepStateList.add(OnboardingPreparationStepState(
          id: selectedList[i].preparationId,
          preparationName: selectedList[i].preparationName.value,
        ));
        continue;
      }
      onboardingPreparationStepStateList
          .add(onboardingState.preparationStepList[j].copyWith(
        preparationName: selectedList[i].preparationName.value,
      ));
    }
    onboardingCubit.onboardingFormChanged(onboardingPreparationStepStateList);
  }

  bool _validate(List<PreparationStepNameState> preparationStepList) {
    final selectedPreparationStepList =
        preparationStepList.where((element) => element.isSelected).toList();
    final isValid = selectedPreparationStepList.isNotEmpty &&
        Formz.validate(
            selectedPreparationStepList.map((e) => e.preparationName).toList());
    return isValid;
  }
}
