part of 'preparation_form_bloc.dart';

enum PreparationFormStatus { initial, success, adding }

final class PreparationFormState extends Equatable {
  const PreparationFormState({
    this.status = PreparationFormStatus.initial,
    this.preparationStepList = const [],
    this.isValid = false,
  });

  factory PreparationFormState.fromEntity(PreparationEntity preparationEntity) {
    final List<PreparationStepFormState> preparationStepFormStateList = [];
    String? nextPreparationStepId;

    final int length = preparationEntity.preparationStepList.length;
    for (var i = 0; i < length; i++) {
      for (var j = 0; j < length; j++) {
        final currentPreparationStep = preparationEntity.preparationStepList[j];
        if (currentPreparationStep.nextPreparationId == nextPreparationStepId) {
          nextPreparationStepId = currentPreparationStep.id;
          preparationStepFormStateList.add(
            PreparationStepFormState(
              id: currentPreparationStep.id,
              preparationName: PreparationNameInputModel.pure(
                  currentPreparationStep.preparationName),
              preparationTime: PreparationTimeInputModel.pure(
                  currentPreparationStep.preparationTime),
            ),
          );
          break;
        }
      }
    }
    return PreparationFormState(
      status: PreparationFormStatus.success,
      preparationStepList: preparationStepFormStateList.reversed.toList(),
    );
  }

  PreparationEntity toPreparationEntity() {
    final steps = preparationStepList
        .mapIndexed((index, step) => PreparationStepEntity(
              id: step.id,
              preparationName: step.preparationName.value,
              preparationTime: step.preparationTime.value,
              nextPreparationId: index < preparationStepList.length - 1
                  ? preparationStepList[index + 1].id
                  : null, // if not last step, set next step id
            ))
        .toList();
    return PreparationEntity(preparationStepList: steps);
  }

  final PreparationFormStatus status;
  final List<PreparationStepFormState> preparationStepList;
  final bool isValid;

  PreparationFormState copyWith({
    PreparationFormStatus? status,
    List<PreparationStepFormState>? preparationStepList,
    bool? isValid,
  }) {
    return PreparationFormState(
      status: status ?? this.status,
      preparationStepList: preparationStepList ?? this.preparationStepList,
      isValid: isValid ?? this.isValid,
    );
  }

  @override
  List<Object> get props => [
        status,
        preparationStepList,
        isValid,
      ];
}
