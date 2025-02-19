import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/presentation/onboarding/cubit/onboarding/onboarding_cubit.dart';

part 'preparation_order_state.dart';

class PreparationOrderCubit extends Cubit<PreparationOrderState> {
  PreparationOrderCubit({
    required this.onboardingCubit,
  }) : super(PreparationOrderState()) {
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
    final PreparationStepOrderState item =
        preparationStepList.removeAt(oldIndex);
    preparationStepList.insert(newIndex, item);
    emit(state.copyWith(preparationStepList: preparationStepList));
  }

  void preparationOrderSaved() {
    onboardingCubit
        .onboardingFormChanged(state.toOnboardingState().preparationStepList);
  }
}
