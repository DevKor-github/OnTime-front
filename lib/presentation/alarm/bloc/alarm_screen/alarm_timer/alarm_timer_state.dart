part of 'alarm_timer_bloc.dart';

abstract class AlarmTimerState extends Equatable {
  const AlarmTimerState();

  @override
  List<Object?> get props => [];
}

class TimerInitial extends AlarmTimerState {
  final int duration;
  final int currentStepIndex;
  final int elapsedTime;
  final String preparationName;
  final String preparationState;

  const TimerInitial({
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

class TimerRunInProgress extends AlarmTimerState {
  final int remainingTime;
  final int currentStepIndex;
  final int elapsedTime;
  final double progress;
  final String preparationName;
  final String preparationState;

  const TimerRunInProgress({
    required this.remainingTime,
    required this.currentStepIndex,
    required this.elapsedTime,
    required this.progress,
    required this.preparationName,
    required this.preparationState,
  });

  @override
  List<Object?> get props => [
        remainingTime,
        currentStepIndex,
        elapsedTime,
        progress,
        preparationName,
        preparationState
      ];
}

class TimerStepCompleted extends AlarmTimerState {
  final int completedStepIndex;
  const TimerStepCompleted(this.completedStepIndex);

  @override
  List<Object?> get props => [completedStepIndex];
}

class TimerAllCompleted extends AlarmTimerState {
  const TimerAllCompleted();

  @override
  List<Object?> get props => [];
}
