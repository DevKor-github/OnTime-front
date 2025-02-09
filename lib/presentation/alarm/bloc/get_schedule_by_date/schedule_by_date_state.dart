part of 'schedule_by_date_bloc.dart';

abstract class ScheduleByDateState extends Equatable {
  const ScheduleByDateState();

  @override
  List<Object?> get props => [];
}

class ScheduleListInitial extends ScheduleByDateState {}

class ScheduleListLoadInProgress extends ScheduleByDateState {}

class ScheduleListLoadSuccess extends ScheduleByDateState {
  final List<ScheduleEntity> schedules;
  const ScheduleListLoadSuccess({required this.schedules});

  @override
  List<Object?> get props => [schedules];
}

class ScheduleListError extends ScheduleByDateState {
  final String errorMessage;
  const ScheduleListError({required this.errorMessage});

  @override
  List<Object?> get props => [errorMessage];
}
