part of 'alarm_timer_bloc.dart';

sealed class AlarmTimerState extends Equatable {
  final List<PreparationStepEntity> preparationSteps;
  final int currentStepIndex;
  final List<int> elapsedTimes;
  final List<PreparationStateEnum> preparationStates;
  final int preparationRemainingTime;
  final int totalRemainingTime;
  final int totalPreparationTime;

  const AlarmTimerState({
    required this.preparationSteps,
    required this.currentStepIndex,
    required this.elapsedTimes,
    required this.preparationStates,
    required this.preparationRemainingTime,
    required this.totalRemainingTime,
    required this.totalPreparationTime,
  });

  @override
  List<Object?> get props => [
        preparationSteps,
        currentStepIndex,
        elapsedTimes,
        preparationStates,
        preparationRemainingTime,
        totalRemainingTime,
        totalPreparationTime,
      ];

  /// 🔹 모든 상태에서 `copyWith()` 사용 가능하도록 설정
  AlarmTimerState copyWith({
    List<PreparationStepEntity>? preparationSteps,
    int? currentStepIndex,
    List<int>? elapsedTimes,
    List<PreparationStateEnum>? preparationStates,
    int? preparationRemainingTime,
    int? totalRemainingTime,
    int? totalPreparationTime,
  });
}

/// 초기 상태
class AlarmTimerInitial extends AlarmTimerState {
  const AlarmTimerInitial({
    required super.preparationSteps,
    required super.currentStepIndex,
    required super.elapsedTimes,
    required super.preparationStates,
    required super.preparationRemainingTime,
    required super.totalRemainingTime,
    required super.totalPreparationTime,
  });

  @override
  AlarmTimerInitial copyWith({
    List<PreparationStepEntity>? preparationSteps,
    int? currentStepIndex,
    List<int>? elapsedTimes,
    List<PreparationStateEnum>? preparationStates,
    int? preparationRemainingTime,
    int? totalRemainingTime,
    int? totalPreparationTime,
  }) {
    return AlarmTimerInitial(
      preparationSteps: preparationSteps ?? this.preparationSteps,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      elapsedTimes: elapsedTimes ?? this.elapsedTimes,
      preparationStates: preparationStates ?? this.preparationStates,
      preparationRemainingTime:
          preparationRemainingTime ?? this.preparationRemainingTime,
      totalRemainingTime: totalRemainingTime ?? this.totalRemainingTime,
      totalPreparationTime: totalPreparationTime ?? this.totalPreparationTime,
    );
  }
}

/// 진행 중 상태
class AlarmTimerRunInProgress extends AlarmTimerState {
  const AlarmTimerRunInProgress({
    required super.preparationSteps,
    required super.currentStepIndex,
    required super.elapsedTimes,
    required super.preparationStates,
    required super.preparationRemainingTime,
    required super.totalRemainingTime,
    required super.totalPreparationTime,
  });

  @override
  AlarmTimerRunInProgress copyWith({
    List<PreparationStepEntity>? preparationSteps,
    int? currentStepIndex,
    List<int>? elapsedTimes,
    List<PreparationStateEnum>? preparationStates,
    int? preparationRemainingTime,
    int? totalRemainingTime,
    int? totalPreparationTime,
  }) {
    return AlarmTimerRunInProgress(
      preparationSteps: preparationSteps ?? this.preparationSteps,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      elapsedTimes: elapsedTimes ?? this.elapsedTimes,
      preparationStates: preparationStates ?? this.preparationStates,
      preparationRemainingTime:
          preparationRemainingTime ?? this.preparationRemainingTime,
      totalRemainingTime: totalRemainingTime ?? this.totalRemainingTime,
      totalPreparationTime: totalPreparationTime ?? this.totalPreparationTime,
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
    required super.elapsedTimes,
    required super.preparationStates,
    required super.preparationRemainingTime,
    required super.totalRemainingTime,
    required super.totalPreparationTime,
  });

  @override
  AlarmTimerPreparationStepCompletion copyWith({
    List<PreparationStepEntity>? preparationSteps,
    int? currentStepIndex,
    List<int>? elapsedTimes,
    List<PreparationStateEnum>? preparationStates,
    int? preparationRemainingTime,
    int? totalRemainingTime,
    int? totalPreparationTime,
  }) {
    return AlarmTimerPreparationStepCompletion(
      completedStepIndex: completedStepIndex,
      preparationSteps: preparationSteps ?? this.preparationSteps,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      elapsedTimes: elapsedTimes ?? this.elapsedTimes,
      preparationStates: preparationStates ?? this.preparationStates,
      preparationRemainingTime:
          preparationRemainingTime ?? this.preparationRemainingTime,
      totalRemainingTime: totalRemainingTime ?? this.totalRemainingTime,
      totalPreparationTime: totalPreparationTime ?? this.totalPreparationTime,
    );
  }
}

/// 준비 종료 상태
class AlarmTimerPreparationCompletion extends AlarmTimerState {
  const AlarmTimerPreparationCompletion({
    required super.preparationSteps,
    required super.currentStepIndex,
    required super.elapsedTimes,
    required super.preparationStates,
    required super.preparationRemainingTime,
    required super.totalRemainingTime,
    required super.totalPreparationTime,
  });

  @override
  AlarmTimerPreparationCompletion copyWith({
    List<PreparationStepEntity>? preparationSteps,
    int? currentStepIndex,
    List<int>? elapsedTimes,
    List<PreparationStateEnum>? preparationStates,
    int? preparationRemainingTime,
    int? totalRemainingTime,
    int? totalPreparationTime,
  }) {
    return AlarmTimerPreparationCompletion(
      preparationSteps: preparationSteps ?? this.preparationSteps,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      elapsedTimes: elapsedTimes ?? this.elapsedTimes,
      preparationStates: preparationStates ?? this.preparationStates,
      preparationRemainingTime:
          preparationRemainingTime ?? this.preparationRemainingTime,
      totalRemainingTime: totalRemainingTime ?? this.totalRemainingTime,
      totalPreparationTime: totalPreparationTime ?? this.totalPreparationTime,
    );
  }
}
