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

  const PreparationFormPreparationStepRemoved(
      {required this.preparationStepId});

  @override
  List<Object> get props => [preparationStepId];
}

final class PreparationFormPreparationStepNameChanged
    extends PreparationFormEvent {
  final String preparationStepId;
  final String preparationStepName;

  const PreparationFormPreparationStepNameChanged(
      {required this.preparationStepId, required this.preparationStepName});

  @override
  List<Object> get props => [preparationStepId, preparationStepName];
}

final class PreparationFormPreparationStepTimeChanged
    extends PreparationFormEvent {
  final String preparationStepId;
  final Duration preparationStepTime;

  const PreparationFormPreparationStepTimeChanged(
      {required this.preparationStepId, required this.preparationStepTime});

  @override
  List<Object> get props => [preparationStepId, preparationStepTime];
}

final class PreparationFormPreparationStepOrderChanged
    extends PreparationFormEvent {
  final int oldIndex;
  final int newIndex;

  const PreparationFormPreparationStepOrderChanged(
      {required this.oldIndex, required this.newIndex});

  @override
  List<Object> get props => [oldIndex, newIndex];
}
