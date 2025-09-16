part of 'schedule_bloc.dart';

enum ScheduleStatus {
  initial,
  notExists,
  upcoming,
  ongoing,
  started,
}

class ScheduleState extends Equatable {
  const ScheduleState._({
    required this.status,
    this.schedule,
    this.preparation,
  });

  const ScheduleState.initial() : this._(status: ScheduleStatus.initial);

  const ScheduleState.notExists() : this._(status: ScheduleStatus.notExists);

  const ScheduleState.upcoming(
      ScheduleEntity schedule, PreparationWithTimeEntity preparation)
      : this._(
          status: ScheduleStatus.upcoming,
          schedule: schedule,
          preparation: preparation,
        );

  const ScheduleState.ongoing(
      ScheduleEntity schedule, PreparationWithTimeEntity preparation)
      : this._(
            status: ScheduleStatus.ongoing,
            schedule: schedule,
            preparation: preparation);

  const ScheduleState.started(
      ScheduleEntity schedule, PreparationWithTimeEntity preparation)
      : this._(
            status: ScheduleStatus.started,
            schedule: schedule,
            preparation: preparation);

  final ScheduleStatus status;
  final ScheduleEntity? schedule;
  final PreparationWithTimeEntity? preparation;

  ScheduleState copyWith({
    ScheduleStatus? status,
    ScheduleEntity? schedule,
    PreparationWithTimeEntity? preparation,
  }) {
    return ScheduleState._(
      status: status ?? this.status,
      schedule: schedule ?? this.schedule,
      preparation: preparation ?? this.preparation,
    );
  }

  Duration? get durationUntilPreparationStart {
    final now = DateTime.now();
    final totalDuration = schedule!.moveTime +
        preparation!.totalDuration +
        (schedule!.scheduleSpareTime ?? Duration.zero);
    final preparationStartTime = schedule!.scheduleTime.subtract(totalDuration);

    // If the target time is in the past or now, don't set a timer
    if (preparationStartTime.isBefore(now) ||
        preparationStartTime.isAtSameMomentAs(now)) {
      return null;
    }

    return preparationStartTime.difference(now);
  }

  @override
  List<Object?> get props => [status, schedule, preparation];
}
