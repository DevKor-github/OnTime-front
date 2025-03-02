part of 'preparation_order_cubit.dart';

class PreparationOrderState extends Equatable {
  const PreparationOrderState({
    this.preparationStepList = const [],
  });

  final List<PreparationStepOrderState> preparationStepList;

  PreparationOrderState copyWith({
    List<PreparationStepOrderState>? preparationStepList,
  }) {
    return PreparationOrderState(
      preparationStepList: preparationStepList ?? this.preparationStepList,
    );
  }

  static PreparationOrderState fromOnboardingState(OnboardingState state) {
    final List<PreparationStepOrderState> preparationStepList = [];
    final List<OnboardingPreparationStepState> onboardingPreparationStepList =
        state.preparationStepList;

    // Check if the order does not exist
    // If all the nextPreparationId is null, it means the order does not exist
    bool orderNotExists =
        onboardingPreparationStepList.fold(true, (bool flag, element) {
      if (flag) {
        return element.nextPreparationId == null;
      }
      return false;
    });

    if (orderNotExists) {
      return PreparationOrderState(
        preparationStepList: onboardingPreparationStepList
            .map((e) =>
                PreparationStepOrderState.fromOnboardingPreparationStepState(e))
            .toList(),
      );
    }

    String? nextPreparationId;
    for (int i = 0; i < onboardingPreparationStepList.length; i++) {
      for (int j = 0; j < onboardingPreparationStepList.length; j++) {
        if (onboardingPreparationStepList[j].nextPreparationId ==
            nextPreparationId) {
          preparationStepList.add(
              PreparationStepOrderState.fromOnboardingPreparationStepState(
                  onboardingPreparationStepList[j]));
          nextPreparationId = onboardingPreparationStepList[j].id;
          break;
        }
      }
    }
    return PreparationOrderState(
      preparationStepList: preparationStepList.reversed.toList(),
    );
  }

  OnboardingState toOnboardingState() {
    final List<OnboardingPreparationStepState> preparationStepList = [];
    for (int i = 0; i < this.preparationStepList.length; i++) {
      preparationStepList.add(OnboardingPreparationStepState(
          id: this.preparationStepList[i].preparationId,
          preparationName: this.preparationStepList[i].preparationName,
          nextPreparationId: i == this.preparationStepList.length - 1
              ? null
              : this.preparationStepList[i + 1].preparationId));
    }
    return OnboardingState(preparationStepList: preparationStepList);
  }

  @override
  List<Object> get props => [preparationStepList];
}

class PreparationStepOrderState extends Equatable {
  const PreparationStepOrderState({
    required this.preparationId,
    required this.preparationName,
  });

  final String preparationId;
  final String preparationName;

  static PreparationStepOrderState fromOnboardingPreparationStepState(
      OnboardingPreparationStepState state) {
    return PreparationStepOrderState(
      preparationId: state.id,
      preparationName: state.preparationName,
    );
  }

  @override
  List<Object> get props => [preparationId, preparationName];
}
