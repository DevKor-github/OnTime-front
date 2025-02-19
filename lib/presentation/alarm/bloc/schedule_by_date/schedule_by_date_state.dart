part of 'schedule_by_date_bloc.dart';

abstract class ScheduleByDateState extends Equatable {
  const ScheduleByDateState();

  @override
  List<Object?> get props => [];
}

class ScheduleByDateInitial extends ScheduleByDateState {}

class ScheduleByDateLoadInProgress extends ScheduleByDateState {}

class ScheduleByDateLoadSuccess extends ScheduleByDateState {
  final List<ScheduleEntity> schedules;
  const ScheduleByDateLoadSuccess({required this.schedules});

  @override
  List<Object?> get props => [schedules];
}

class ScheduleByDateError extends ScheduleByDateState {
  final String errorMessage;
  const ScheduleByDateError({required this.errorMessage});

  @override
  List<Object?> get props => [errorMessage];
}
