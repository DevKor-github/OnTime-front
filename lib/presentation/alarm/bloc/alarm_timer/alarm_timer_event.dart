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
  final int beforeOutTime; // 나가기 전까지 남은 시간
  final bool isLate; // 지각 여부

  const AlarmTimerStepTicked({
    required this.preparationRemainingTime,
    required this.preparationElapsedTime,
    required this.totalRemainingTime,
    required this.beforeOutTime,
    required this.isLate,
  });

  @override
  List<Object?> get props => [
        preparationRemainingTime,
        preparationElapsedTime,
        totalRemainingTime,
        beforeOutTime,
        isLate,
      ];
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
