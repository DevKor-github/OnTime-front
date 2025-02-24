part of 'onboarding_cubit.dart';

class OnboardingState extends Equatable {
  const OnboardingState(
      {this.preparationStepList = const [],
      this.spareTime,
      this.note,
      this.isValid = false});
  final List<OnboardingPreparationStepState> preparationStepList;
  final Duration? spareTime;
  final String? note;
  final bool isValid;

  OnboardingState copyWith({
    List<OnboardingPreparationStepState>? preparationStepList,
    Duration? spareTime,
    String? note,
    bool? isValid,
  }) {
    return OnboardingState(
      preparationStepList: preparationStepList ?? this.preparationStepList,
      spareTime: spareTime ?? this.spareTime,
      note: note ?? this.note,
      isValid: isValid ?? this.isValid,
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
  List<Object?> get props => [preparationStepList, spareTime, note, isValid];
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
      nextPreparationId: nextPreparationId == ''
          ? null
          : (nextPreparationId ?? this.nextPreparationId),
    );
  }

  @override
  List<Object?> get props =>
      [id, preparationName, preparationTime, nextPreparationId];
}
