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
    this.currentStep,
  });

  const ScheduleState.initial() : this._(status: ScheduleStatus.initial);

  const ScheduleState.notExists() : this._(status: ScheduleStatus.notExists);

  const ScheduleState.upcoming(ScheduleWithPreparationEntity schedule)
      : this._(status: ScheduleStatus.upcoming, schedule: schedule);

  const ScheduleState.ongoing(
      ScheduleWithPreparationEntity schedule, PreparationStepEntity currentStep)
      : this._(
            status: ScheduleStatus.ongoing,
            schedule: schedule,
            currentStep: currentStep);

  const ScheduleState.started(ScheduleWithPreparationEntity schedule)
      : this._(status: ScheduleStatus.started, schedule: schedule);

  final ScheduleStatus status;
  final ScheduleWithPreparationEntity? schedule;
  final PreparationStepEntity? currentStep;

  ScheduleState copyWith({
    ScheduleStatus? status,
    ScheduleWithPreparationEntity? schedule,
    PreparationStepEntity? currentStep,
  }) {
    return ScheduleState._(
      status: status ?? this.status,
      schedule: schedule ?? this.schedule,
      currentStep: currentStep ?? this.currentStep,
    );
  }

  @override
  List<Object?> get props => [status, schedule];
}

class PreprationStepWithTime extends PreparationStepEntity
    implements Equatable {
  Duration elapsedTime;

  PreprationStepWithTime({
    required super.id,
    required super.preparationName,
    required super.preparationTime,
    required super.nextPreparationId,
    this.elapsedTime = Duration.zero,
  });

  @override
  List<Object?> get props =>
      [id, preparationName, preparationTime, nextPreparationId, elapsedTime];
}

class PreparationWithTime extends PreparationEntity implements Equatable {
  const PreparationWithTime({
    required List<PreprationStepWithTime> preparationStepList,
  }) : super(preparationStepList: preparationStepList);

  @override
  List<PreprationStepWithTime> get preparationStepList =>
      super.preparationStepList.cast<PreprationStepWithTime>();

  @override
  List<Object?> get props => [preparationStepList];
}
