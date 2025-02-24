import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:on_time_front/presentation/onboarding/cubit/onboarding/onboarding_cubit.dart';
import 'package:on_time_front/presentation/onboarding/preparation_time/input_models/preparation_time_input_model.dart';

part 'preparation_time_state.dart';

class PreparationTimeCubit extends Cubit<PreparationTimeState> {
  PreparationTimeCubit({
    required this.onboardingCubit,
  }) : super(PreparationTimeState()) {
    initialize();
  }

  final OnboardingCubit onboardingCubit;

  void initialize() {
    final preparationTimeState =
        PreparationTimeState.fromOnboardingState(onboardingCubit.state);

    emit(state.copyWith(
      preparationTimeList: preparationTimeState.preparationTimeList,
    ));
    onboardingCubit.onboardingFormValidated(
        isValid: preparationTimeState.isValid);
  }

  void preparationTimeChanged(int index, Duration preparationTime) {
    final List<PreparationStepTimeState> preparationTimeList =
        List<PreparationStepTimeState>.from(state.preparationTimeList);
    preparationTimeList[index] = preparationTimeList[index].copyWith(
      preparationTime: PreparationTimeInputModel.dirty(preparationTime),
    );
    emit(state.copyWith(
      preparationTimeList: preparationTimeList,
    ));
    onboardingCubit.onboardingFormValidated(isValid: state.isValid);
  }

  void preparationTimeSaved() {
    final newList =
        state.toOnboardingState(onboardingCubit.state).preparationStepList;
    onboardingCubit.onboardingFormChanged(newList);
  }
}
