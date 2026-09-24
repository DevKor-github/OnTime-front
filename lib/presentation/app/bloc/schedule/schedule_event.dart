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

  const ScheduleUpcomingReceived(
    ScheduleWithPreparationEntity? upcomingScheduleWithPreparation,
  ) : upcomingSchedule = upcomingScheduleWithPreparation;

  @override
  List<Object?> get props => [upcomingSchedule];
}

final class ScheduleAlarmPromptRequested extends ScheduleEvent {
  final String scheduleId;
  final String? scheduleFingerprint;
  final bool startPreparation;

  const ScheduleAlarmPromptRequested({
    required this.scheduleId,
    this.scheduleFingerprint,
    this.startPreparation = false,
  });

  @override
  List<Object?> get props => [
    scheduleId,
    scheduleFingerprint,
    startPreparation,
  ];
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

enum PreparationRefreshOrigin { periodic, resume, restore, manual }

final class SchedulePreparationTimeRefreshRequested extends ScheduleEvent {
  const SchedulePreparationTimeRefreshRequested({
    this.origin = PreparationRefreshOrigin.manual,
  });

  final PreparationRefreshOrigin origin;

  @override
  List<Object?> get props => [origin];
}

final class ScheduleStepSkipped extends ScheduleEvent {
  const ScheduleStepSkipped();
}

final class ScheduleFinished extends ScheduleEvent {
  final int latenessTime;

  const ScheduleFinished(this.latenessTime);

  @override
  List<Object?> get props => [latenessTime];
}

final class _NotificationPromptPresented extends ScheduleEvent {
  const _NotificationPromptPresented(this.schedule, this.owner, this.isCurrent);
  final ScheduleWithPreparationEntity schedule;
  final Object owner;
  final bool Function() isCurrent;
  @override
  List<Object?> get props => [schedule, owner];
}
