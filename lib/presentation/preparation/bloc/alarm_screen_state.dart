part of 'alarm_screen_bloc.dart';

abstract class AlarmScreenState {}

class AlarmScreenInitial extends AlarmScreenState {}

class TotalTimeInitialized extends AlarmScreenState {
  final int totalPreparationTime;
  final int totalRemainingTime;
  TotalTimeInitialized(this.totalPreparationTime, this.totalRemainingTime);
}

class FullTimeCalculated extends AlarmScreenState {
  final int fullTime;
  final bool isLate;
  FullTimeCalculated(this.fullTime, this.isLate);
}

class FullTimeTimerUpdated extends AlarmScreenState {
  final int fullTime;
  final bool isLate;
  FullTimeTimerUpdated(this.fullTime, this.isLate);
}

class PreparationRatiosCalculated extends AlarmScreenState {
  final List<double> preparationRatios;
  PreparationRatiosCalculated(this.preparationRatios);
}

class PreparationFinalized extends AlarmScreenState {}

class ProgressUpdated extends AlarmScreenState {
  final double currentProgress;
  ProgressUpdated(this.currentProgress);
}

class PreparationStarted extends AlarmScreenState {
  final int remainingTime;
  final int totalRemainingTime;
  PreparationStarted(this.remainingTime, this.totalRemainingTime);
}

class PreparationSkipped extends AlarmScreenState {}

class NextPreparationStarted extends AlarmScreenState {}

class PreparationsLoading extends AlarmScreenState {}

class PreparationsLoaded extends AlarmScreenState {
  final List<Map<String, dynamic>> preparations;
  PreparationsLoaded(this.preparations);
}

class PreparationsError extends AlarmScreenState {
  final String message;
  PreparationsError(this.message);
}
