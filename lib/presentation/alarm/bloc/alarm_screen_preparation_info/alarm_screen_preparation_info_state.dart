part of 'alarm_screen_preparation_info_bloc.dart';

sealed class AlarmScreenPreparationInfoState extends Equatable {
  const AlarmScreenPreparationInfoState();

  @override
  List<Object?> get props => [];
}

class AlarmScreenPreparationInitial extends AlarmScreenPreparationInfoState {}

class AlarmScreenPreparationInfoLoadInProgress
    extends AlarmScreenPreparationInfoState {}

class AlarmScreenPreparationLoadSuccess
    extends AlarmScreenPreparationInfoState {
  final List<PreparationStepEntity> preparationSteps;
  final ScheduleEntity schedule;

  const AlarmScreenPreparationLoadSuccess({
    required this.preparationSteps,
    required this.schedule,
  });

  /// 지금부터 몇분 뒤에 나가야하는지에 대한 시간. alarm screen 최상단에서 표시.
  int get beforeOutTime {
    final DateTime now = DateTime.now();
    final Duration spareTime = schedule.scheduleSpareTime;
    final DateTime scheduleTime = schedule.scheduleTime;
    final Duration moveTime = schedule.moveTime;
    final Duration remainingDuration =
        scheduleTime.difference(now) - moveTime - spareTime;
    return remainingDuration.inSeconds;
  }

  /// 지각 여부 (Getter)
  bool get isLate => beforeOutTime < 0;

  AlarmScreenPreparationLoadSuccess copyWith({
    List<PreparationStepEntity>? preparationSteps,
    int? currentIndex,
    ScheduleEntity? schedule,
  }) {
    return AlarmScreenPreparationLoadSuccess(
      preparationSteps: preparationSteps ?? this.preparationSteps,
      schedule: schedule ?? this.schedule,
    );
  }

  @override
  List<Object?> get props => [
        preparationSteps,
      ];
}

class AlarmScreenPreparationLoadFailure
    extends AlarmScreenPreparationInfoState {
  final String errorMessage;
  const AlarmScreenPreparationLoadFailure(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}
