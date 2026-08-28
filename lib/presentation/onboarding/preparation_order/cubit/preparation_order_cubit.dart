import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/presentation/onboarding/cubit/onboarding_cubit.dart';

part 'preparation_order_state.dart';

class PreparationOrderCubit extends Cubit<PreparationOrderState> {
  PreparationOrderCubit({required this.onboardingCubit})
    : super(PreparationOrderState()) {
    initialize();
  }

  final OnboardingCubit onboardingCubit;

  void initialize() {
    emit(PreparationOrderState.fromOnboardingState(onboardingCubit.state));
    onboardingCubit.onboardingFormValidated(isValid: true);
  }

  void preparationOrderChanged(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final List<PreparationStepOrderState> preparationStepList =
        List<PreparationStepOrderState>.from(state.preparationStepList);
    final PreparationStepOrderState item = preparationStepList.removeAt(
      oldIndex,
    );
    preparationStepList.insert(newIndex, item);
    emit(state.copyWith(preparationStepList: preparationStepList));
  }

  void preparationOrderSaved() {
    final orderedList = state.toOnboardingState().preparationStepList;
    final existingSteps = {
      for (final step in onboardingCubit.state.preparationStepList)
        step.id: step,
    };

    assert(orderedList.length == existingSteps.length);

    final reorderedSteps = orderedList
        .map((step) {
          final existingStep = existingSteps[step.id];
          return OnboardingPreparationStepState(
            id: step.id,
            preparationName: step.preparationName,
            preparationTime:
                existingStep?.preparationTime ?? step.preparationTime,
            nextPreparationId: step.nextPreparationId,
          );
        })
        .toList(growable: false);

    onboardingCubit.onboardingFormChanged(preparationStepList: reorderedSteps);
  }
}
