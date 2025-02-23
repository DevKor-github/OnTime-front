part of 'alarm_screen_preparation_info_bloc.dart';

abstract class AlarmScreenPreparationInfoState extends Equatable {
  const AlarmScreenPreparationInfoState();

  @override
  List<Object?> get props => [];
}

class PreparationInfoInitial extends AlarmScreenPreparationInfoState {}

class PreparationInfoLoadInProgress extends AlarmScreenPreparationInfoState {}

class PreparationInfoLoadSuccess extends AlarmScreenPreparationInfoState {
  final List<PreparationStepEntity> preparationSteps;
  final int currentIndex;
  final int remainingTime;
  final int totalPreparationTime;
  final int _totalRemainingTime;
  final int fullTime;
  final bool isLate;
  final List<bool> preparationCompleted;

  const PreparationInfoLoadSuccess({
    required this.preparationSteps,
    required this.currentIndex,
    required this.remainingTime,
    required this.totalPreparationTime,
    required int totalRemainingTime,
    required this.fullTime,
    required this.isLate,
    required this.preparationCompleted,
  }) : _totalRemainingTime = totalRemainingTime;

  int get totalRemainingTime => _totalRemainingTime;

  double get progress => totalPreparationTime == 0
      ? 0.0
      : 1.0 - (_totalRemainingTime / totalPreparationTime);

  List<double> get preparationRatios {
    List<double> ratios = [];
    int cumulativeTime = 0;
    for (var step in preparationSteps) {
      final int prepTime = step.preparationTime.inSeconds;
      ratios.add(totalPreparationTime == 0
          ? 0.0
          : cumulativeTime / totalPreparationTime);
      cumulativeTime += prepTime;
    }
    return ratios;
  }

  PreparationInfoLoadSuccess copyWith({
    List<PreparationStepEntity>? preparationSteps,
    int? currentIndex,
    int? remainingTime,
    int? totalPreparationTime,
    int? totalRemainingTime,
    int? fullTime,
    bool? isLate,
    List<bool>? preparationCompleted,
  }) {
    return PreparationInfoLoadSuccess(
      preparationSteps: preparationSteps ?? this.preparationSteps,
      currentIndex: currentIndex ?? this.currentIndex,
      remainingTime: remainingTime ?? this.remainingTime,
      totalPreparationTime: totalPreparationTime ?? this.totalPreparationTime,
      totalRemainingTime: totalRemainingTime ?? _totalRemainingTime,
      fullTime: fullTime ?? this.fullTime,
      isLate: isLate ?? this.isLate,
      preparationCompleted: preparationCompleted ?? this.preparationCompleted,
    );
  }

  @override
  List<Object?> get props => [
        preparationSteps,
        currentIndex,
        remainingTime,
        totalPreparationTime,
        _totalRemainingTime,
        fullTime,
        isLate,
        preparationCompleted,
      ];
}

class PreparationInfoLoadFailure extends AlarmScreenPreparationInfoState {
  final String errorMessage;
  const PreparationInfoLoadFailure(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}
