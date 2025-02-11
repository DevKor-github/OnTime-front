part of 'onboarding_cubit.dart';

class OnboardingState extends Equatable {
  const OnboardingState(
      {this.preparationStepList = const [], this.spareTime, this.note});
  final List<OnboardingPreparationStepState> preparationStepList;
  final Duration? spareTime;
  final String? note;

  OnboardingState copyWith(
      {List<OnboardingPreparationStepState>? preparationStepList,
      Duration? spareTime,
      String? note}) {
    return OnboardingState(
      preparationStepList: preparationStepList ?? this.preparationStepList,
      spareTime: spareTime ?? this.spareTime,
      note: note ?? this.note,
    );
  }

  PreparationEntity toEntity() {
    return PreparationEntity(
      preparationStepList: preparationStepList
          .map((step) => PreparationStepEntity(
                id: step.id,
                preparationName: step.preparationName,
                preparationTime: step.preparationTime,
                nextPreparationId: step.nextPreparationId,
              ))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [preparationStepList, spareTime, note];
}

class OnboardingPreparationStepState extends Equatable {
  const OnboardingPreparationStepState({
    required this.id,
    required this.preparationName,
    this.preparationTime = const Duration(minutes: 0),
    this.nextPreparationId,
  });

  final String id;
  final String preparationName;
  final Duration preparationTime;
  final String? nextPreparationId;

  OnboardingPreparationStepState copyWith({
    String? id,
    String? preparationName,
    Duration? preparationTime,
    String? nextPreparationId,
  }) {
    return OnboardingPreparationStepState(
      id: id ?? this.id,
      preparationName: preparationName ?? this.preparationName,
      preparationTime: preparationTime ?? this.preparationTime,
      nextPreparationId: nextPreparationId ?? this.nextPreparationId,
    );
  }

  @override
  List<Object?> get props =>
      [id, preparationName, preparationTime, nextPreparationId];
}
