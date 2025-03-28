part of 'app_bloc.dart';

abstract class AppEvent {
  const AppEvent();
}

final class AppUserSubscriptionRequested extends AppEvent {
  const AppUserSubscriptionRequested();
}

final class AppSignOutPressed extends AppEvent {
  const AppSignOutPressed();
}

final class AppUpcomingScheduleSubscriptionRequested extends AppEvent {
  const AppUpcomingScheduleSubscriptionRequested();
}

final class AppUpcomingScheduleReceived extends AppEvent {
  final ScheduleWithPreparationEntity? nearestUpcomingSchedule;

  const AppUpcomingScheduleReceived(this.nearestUpcomingSchedule);
}

final class AppPreparationStarted extends AppEvent {
  final ScheduleWithPreparationEntity schedule;

  const AppPreparationStarted(this.schedule);
}
