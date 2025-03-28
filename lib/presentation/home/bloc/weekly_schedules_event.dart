part of 'weekly_schedules_bloc.dart';

sealed class WeeklySchedulesEvent extends Equatable {
  const WeeklySchedulesEvent();

  @override
  List<Object> get props => [];
}

final class WeeklySchedulesSubscriptionRequested extends WeeklySchedulesEvent {
  final DateTime date;

  const WeeklySchedulesSubscriptionRequested({required this.date});

  DateTime get startDate => date.subtract(Duration(days: date.weekday - 1));
  DateTime get endDate => startDate.add(Duration(days: 7));

  @override
  List<Object> get props => [startDate, endDate];
}
