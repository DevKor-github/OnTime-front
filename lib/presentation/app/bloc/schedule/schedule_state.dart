part of 'schedule_bloc.dart';

enum ScheduleStatus {
  initial,
  notExists,
  upcoming,
  ongoing,
  started,
}

class ScheduleState extends Equatable {
  const ScheduleState._({
    required this.status,
    this.schedule,
    this.preparation,
  });

  const ScheduleState.initial() : this._(status: ScheduleStatus.initial);

  const ScheduleState.notExists() : this._(status: ScheduleStatus.notExists);

  const ScheduleState.upcoming(
      ScheduleEntity schedule, PreparationWithTime preparation)
      : this._(
          status: ScheduleStatus.upcoming,
          schedule: schedule,
          preparation: preparation,
        );

  const ScheduleState.ongoing(
      ScheduleEntity schedule, PreparationWithTime preparation)
      : this._(
            status: ScheduleStatus.ongoing,
            schedule: schedule,
            preparation: preparation);

  const ScheduleState.started(
      ScheduleEntity schedule, PreparationWithTime preparation)
      : this._(
            status: ScheduleStatus.started,
            schedule: schedule,
            preparation: preparation);

  final ScheduleStatus status;
  final ScheduleEntity? schedule;
  final PreparationWithTime? preparation;

  ScheduleState copyWith({
    ScheduleStatus? status,
    ScheduleEntity? schedule,
    PreparationWithTime? preparation,
  }) {
    return ScheduleState._(
      status: status ?? this.status,
      schedule: schedule ?? this.schedule,
      preparation: preparation ?? this.preparation,
    );
  }

  Duration? get durationUntilPreparationStart {
    final now = DateTime.now();
    final totalDuration = schedule!.moveTime +
        preparation!.totalDuration +
        (schedule!.scheduleSpareTime ?? Duration.zero);
    final preparationStartTime = schedule!.scheduleTime.subtract(totalDuration);

    // If the target time is in the past or now, don't set a timer
    if (preparationStartTime.isBefore(now) ||
        preparationStartTime.isAtSameMomentAs(now)) {
      return null;
    }

    return preparationStartTime.difference(now);
  }

  @override
  List<Object?> get props => [status, schedule, preparation];
}

class PreparationStepWithTime extends PreparationStepEntity {
  final Duration elapsedTime;
  final bool isDone;

  const PreparationStepWithTime({
    required super.id,
    required super.preparationName,
    required super.preparationTime,
    required super.nextPreparationId,
    this.elapsedTime = Duration.zero,
    this.isDone = false,
  });

  @override
  PreparationStepWithTime copyWith({
    String? id,
    String? preparationName,
    Duration? preparationTime,
    String? nextPreparationId,
    Duration? elapsedTime,
    bool? isDone,
  }) {
    return PreparationStepWithTime(
      id: id ?? this.id,
      preparationName: preparationName ?? this.preparationName,
      preparationTime: preparationTime ?? this.preparationTime,
      nextPreparationId: nextPreparationId ?? this.nextPreparationId,
      elapsedTime: elapsedTime ?? this.elapsedTime,
      isDone: isDone ?? this.isDone,
    );
  }

  PreparationStepWithTime timeElapsed(Duration elapsed) {
    final updatedElapsed = elapsedTime + elapsed;
    final updatedIsDone = updatedElapsed >= preparationTime;
    return copyWith(
      elapsedTime: updatedElapsed,
      isDone: updatedIsDone,
    );
  }

  @override
  List<Object?> get props => [
        id,
        preparationName,
        preparationTime,
        nextPreparationId,
        elapsedTime,
        isDone
      ];
}

class PreparationWithTime extends PreparationEntity implements Equatable {
  const PreparationWithTime({
    required List<PreparationStepWithTime> preparationStepList,
  }) : super(preparationStepList: preparationStepList);

  factory PreparationWithTime.fromPreparation(PreparationEntity preparation) {
    return PreparationWithTime(
      preparationStepList: preparation.preparationStepList
          .map(
            (step) => PreparationStepWithTime(
              id: step.id,
              preparationName: step.preparationName,
              preparationTime: step.preparationTime,
              nextPreparationId: step.nextPreparationId,
            ),
          )
          .toList(),
    );
  }

  PreparationWithTime copyWith({
    List<PreparationStepWithTime>? preparationStepList,
  }) {
    return PreparationWithTime(
      preparationStepList: preparationStepList ?? this.preparationStepList,
    );
  }

  @override
  List<PreparationStepWithTime> get preparationStepList =>
      super.preparationStepList.cast<PreparationStepWithTime>();

  PreparationStepWithTime get currentStep => preparationStepList.firstWhere(
        (step) => !step.isDone,
      );

  PreparationWithTime timeElapsed(Duration elapsed) {
    final updatedCurrentStep = currentStep.timeElapsed(elapsed);
    return copyWith(
      preparationStepList: preparationStepList
          .map((step) =>
              step.id == updatedCurrentStep.id ? updatedCurrentStep : step)
          .toList(),
    );
  }

  @override
  List<Object?> get props => [preparationStepList];
}
