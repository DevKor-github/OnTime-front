part of 'preparation_name_cubit.dart';

enum PreparationNameStatus { initial, adding }

final class PreparationNameState extends Equatable {
  const PreparationNameState({
    this.preparationStepList = const [],
    this.status = PreparationNameStatus.initial,
  });

  final List<PreparationStepNameState> preparationStepList;
  final PreparationNameStatus status;

  @override
  List<Object> get props => [status];
}

final onBoardingPreparationSuggestion = [
  PreparationStepNameState(
    preparationName: '화장실 가기',
  ),
  PreparationStepNameState(
    preparationName: '메이크업',
  ),
  PreparationStepNameState(
    preparationName: '머리 세팅하기',
  ),
  PreparationStepNameState(
    preparationName: '짐 챙기기',
  ),
];
