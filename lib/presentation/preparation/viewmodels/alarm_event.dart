// alarm_event.dart

abstract class AlarmEvent {
  const AlarmEvent();
}

class StartPreparationEvent extends AlarmEvent {
  final List<dynamic> preparations;

  const StartPreparationEvent({required this.preparations});
}

class PreparationInProgressEvent extends AlarmEvent {
  final double currentProgress;
  final String remainingTime;

  const PreparationInProgressEvent({
    required this.currentProgress,
    required this.remainingTime,
  });
}

class FinalizePreparationEvent extends AlarmEvent {
  const FinalizePreparationEvent();
}
