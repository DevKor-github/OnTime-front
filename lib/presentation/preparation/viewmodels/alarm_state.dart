// alarm_state.dart

abstract class AlarmState {
  const AlarmState();
}

class AlarmInitialState extends AlarmState {}

class AlarmPreparingState extends AlarmState {
  final List<dynamic> preparations;
  final double currentProgress;
  final int remainingTime;

  const AlarmPreparingState({
    required this.preparations,
    required this.currentProgress,
    required this.remainingTime,
  });
}

class AlarmInProgressState extends AlarmState {
  final double currentProgress;
  final String remainingTime;

  const AlarmInProgressState({
    required this.currentProgress,
    required this.remainingTime,
  });
}

class AlarmFinalizedState extends AlarmState {
  final String resultMessage;

  const AlarmFinalizedState({required this.resultMessage});
}
