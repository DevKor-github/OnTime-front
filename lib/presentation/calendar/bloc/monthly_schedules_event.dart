part of 'monthly_schedules_bloc.dart';

sealed class MonthlySchedulesEvent extends Equatable {
  const MonthlySchedulesEvent();

  @override
  List<Object> get props => [];
}

final class MonthlySchedulesSubscriptionRequested
    extends MonthlySchedulesEvent {
  final DateTime date;

  const MonthlySchedulesSubscriptionRequested({required this.date});

  DateTime get startDate => DateTime(date.year, date.month, 1);
  DateTime get endDate => DateTime(date.year, date.month + 1, 1);

  @override
  List<Object> get props => [startDate, endDate];
}

final class MonthlySchedulesMonthAdded extends MonthlySchedulesEvent {
  final DateTime date;

  const MonthlySchedulesMonthAdded({required this.date});

  DateTime get startDate => DateTime(date.year, date.month, 1);
  DateTime get endDate => DateTime(date.year, date.month + 1, 1);

  @override
  List<Object> get props => [date];
}
