part of 'alarm_timer_bloc.dart';

sealed class AlarmTimerState extends Equatable {
  const AlarmTimerState();

  @override
  List<Object?> get props => [];
}

class AlarmTimerInitial extends AlarmTimerState {
  final int duration;
  final int currentStepIndex;
  final int elapsedTime;
  final String preparationName;
  final String preparationState;

  const AlarmTimerInitial({
    required this.duration,
    required this.currentStepIndex,
    required this.elapsedTime,
    required this.preparationName,
    required this.preparationState,
  });

  @override
  List<Object?> get props =>
      [duration, currentStepIndex, elapsedTime, preparationState];
}

class AlarmTimerRunInProgress extends AlarmTimerState {
  final int preparationRemainingTime;
  final int currentStepIndex;
  final int preparationStepelapsedTime;
  final double progress;
  final String preparationStepName;
  final String preparationState;

  const AlarmTimerRunInProgress({
    required this.preparationRemainingTime,
    required this.currentStepIndex,
    required this.preparationStepelapsedTime,
    required this.progress,
    required this.preparationStepName,
    required this.preparationState,
  });

  @override
  List<Object?> get props => [
        preparationRemainingTime,
        currentStepIndex,
        preparationStepelapsedTime,
        progress,
        preparationStepName,
        preparationState
      ];
}

class AlarmTimerPreparationStepCompletion extends AlarmTimerState {
  final int completedStepIndex;
  const AlarmTimerPreparationStepCompletion(this.completedStepIndex);

  @override
  List<Object?> get props => [completedStepIndex];
}

class AlarmTimerPreparationCompletion extends AlarmTimerState {
  const AlarmTimerPreparationCompletion();

  @override
  List<Object?> get props => [];
}
