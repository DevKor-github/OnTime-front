part of 'alarm_screen_bloc.dart';

abstract class AlarmScreenEvent extends Equatable {
  const AlarmScreenEvent();

  @override
  List<Object?> get props => [];
}

class AlarmScreenFetchPreparation extends AlarmScreenEvent {
  final String scheduleId;
  const AlarmScreenFetchPreparation(this.scheduleId);

  @override
  List<Object?> get props => [scheduleId];
}

class AlarmScreenStartPreparation extends AlarmScreenEvent {
  const AlarmScreenStartPreparation();
}

class AlarmScreenTick extends AlarmScreenEvent {
  const AlarmScreenTick();
}

class AlarmScreenSkipPreparation extends AlarmScreenEvent {
  const AlarmScreenSkipPreparation();
}

class AlarmScreenMoveToNextPreparation extends AlarmScreenEvent {
  const AlarmScreenMoveToNextPreparation();
}

class AlarmScreenFinalizePreparation extends AlarmScreenEvent {
  const AlarmScreenFinalizePreparation();
}
