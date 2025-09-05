part of 'schedule_bloc.dart';

class ScheduleEvent extends Equatable {
  const ScheduleEvent();

  @override
  List<Object?> get props => [];
}

final class ScheduleSubscriptionRequested extends ScheduleEvent {
  const ScheduleSubscriptionRequested();

  @override
  List<Object?> get props => [];
}

final class ScheduleUpcomingReceived extends ScheduleEvent {
  final ScheduleWithPreparationEntity? upcomingSchedule;

  const ScheduleUpcomingReceived(this.upcomingSchedule);

  @override
  List<Object?> get props => [upcomingSchedule];
}

final class ScheduleStarted extends ScheduleEvent {
  const ScheduleStarted();

  @override
  List<Object?> get props => [];
}
