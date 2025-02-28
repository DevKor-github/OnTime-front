part of 'alarm_timer_bloc.dart';

abstract class AlarmTimerEvent extends Equatable {
  const AlarmTimerEvent();

  @override
  List<Object?> get props => [];
}

class TimerStepStarted extends AlarmTimerEvent {
  final int duration;
  const TimerStepStarted(this.duration);

  @override
  List<Object?> get props => [duration];
}

class TimerStepTicked extends AlarmTimerEvent {
  final int preparationRemainingTime; // 남은 시간
  final int preparationElapsedTime; // 경과 시간

  const TimerStepTicked({
    required this.preparationRemainingTime,
    required this.preparationElapsedTime,
  });

  @override
  List<Object?> get props => [preparationRemainingTime, preparationElapsedTime];
}

class TimerStepSkipped extends AlarmTimerEvent {
  const TimerStepSkipped();
}

class TimerStepNextShifted extends AlarmTimerEvent {
  const TimerStepNextShifted();
}

class TimerStepFinalized extends AlarmTimerEvent {
  const TimerStepFinalized();
}
