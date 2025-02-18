part of 'preparation_name_cubit.dart';

enum PreparationNameStatus { initial, adding }

final class PreparationNameState extends Equatable {
  const PreparationNameState({
    this.preparationStepList = const [],
    this.isValid = false,
    this.status = PreparationNameStatus.initial,
  });

  final List<PreparationStepNameState> preparationStepList;
  final bool isValid;
  final PreparationNameStatus status;

  PreparationNameState copyWith({
    List<PreparationStepNameState>? preparationStepList,
    bool? isValid,
    PreparationNameStatus? status,
  }) {
    return PreparationNameState(
      preparationStepList: preparationStepList ?? this.preparationStepList,
      isValid: isValid ?? this.isValid,
      status: status ?? this.status,
    );
  }

  @override
  List<Object> get props => [preparationStepList, isValid, status];
}

final onBoardingPreparationSuggestion = [
  PreparationStepNameState(
    preparationName: PreparationNameInputModel.dirty('화장실 가기'),
    isSelected: false,
  ),
  PreparationStepNameState(
    preparationName: PreparationNameInputModel.dirty('메이크업'),
    isSelected: false,
  ),
  PreparationStepNameState(
    preparationName: PreparationNameInputModel.dirty('머리 세팅하기'),
    isSelected: false,
  ),
  PreparationStepNameState(
    preparationName: PreparationNameInputModel.dirty('짐 챙기기'),
    isSelected: false,
  ),
];
