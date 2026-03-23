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

final class MonthlySchedulesRefreshRequested extends MonthlySchedulesEvent {
  final DateTime date;

  const MonthlySchedulesRefreshRequested({required this.date});

  @override
  List<Object> get props => [date.year, date.month];
}

final class MonthlySchedulesScheduleDeleted extends MonthlySchedulesEvent {
  final ScheduleEntity schedule;

  const MonthlySchedulesScheduleDeleted({required this.schedule});

  @override
  List<Object> get props => [schedule];
}

final class MonthlySchedulesVisibleDateChanged extends MonthlySchedulesEvent {
  final DateTime date;

  const MonthlySchedulesVisibleDateChanged({required this.date});

  @override
  List<Object> get props => [date.year, date.month, date.day];
}

final class MonthlySchedulesPreparationsPrefetchRequested
    extends MonthlySchedulesEvent {
  final List<String> scheduleIds;

  const MonthlySchedulesPreparationsPrefetchRequested({
    required this.scheduleIds,
  });

  @override
  List<Object> get props => [scheduleIds];
}

final class MonthlySchedulesPreparationsStreamChanged
    extends MonthlySchedulesEvent {
  final Map<String, PreparationEntity> preparations;

  const MonthlySchedulesPreparationsStreamChanged({
    required this.preparations,
  });

  @override
  List<Object> get props => [preparations];
}
