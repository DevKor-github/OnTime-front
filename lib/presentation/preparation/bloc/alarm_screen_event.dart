part of 'alarm_screen_bloc.dart';

abstract class AlarmScreenEvent {}

class InitializeTotalTime extends AlarmScreenEvent {
  final List<dynamic> preparations;
  InitializeTotalTime(this.preparations);
}

class CalculateFullTime extends AlarmScreenEvent {
  final Map<String, dynamic> schedule;
  CalculateFullTime(this.schedule);
}

class StartFullTimeTimer extends AlarmScreenEvent {}

class CalculatePreparationRatios extends AlarmScreenEvent {
  final List<dynamic> preparations;
  final int totalPreparationTime;
  CalculatePreparationRatios(this.preparations, this.totalPreparationTime);
}

class FinalizePreparation extends AlarmScreenEvent {}

class UpdateProgress extends AlarmScreenEvent {
  final double newProgress;
  UpdateProgress(this.newProgress);
}

class StartPreparation extends AlarmScreenEvent {}

class SkipCurrentPreparation extends AlarmScreenEvent {}

class MoveToNextPreparation extends AlarmScreenEvent {}

class FetchPreparations extends AlarmScreenEvent {
  final int scheduleId;
  FetchPreparations(this.scheduleId);
}
