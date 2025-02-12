part of 'preparation_step_name_cubit.dart';

enum PreparationStepNameStatus { selected, unselected }

class PreparationStepNameState extends Equatable {
  PreparationStepNameState({
    String? preparationId,
    this.preparationName = '',
    FocusNode? focusNode,
    this.isValid = false,
    this.status = PreparationStepNameStatus.unselected,
  })  : preparationId = preparationId ?? Uuid().v7(),
        focusNode = focusNode ?? FocusNode();

  final String preparationId;
  final String preparationName;
  final FocusNode focusNode;
  final bool isValid;
  final PreparationStepNameStatus status;

  PreparationStepNameState copyWith({
    String? preparationId,
    String? preparationName,
    FocusNode? focusNode,
    bool? isValid,
    PreparationStepNameStatus? status,
  }) {
    return PreparationStepNameState(
      preparationId: preparationId ?? this.preparationId,
      preparationName: preparationName ?? this.preparationName,
      focusNode: focusNode ?? this.focusNode,
      isValid: isValid ?? this.isValid,
      status: status ?? this.status,
    );
  }

  @override
  List<Object> get props =>
      [preparationId, preparationName, focusNode, isValid, status];
}
