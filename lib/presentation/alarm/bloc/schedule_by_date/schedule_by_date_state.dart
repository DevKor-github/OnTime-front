part of 'schedule_by_date_bloc.dart';

sealed class ScheduleByDateState extends Equatable {
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

class ScheduleByDateLoadFailure extends ScheduleByDateState {
  final String errorMessage;
  const ScheduleByDateLoadFailure({required this.errorMessage});

  @override
  List<Object?> get props => [errorMessage];
}
