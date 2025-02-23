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
  final int duration; // 남은 시간
  final int elapsedTime; // 경과 시간
  const TimerStepTicked(this.duration, this.elapsedTime);

  @override
  List<Object?> get props => [duration, elapsedTime];
}

class TimerStepSkipped extends AlarmTimerEvent {
  const TimerStepSkipped();
}

class TimerStepNext extends AlarmTimerEvent {
  const TimerStepNext();
}

class TimerStepFinalized extends AlarmTimerEvent {
  const TimerStepFinalized();
}
