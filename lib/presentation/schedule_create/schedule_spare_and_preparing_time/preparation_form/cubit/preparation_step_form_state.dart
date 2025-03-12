part of 'preparation_step_form_cubit.dart';

class PreparationStepFormState extends Equatable {
  PreparationStepFormState({
    String? id,
    this.preparationName = const PreparationNameInputModel.pure(),
    this.preparationTime = const PreparationTimeInputModel.pure(),
    this.isValid = false,
  }) : id = id ?? Uuid().v7();

  final String id;
  final PreparationNameInputModel preparationName;
  final PreparationTimeInputModel preparationTime;
  final bool isValid;

  PreparationStepFormState copyWith({
    String? id,
    PreparationNameInputModel? preparationName,
    PreparationTimeInputModel? preparationTime,
    bool? isValid,
  }) {
    return PreparationStepFormState(
      id: id ?? this.id,
      preparationName: preparationName ?? this.preparationName,
      preparationTime: preparationTime ?? this.preparationTime,
      isValid: isValid ?? this.isValid,
    );
  }

  @override
  List<Object> get props => [id, preparationName, preparationTime, isValid];
}
