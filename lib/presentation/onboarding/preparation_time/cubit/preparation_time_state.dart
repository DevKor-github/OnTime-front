part of 'preparation_time_cubit.dart';

class PreparationTimeState extends Equatable {
  const PreparationTimeState({
    this.preparationTimeList = const [],
  });

  final List<PreparationStepTimeState> preparationTimeList;
  bool get isValid => Formz.validate(
      preparationTimeList.map((e) => e.preparationTime).toList());

  PreparationTimeState copyWith({
    List<PreparationStepTimeState>? preparationTimeList,
    bool? isValid,
  }) {
    return PreparationTimeState(
      preparationTimeList: preparationTimeList ?? this.preparationTimeList,
    );
  }

  static PreparationTimeState fromOnboardingState(OnboardingState state) {
    final preparationTimeList = state.preparationStepList
        .map((e) =>
            PreparationStepTimeState.fromOnboardingPreparationStepState(e))
        .toList();
    return PreparationTimeState(preparationTimeList: preparationTimeList);
  }

  OnboardingState toOnboardingState(OnboardingState oldState) {
    final List<OnboardingPreparationStepState>
        onboardingPreparationStepStateList = [];
    int j = 0;
    for (int i = 0; i < preparationTimeList.length; i++) {
      while (j < oldState.preparationStepList.length &&
          oldState.preparationStepList[j].id !=
              preparationTimeList[i].preparationId) {
        j++;
      }
      if (j == oldState.preparationStepList.length) {
        continue;
      }
      onboardingPreparationStepStateList
          .add(oldState.preparationStepList[j].copyWith(
        preparationTime: preparationTimeList[i].preparationTime.value,
      ));
    }
    return oldState.copyWith(
      preparationStepList: onboardingPreparationStepStateList,
    );
  }

  @override
  List<Object> get props => [preparationTimeList];
}

class PreparationStepTimeState extends Equatable {
  const PreparationStepTimeState({
    required this.preparationId,
    required this.preparationName,
    this.preparationTime = const PreparationTimeInputModel.pure(),
  });

  final String preparationId;
  final String preparationName;
  final PreparationTimeInputModel preparationTime;

  PreparationStepTimeState copyWith({
    PreparationTimeInputModel? preparationTime,
  }) {
    return PreparationStepTimeState(
      preparationId: preparationId,
      preparationName: preparationName,
      preparationTime: preparationTime ?? this.preparationTime,
    );
  }

  static PreparationStepTimeState fromOnboardingPreparationStepState(
      OnboardingPreparationStepState state) {
    return PreparationStepTimeState(
      preparationId: state.id,
      preparationName: state.preparationName,
      preparationTime: PreparationTimeInputModel.dirty(state.preparationTime),
    );
  }

  @override
  List<Object> get props => [preparationId, preparationName, preparationTime];
}
