part of 'preparation_name_cubit.dart';

enum PreparationNameStatus { initial, adding }

final class PreparationNameState extends Equatable {
  const PreparationNameState({
    this.preparationStepList = const [],
    this.status = PreparationNameStatus.initial,
  });

  final List<PreparationStepNameState> preparationStepList;
  final PreparationNameStatus status;

  PreparationNameState copyWith({
    List<PreparationStepNameState>? preparationStepList,
    PreparationNameStatus? status,
  }) {
    return PreparationNameState(
      preparationStepList: preparationStepList ?? this.preparationStepList,
      status: status ?? this.status,
    );
  }

  @override
  List<Object> get props => [status];
}

final onBoardingPreparationSuggestion = [
  PreparationStepNameState(
    preparationName: PreparationNameInputModel.dirty('화장실 가기'),
  ),
  PreparationStepNameState(
    preparationName: PreparationNameInputModel.dirty('메이크업'),
  ),
  PreparationStepNameState(
    preparationName: PreparationNameInputModel.dirty('머리 세팅하기'),
  ),
  PreparationStepNameState(
    preparationName: PreparationNameInputModel.dirty('짐 챙기기'),
  ),
];
