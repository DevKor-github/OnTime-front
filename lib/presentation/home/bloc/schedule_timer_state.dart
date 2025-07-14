part of 'schedule_timer_bloc.dart';

sealed class ScheduleTimerState extends Equatable {
  const ScheduleTimerState();

  @override
  List<Object?> get props => [];
}

class ScheduleTimerInitial extends ScheduleTimerState {
  const ScheduleTimerInitial();
}

class ScheduleTimerRunning extends ScheduleTimerState {
  final DateTime scheduleTime;
  final DateTime currentTime;
  final Duration remainingDuration;

  const ScheduleTimerRunning({
    required this.scheduleTime,
    required this.currentTime,
    required this.remainingDuration,
  });

  @override
  List<Object?> get props => [scheduleTime, currentTime, remainingDuration];
}

class ScheduleTimerFinished extends ScheduleTimerState {
  final DateTime scheduleTime;

  const ScheduleTimerFinished({required this.scheduleTime});

  @override
  List<Object?> get props => [scheduleTime];
}
