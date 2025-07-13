part of 'schedule_timer_bloc.dart';

abstract class ScheduleTimerEvent extends Equatable {
  const ScheduleTimerEvent();

  @override
  List<Object?> get props => [];
}

class ScheduleTimerStarted extends ScheduleTimerEvent {
  final DateTime scheduleTime;

  const ScheduleTimerStarted(this.scheduleTime);

  @override
  List<Object?> get props => [scheduleTime];
}

class ScheduleTimerTicked extends ScheduleTimerEvent {
  final DateTime currentTime;

  const ScheduleTimerTicked(this.currentTime);

  @override
  List<Object?> get props => [currentTime];
}

class ScheduleTimerStopped extends ScheduleTimerEvent {
  const ScheduleTimerStopped();
}

class ScheduleTimerUpdated extends ScheduleTimerEvent {
  final DateTime? scheduleTime;

  const ScheduleTimerUpdated(this.scheduleTime);

  @override
  List<Object?> get props => [scheduleTime];
}
