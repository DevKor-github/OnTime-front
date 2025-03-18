part of 'alarm_timer_bloc.dart';

abstract class AlarmTimerEvent extends Equatable {
  const AlarmTimerEvent();

  @override
  List<Object?> get props => [];
}

class AlarmTimerStepStarted extends AlarmTimerEvent {
  final int duration;
  const AlarmTimerStepStarted(this.duration);

  @override
  List<Object?> get props => [duration];
}

class AlarmTimerStepTicked extends AlarmTimerEvent {
  final int preparationRemainingTime; // 남은 시간
  final int preparationElapsedTime; // 경과 시간
  final int totalRemainingTime;

  const AlarmTimerStepTicked({
    required this.preparationRemainingTime,
    required this.preparationElapsedTime,
    required this.totalRemainingTime,
  });

  @override
  List<Object?> get props => [preparationRemainingTime, preparationElapsedTime];
}

class AlarmTimerStepSkipped extends AlarmTimerEvent {
  const AlarmTimerStepSkipped();
}

class AlarmTimerStepNextShifted extends AlarmTimerEvent {
  const AlarmTimerStepNextShifted();
}

class AlarmTimerStepFinalized extends AlarmTimerEvent {
  const AlarmTimerStepFinalized();
}

class AlarmTimerStepsUpdated extends AlarmTimerEvent {
  final List<PreparationStepEntity> preparationSteps;

  const AlarmTimerStepsUpdated(this.preparationSteps);

  @override
  List<Object?> get props => [preparationSteps];
}
