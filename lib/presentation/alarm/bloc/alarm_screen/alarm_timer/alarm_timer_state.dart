part of 'alarm_timer_bloc.dart';

sealed class AlarmTimerState extends Equatable {
  final List<PreparationStepEntity> preparationSteps;
  final int currentStepIndex;
  final List<int> stepElapsedTimes;
  final List<PreparationStateEnum> preparationStepStates;
  final int preparationRemainingTime;
  final int totalRemainingTime;
  final int totalPreparationTime;

  final double progress;

  const AlarmTimerState({
    required this.preparationSteps,
    required this.currentStepIndex,
    required this.stepElapsedTimes,
    required this.preparationStepStates,
    required this.preparationRemainingTime,
    required this.totalRemainingTime,
    required this.totalPreparationTime,
    required this.progress,
  });

  @override
  List<Object?> get props => [
        preparationSteps,
        currentStepIndex,
        stepElapsedTimes,
        preparationStepStates,
        preparationRemainingTime,
        totalRemainingTime,
        totalPreparationTime,
        progress,
      ];

  AlarmTimerState copyWith({
    List<PreparationStepEntity>? preparationSteps,
    int? currentStepIndex,
    List<int>? stepElapsedTimes,
    List<PreparationStateEnum>? preparationStepStates,
    int? preparationRemainingTime,
    int? totalRemainingTime,
    int? totalPreparationTime,
    double? progress,
  });
}

/// 초기 상태
class AlarmTimerInitial extends AlarmTimerState {
  const AlarmTimerInitial({
    required super.preparationSteps,
    required super.currentStepIndex,
    required super.stepElapsedTimes,
    required super.preparationStepStates,
    required super.preparationRemainingTime,
    required super.totalRemainingTime,
    required super.totalPreparationTime,
    required super.progress,
  });

  @override
  AlarmTimerInitial copyWith({
    List<PreparationStepEntity>? preparationSteps,
    int? currentStepIndex,
    List<int>? stepElapsedTimes,
    List<PreparationStateEnum>? preparationStepStates,
    int? preparationRemainingTime,
    int? totalRemainingTime,
    int? totalPreparationTime,
    double? progress,
  }) {
    return AlarmTimerInitial(
      preparationSteps: preparationSteps ?? this.preparationSteps,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      stepElapsedTimes: stepElapsedTimes ?? this.stepElapsedTimes,
      preparationStepStates:
          preparationStepStates ?? this.preparationStepStates,
      preparationRemainingTime:
          preparationRemainingTime ?? this.preparationRemainingTime,
      totalRemainingTime: totalRemainingTime ?? this.totalRemainingTime,
      totalPreparationTime: totalPreparationTime ?? this.totalPreparationTime,
      progress: progress ?? this.progress,
    );
  }
}

/// 진행 중 상태
class AlarmTimerRunInProgress extends AlarmTimerState {
  const AlarmTimerRunInProgress({
    required super.preparationSteps,
    required super.currentStepIndex,
    required super.stepElapsedTimes,
    required super.preparationStepStates,
    required super.preparationRemainingTime,
    required super.totalRemainingTime,
    required super.totalPreparationTime,
    required super.progress,
  });

  @override
  AlarmTimerRunInProgress copyWith({
    List<PreparationStepEntity>? preparationSteps,
    int? currentStepIndex,
    List<int>? stepElapsedTimes,
    List<PreparationStateEnum>? preparationStepStates,
    int? preparationRemainingTime,
    int? totalRemainingTime,
    int? totalPreparationTime,
    double? progress,
  }) {
    return AlarmTimerRunInProgress(
      preparationSteps: preparationSteps ?? this.preparationSteps,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      stepElapsedTimes: stepElapsedTimes ?? this.stepElapsedTimes,
      preparationStepStates:
          preparationStepStates ?? this.preparationStepStates,
      preparationRemainingTime:
          preparationRemainingTime ?? this.preparationRemainingTime,
      totalRemainingTime: totalRemainingTime ?? this.totalRemainingTime,
      totalPreparationTime: totalPreparationTime ?? this.totalPreparationTime,
      progress: progress ?? this.progress,
    );
  }
}

/// 준비 단계 완료 상태
class AlarmTimerPreparationStepCompletion extends AlarmTimerState {
  final int completedStepIndex;

  const AlarmTimerPreparationStepCompletion({
    required this.completedStepIndex,
    required super.preparationSteps,
    required super.currentStepIndex,
    required super.stepElapsedTimes,
    required super.preparationStepStates,
    required super.preparationRemainingTime,
    required super.totalRemainingTime,
    required super.totalPreparationTime,
    required super.progress,
  });

  @override
  AlarmTimerPreparationStepCompletion copyWith({
    List<PreparationStepEntity>? preparationSteps,
    int? currentStepIndex,
    List<int>? stepElapsedTimes,
    List<PreparationStateEnum>? preparationStepStates,
    int? preparationRemainingTime,
    int? totalRemainingTime,
    int? totalPreparationTime,
    double? progress,
  }) {
    return AlarmTimerPreparationStepCompletion(
      completedStepIndex: completedStepIndex,
      preparationSteps: preparationSteps ?? this.preparationSteps,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      stepElapsedTimes: stepElapsedTimes ?? this.stepElapsedTimes,
      preparationStepStates:
          preparationStepStates ?? this.preparationStepStates,
      preparationRemainingTime:
          preparationRemainingTime ?? this.preparationRemainingTime,
      totalRemainingTime: totalRemainingTime ?? this.totalRemainingTime,
      totalPreparationTime: totalPreparationTime ?? this.totalPreparationTime,
      progress: progress ?? this.progress,
    );
  }
}

/// 준비 종료 상태
class AlarmTimerPreparationCompletion extends AlarmTimerState {
  const AlarmTimerPreparationCompletion({
    required super.preparationSteps,
    required super.currentStepIndex,
    required super.stepElapsedTimes,
    required super.preparationStepStates,
    required super.preparationRemainingTime,
    required super.totalRemainingTime,
    required super.totalPreparationTime,
    required super.progress,
  });

  @override
  AlarmTimerPreparationCompletion copyWith({
    List<PreparationStepEntity>? preparationSteps,
    int? currentStepIndex,
    List<int>? stepElapsedTimes,
    List<PreparationStateEnum>? preparationStepStates,
    int? preparationRemainingTime,
    int? totalRemainingTime,
    int? totalPreparationTime,
    double? progress,
  }) {
    return AlarmTimerPreparationCompletion(
      preparationSteps: preparationSteps ?? this.preparationSteps,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      stepElapsedTimes: stepElapsedTimes ?? this.stepElapsedTimes,
      preparationStepStates:
          preparationStepStates ?? this.preparationStepStates,
      preparationRemainingTime:
          preparationRemainingTime ?? this.preparationRemainingTime,
      totalRemainingTime: totalRemainingTime ?? this.totalRemainingTime,
      totalPreparationTime: totalPreparationTime ?? this.totalPreparationTime,
      progress: progress ?? this.progress,
    );
  }
}
