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
  final int totalPreparationTime; // preparation 내 준비시간 총합
  final int totalPreparationRemainingTime; // 준비 시간 중 남은 시간
  final int beforeOutTime; // 지금부터 몇분 뒤에 나가야하는지에 대한 시간. alarm screen 최상단에서 표시.
  final bool isLate;
  final List<bool> preparationCompleted;

  const AlarmScreenPreparationLoadSuccess({
    required this.preparationSteps,
    required this.currentIndex,
    required this.preparationRemainingTime,
    required this.totalPreparationTime,
    required this.totalPreparationRemainingTime,
    required this.beforeOutTime,
    required this.isLate,
    required this.preparationCompleted,
  });

// 그래프 비율 계산용 (남은 준비시간 / 총 준비시간)
  double get progress => totalPreparationTime == 0
      ? 0.0
      : 1.0 - (totalPreparationRemainingTime / totalPreparationTime);

  List<double> get preparationRatios {
    List<double> ratios = [];
    int cumulativeTime = 0;
    for (var step in preparationSteps) {
      final int prepTime = step.preparationTime.inSeconds;
      ratios.add(totalPreparationTime == 0
          ? 0.0
          : cumulativeTime / totalPreparationTime);
      cumulativeTime += prepTime;
    }
    return ratios;
  }

  AlarmScreenPreparationLoadSuccess copyWith({
    List<PreparationStepEntity>? preparationSteps,
    int? currentIndex,
    int? remainingTime,
    int? totalPreparationTime,
    int? totalRemainingTime,
    int? fullTime,
    bool? isLate,
    List<bool>? preparationCompleted,
  }) {
    return AlarmScreenPreparationLoadSuccess(
      preparationSteps: preparationSteps ?? this.preparationSteps,
      currentIndex: currentIndex ?? this.currentIndex,
      preparationRemainingTime: remainingTime ?? preparationRemainingTime,
      totalPreparationTime: totalPreparationTime ?? this.totalPreparationTime,
      totalPreparationRemainingTime:
          totalRemainingTime ?? totalPreparationRemainingTime,
      beforeOutTime: fullTime ?? beforeOutTime,
      isLate: isLate ?? this.isLate,
      preparationCompleted: preparationCompleted ?? this.preparationCompleted,
    );
  }

  @override
  List<Object?> get props => [
        preparationSteps,
        currentIndex,
        preparationRemainingTime,
        totalPreparationTime,
        totalPreparationRemainingTime,
        beforeOutTime,
        isLate,
        preparationCompleted,
      ];
}

class AlarmScreenPreparationLoadFailure
    extends AlarmScreenPreparationInfoState {
  final String errorMessage;
  const AlarmScreenPreparationLoadFailure(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}
