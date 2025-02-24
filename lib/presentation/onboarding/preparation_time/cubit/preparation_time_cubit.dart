import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/presentation/onboarding/cubit/onboarding/onboarding_cubit.dart';

part 'preparation_time_state.dart';

class PreparationTimeCubit extends Cubit<PreparationTimeState> {
  PreparationTimeCubit({
    required this.onboardingCubit,
  }) : super(PreparationTimeState()) {
    initialize();
  }

  final OnboardingCubit onboardingCubit;

  void initialize() {
    emit(PreparationTimeState.fromOnboardingState(onboardingCubit.state));
  }

  void preparationTimeChanged(int index, Duration preparationTime) {
    final List<PreparationStepTimeState> preparationTimeList =
        List<PreparationStepTimeState>.from(state.preparationTimeList);
    preparationTimeList[index] = preparationTimeList[index].copyWith(
      preparationTime: preparationTime,
    );
    emit(state.copyWith(preparationTimeList: preparationTimeList));
  }

  void preparationTimeSaved() {
    final newList =
        state.toOnboardingState(onboardingCubit.state).preparationStepList;
    onboardingCubit.onboardingFormChanged(newList);
  }
}
