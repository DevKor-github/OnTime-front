part of 'schedule_bloc.dart';

enum ScheduleStatus {
  initial,
  notExists,
  upcoming,
  ongoing,
  starting,
  started,
}

class ScheduleState extends Equatable {
  const ScheduleState._({
    required this.status,
    this.schedule,
  });

  const ScheduleState.initial() : this._(status: ScheduleStatus.initial);

  const ScheduleState.notExists() : this._(status: ScheduleStatus.notExists);

  const ScheduleState.upcoming(ScheduleWithPreparationEntity schedule)
      : this._(status: ScheduleStatus.upcoming, schedule: schedule);

  const ScheduleState.ongoing(ScheduleWithPreparationEntity schedule)
      : this._(status: ScheduleStatus.ongoing, schedule: schedule);

  const ScheduleState.starting(ScheduleWithPreparationEntity schedule)
      : this._(status: ScheduleStatus.starting, schedule: schedule);

  const ScheduleState.started(ScheduleWithPreparationEntity schedule)
      : this._(status: ScheduleStatus.started, schedule: schedule);

  final ScheduleStatus status;
  final ScheduleWithPreparationEntity? schedule;

  ScheduleState copyWith({
    ScheduleStatus? status,
    ScheduleWithPreparationEntity? schedule,
  }) {
    return ScheduleState._(
      status: status ?? this.status,
      schedule: schedule ?? this.schedule,
    );
  }

  @override
  List<Object?> get props => [status, schedule];
}
