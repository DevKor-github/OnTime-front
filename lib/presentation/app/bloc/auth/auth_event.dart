part of 'auth_bloc.dart';

abstract class AuthEvent {
  const AuthEvent();
}

final class AuthUserSubscriptionRequested extends AuthEvent {
  const AuthUserSubscriptionRequested();
}

final class AuthSignOutPressed extends AuthEvent {
  const AuthSignOutPressed();
}

final class AuthUpcomingScheduleSubscriptionRequested extends AuthEvent {
  const AuthUpcomingScheduleSubscriptionRequested();
}

final class AuthUpcomingScheduleReceived extends AuthEvent {
  final ScheduleWithPreparationEntity? nearestUpcomingSchedule;

  const AuthUpcomingScheduleReceived(this.nearestUpcomingSchedule);
}

final class AuthPreparationStarted extends AuthEvent {
  final ScheduleWithPreparationEntity schedule;

  const AuthPreparationStarted(this.schedule);
}
