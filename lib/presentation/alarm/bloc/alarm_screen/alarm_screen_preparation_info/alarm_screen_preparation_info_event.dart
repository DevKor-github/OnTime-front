part of 'alarm_screen_preparation_info_bloc.dart';

abstract class AlarmScreenPreparationInfoEvent extends Equatable {
  const AlarmScreenPreparationInfoEvent();

  @override
  List<Object?> get props => [];
}

class AlarmScreenPreparationLoadingRequested
    extends AlarmScreenPreparationInfoEvent {}

class AlarmScreenPreparationSubscriptionRequested
    extends AlarmScreenPreparationInfoEvent {
  final String scheduleId;
  final ScheduleEntity schedule;

  const AlarmScreenPreparationSubscriptionRequested({
    required this.scheduleId,
    required this.schedule,
  });
  @override
  List<Object?> get props => [scheduleId, schedule];
}
