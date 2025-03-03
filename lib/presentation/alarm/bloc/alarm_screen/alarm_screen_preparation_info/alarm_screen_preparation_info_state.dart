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
  final int currentIndex;
  final int preparationRemainingTime; // 현재 준비단계의 남은 시간
  final int totalPreparationRemainingTime; // 준비 시간 중 남은 시간
  final List<bool> preparationCompleted;
  final ScheduleEntity schedule;

  const AlarmScreenPreparationLoadSuccess(
      {required this.preparationSteps,
      required this.currentIndex,
      required this.preparationRemainingTime,
      required this.totalPreparationRemainingTime,
      required this.preparationCompleted,
      required this.schedule});

  /// preparation 내 준비시간 총합 (Getter)
  int get totalPreparationTime {
    return preparationSteps.fold<int>(
        0, (sum, step) => sum + step.preparationTime.inSeconds);
  }

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

  /// 🔹 지각 여부 (Getter)
  bool get isLate => beforeOutTime < 0;

// 그래프 비율 계산용 (남은 준비시간 / 총 준비시간)
  double get progress => totalPreparationTime == 0
      ? 0.0
      : 1.0 - (totalPreparationRemainingTime / totalPreparationTime);

  AlarmScreenPreparationLoadSuccess copyWith({
    List<PreparationStepEntity>? preparationSteps,
    int? currentIndex,
    int? preparationRemainingTime,
    int? totalRemainingTime,
    List<bool>? preparationCompleted,
    ScheduleEntity? schedule,
  }) {
    return AlarmScreenPreparationLoadSuccess(
      preparationSteps: preparationSteps ?? this.preparationSteps,
      currentIndex: currentIndex ?? this.currentIndex,
      preparationRemainingTime:
          preparationRemainingTime ?? this.preparationRemainingTime,
      totalPreparationRemainingTime:
          totalRemainingTime ?? totalPreparationRemainingTime,
      preparationCompleted: preparationCompleted ?? this.preparationCompleted,
      schedule: schedule ?? this.schedule,
    );
  }

  @override
  List<Object?> get props => [
        preparationSteps,
        currentIndex,
        preparationRemainingTime,
        totalPreparationRemainingTime,
        preparationCompleted,
        schedule,
      ];
}

class AlarmScreenPreparationLoadFailure
    extends AlarmScreenPreparationInfoState {
  final String errorMessage;
  const AlarmScreenPreparationLoadFailure(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}
