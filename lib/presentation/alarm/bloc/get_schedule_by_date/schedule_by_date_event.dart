part of 'schedule_by_date_bloc.dart';

abstract class ScheduleByDateEvent extends Equatable {
  const ScheduleByDateEvent();

  @override
  List<Object?> get props => [];
}

class ScheduleListFetchEvent extends ScheduleByDateEvent {}
