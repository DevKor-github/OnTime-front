part of 'alarm_screen_bloc.dart';

abstract class AlarmScreenEvent extends Equatable {
  const AlarmScreenEvent();

  @override
  List<Object?> get props => [];
}

class AlarmScreenPreparationFetched extends AlarmScreenEvent {
  final String scheduleId;
  const AlarmScreenPreparationFetched(this.scheduleId);

  @override
  List<Object?> get props => [scheduleId];
}

class AlarmScreenPreparationStarted extends AlarmScreenEvent {
  const AlarmScreenPreparationStarted();
}

class AlarmScreenTimerTicked extends AlarmScreenEvent {
  const AlarmScreenTimerTicked();
}

class AlarmScreenPreparationSkipped extends AlarmScreenEvent {
  const AlarmScreenPreparationSkipped();
}

class AlarmScreenNextPreparationSwitched extends AlarmScreenEvent {
  const AlarmScreenNextPreparationSwitched();
}

class AlarmScreenPreparationFinalized extends AlarmScreenEvent {
  const AlarmScreenPreparationFinalized();
}
