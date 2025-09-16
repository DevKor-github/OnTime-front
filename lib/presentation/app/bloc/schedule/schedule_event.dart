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
  final ScheduleEntity? upcomingSchedule;
  final PreparationWithTime? preparation;

  ScheduleUpcomingReceived(
      ScheduleWithPreparationEntity? upcomingScheduleWithPreparation)
      : upcomingSchedule = upcomingScheduleWithPreparation,
        preparation = upcomingScheduleWithPreparation == null
            ? null
            : PreparationWithTime.fromPreparation(
                upcomingScheduleWithPreparation.preparation,
              );

  @override
  List<Object?> get props => [upcomingSchedule];
}

final class ScheduleStarted extends ScheduleEvent {
  const ScheduleStarted();

  @override
  List<Object?> get props => [];
}

final class SchedulePreparationStarted extends ScheduleEvent {
  const SchedulePreparationStarted();

  @override
  List<Object?> get props => [];
}

final class ScheduleTick extends ScheduleEvent {
  final Duration elapsed;

  const ScheduleTick(this.elapsed);

  @override
  List<Object?> get props => [elapsed];
}
