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
  final int beforeOutTime;
  final bool isLate;

  const AlarmTimerState({
    required this.preparationSteps,
    required this.currentStepIndex,
    required this.stepElapsedTimes,
    required this.preparationStepStates,
    required this.preparationRemainingTime,
    required this.totalRemainingTime,
    required this.totalPreparationTime,
    required this.progress,
    required this.beforeOutTime,
    required this.isLate,
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
        beforeOutTime,
        isLate,
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
    int beforeOutTime,
    bool isLate,
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
    required super.beforeOutTime,
    required super.isLate,
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
    int? beforeOutTime,
    bool? isLate,
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
      beforeOutTime: beforeOutTime ?? this.beforeOutTime,
      isLate: isLate ?? this.isLate,
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
    required super.beforeOutTime,
    required super.isLate,
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
    int? beforeOutTime,
    bool? isLate,
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
      beforeOutTime: beforeOutTime ?? this.beforeOutTime,
      isLate: isLate ?? this.isLate,
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
    required super.beforeOutTime,
    required super.isLate,
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
    int? beforeOutTime,
    bool? isLate,
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
      beforeOutTime: beforeOutTime ?? this.beforeOutTime,
      isLate: isLate ?? this.isLate,
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
    required super.beforeOutTime,
    required super.isLate,
  });

// 준비 완료 상태
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
    int? beforeOutTime,
    bool? isLate,
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
      beforeOutTime: beforeOutTime ?? this.beforeOutTime,
      isLate: isLate ?? this.isLate,
    );
  }
}

// 준비 시간 만료 상태
class AlarmTimerPreparationsTimeOver extends AlarmTimerState {
  const AlarmTimerPreparationsTimeOver({
    required super.preparationSteps,
    required super.currentStepIndex,
    required super.stepElapsedTimes,
    required super.preparationStepStates,
    required super.preparationRemainingTime,
    required super.totalRemainingTime,
    required super.totalPreparationTime,
    required super.progress,
    required super.beforeOutTime,
    required super.isLate,
  });

  @override
  AlarmTimerPreparationsTimeOver copyWith({
    List<PreparationStepEntity>? preparationSteps,
    int? currentStepIndex,
    List<int>? stepElapsedTimes,
    List<PreparationStateEnum>? preparationStepStates,
    int? preparationRemainingTime,
    int? totalRemainingTime,
    int? totalPreparationTime,
    double? progress,
    int? beforeOutTime,
    bool? isLate,
  }) {
    return AlarmTimerPreparationsTimeOver(
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
      beforeOutTime: beforeOutTime ?? this.beforeOutTime,
      isLate: isLate ?? this.isLate,
    );
  }
}
