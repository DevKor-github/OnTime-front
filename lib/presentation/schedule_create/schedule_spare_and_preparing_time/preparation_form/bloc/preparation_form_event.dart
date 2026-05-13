part of 'preparation_form_bloc.dart';

sealed class PreparationFormEvent extends Equatable {
  const PreparationFormEvent();

  @override
  List<Object> get props => [];
}

final class PreparationFormEditRequested extends PreparationFormEvent {
  final PreparationEntity preparationEntity;

  const PreparationFormEditRequested({required this.preparationEntity});

  @override
  List<Object> get props => [];
}

final class PreparationFormPreparationStepCreated extends PreparationFormEvent {
  final PreparationStepFormState preparationStep;

  const PreparationFormPreparationStepCreated({required this.preparationStep});

  @override
  List<Object> get props => [preparationStep];
}

final class PreparationFormPreparationStepRemoved extends PreparationFormEvent {
  final String preparationStepId;

  const PreparationFormPreparationStepRemoved({
    required this.preparationStepId,
  });

  @override
  List<Object> get props => [preparationStepId];
}

final class PreparationFormPreparationStepNameChanged
    extends PreparationFormEvent {
  final int index;
  final String preparationStepName;

  const PreparationFormPreparationStepNameChanged({
    required this.index,
    required this.preparationStepName,
  });

  @override
  List<Object> get props => [index, preparationStepName];
}

final class PreparationFormPreparationStepNameFocusLost
    extends PreparationFormEvent {
  final int index;
  final String preparationStepName;

  const PreparationFormPreparationStepNameFocusLost({
    required this.index,
    required this.preparationStepName,
  });

  @override
  List<Object> get props => [index, preparationStepName];
}

final class PreparationFormPreparationStepInteractionEnded
    extends PreparationFormEvent {
  final int index;
  final String preparationStepName;

  const PreparationFormPreparationStepInteractionEnded({
    required this.index,
    required this.preparationStepName,
  });

  @override
  List<Object> get props => [index, preparationStepName];
}

final class PreparationFormPreparationStepTimeChanged
    extends PreparationFormEvent {
  final int index;
  final Duration preparationStepTime;

  const PreparationFormPreparationStepTimeChanged({
    required this.index,
    required this.preparationStepTime,
  });

  @override
  List<Object> get props => [index, preparationStepTime];
}

final class PreparationFormDraftStepNameChanged extends PreparationFormEvent {
  final String preparationStepName;

  const PreparationFormDraftStepNameChanged({
    required this.preparationStepName,
  });

  @override
  List<Object> get props => [preparationStepName];
}

final class PreparationFormDraftStepTimeChanged extends PreparationFormEvent {
  final Duration preparationStepTime;

  const PreparationFormDraftStepTimeChanged({
    required this.preparationStepTime,
  });

  @override
  List<Object> get props => [preparationStepTime];
}

final class PreparationFormPreparationStepOrderChanged
    extends PreparationFormEvent {
  final int oldIndex;
  final int newIndex;

  const PreparationFormPreparationStepOrderChanged({
    required this.oldIndex,
    required this.newIndex,
  });

  @override
  List<Object> get props => [oldIndex, newIndex];
}

final class PreparationFormPreparationStepCreationRequested
    extends PreparationFormEvent {
  const PreparationFormPreparationStepCreationRequested();
}

final class PreparationFormValidationRequested extends PreparationFormEvent {
  const PreparationFormValidationRequested();
}
