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

  PreparationStepOrderState copyWith({
    String? preparationId,
    String? preparationName,
  }) {
    return PreparationStepOrderState(
      preparationId: preparationId ?? this.preparationId,
      preparationName: preparationName ?? this.preparationName,
    );
  }

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
