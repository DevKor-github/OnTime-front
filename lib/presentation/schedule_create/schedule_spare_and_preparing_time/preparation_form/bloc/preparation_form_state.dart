part of 'preparation_form_bloc.dart';

enum PreparationFormStatus { initial, success, adding }

enum PreparationFormInvalidField { name, time }

final class PreparationFormState extends Equatable {
  const PreparationFormState({
    this.status = PreparationFormStatus.initial,
    this.preparationStepList = const [],
    this.addingStepId,
    this.showValidationErrors = false,
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
                currentPreparationStep.preparationName,
              ),
              preparationTime: PreparationTimeInputModel.pure(
                currentPreparationStep.preparationTime,
              ),
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
    final steps = visiblePreparationStepList
        .mapIndexed(
          (index, step) => PreparationStepEntity(
            id: step.id,
            preparationName: step.preparationName.value,
            preparationTime: step.preparationTime.value,
            nextPreparationId: index < visiblePreparationStepList.length - 1
                ? visiblePreparationStepList[index + 1].id
                : null, // if not last step, set next step id
          ),
        )
        .toList();
    return PreparationEntity(preparationStepList: steps);
  }

  final PreparationFormStatus status;
  final List<PreparationStepFormState> preparationStepList;
  final String? addingStepId;
  final bool showValidationErrors;
  final bool isValid;

  List<PreparationStepFormState> get visiblePreparationStepList =>
      preparationStepList;

  PreparationStepFormState? get firstInvalidStep => visiblePreparationStepList
      .firstWhereOrNull((step) => invalidFieldFor(step) != null);

  PreparationFormInvalidField? invalidFieldFor(PreparationStepFormState step) {
    if (!step.preparationName.isValid) {
      return PreparationFormInvalidField.name;
    }
    if (!step.preparationTime.isValid) {
      return PreparationFormInvalidField.time;
    }
    return null;
  }

  PreparationFormState copyWith({
    PreparationFormStatus? status,
    List<PreparationStepFormState>? preparationStepList,
    String? addingStepId,
    bool clearAddingStepId = false,
    bool? showValidationErrors,
    bool? isValid,
  }) {
    return PreparationFormState(
      status: status ?? this.status,
      preparationStepList: preparationStepList ?? this.preparationStepList,
      addingStepId: clearAddingStepId
          ? null
          : addingStepId ?? this.addingStepId,
      showValidationErrors: showValidationErrors ?? this.showValidationErrors,
      isValid: isValid ?? this.isValid,
    );
  }

  @override
  List<Object?> get props => [
    status,
    preparationStepList,
    addingStepId,
    showValidationErrors,
    isValid,
  ];
}
