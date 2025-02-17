part of 'preparation_step_name_cubit.dart';

class PreparationStepNameState extends Equatable {
  PreparationStepNameState({
    String? preparationId,
    this.preparationName = const PreparationNameInputModel.pure(),
    this.isValid = false,
    this.isSelected = true,
  }) : preparationId = preparationId ?? Uuid().v7();

  final String preparationId;
  final PreparationNameInputModel preparationName;
  final bool isValid;
  final bool isSelected;

  PreparationStepNameState copyWith({
    String? preparationId,
    PreparationNameInputModel? preparationName,
    bool? isValid,
    bool? isSelected,
  }) {
    return PreparationStepNameState(
      preparationId: preparationId ?? this.preparationId,
      preparationName: preparationName ?? this.preparationName,
      isValid: isValid ?? this.isValid,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  @override
  List<Object> get props =>
      [preparationId, preparationName, isValid, isSelected];
}
