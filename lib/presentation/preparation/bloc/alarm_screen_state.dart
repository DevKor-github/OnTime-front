part of 'alarm_screen_bloc.dart';

abstract class AlarmScreenState extends Equatable {
  const AlarmScreenState();

  @override
  List<Object?> get props => [];
}

class AlarmScreenInitial extends AlarmScreenState {}

class AlarmScreenLoading extends AlarmScreenState {}

class AlarmScreenLoaded extends AlarmScreenState {
  final List<PreparationStepEntity> preparationSteps;
  final List<int> elapsedTimes;
  final int currentIndex;
  final int remainingTime;
  final int totalPreparationTime;
  final int totalRemainingTime;
  final double progress;
  final List<double> preparationRatios;
  final List<bool> preparationCompleted;
  final int fullTime;
  final bool isLate;

  const AlarmScreenLoaded({
    required this.preparationSteps,
    required this.elapsedTimes,
    required this.currentIndex,
    required this.remainingTime,
    required this.totalPreparationTime,
    required this.totalRemainingTime,
    required this.progress,
    required this.preparationRatios,
    required this.preparationCompleted,
    required this.fullTime,
    required this.isLate,
  });

  @override
  List<Object?> get props => [
        preparationSteps,
        elapsedTimes,
        currentIndex,
        remainingTime,
        totalPreparationTime,
        totalRemainingTime,
        progress,
        preparationRatios,
        preparationCompleted,
        fullTime,
        isLate,
      ];
}

class AlarmScreenError extends AlarmScreenState {
  final String errorMessage;
  const AlarmScreenError(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}
