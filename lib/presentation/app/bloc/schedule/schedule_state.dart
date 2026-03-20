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
    this.isEarlyStarted = false,
  });

  const ScheduleState.initial() : this._(status: ScheduleStatus.initial);

  const ScheduleState.notExists() : this._(status: ScheduleStatus.notExists);

  const ScheduleState.upcoming(ScheduleWithPreparationEntity schedule)
      : this._(status: ScheduleStatus.upcoming, schedule: schedule);

  const ScheduleState.ongoing(ScheduleWithPreparationEntity schedule)
      : this._(status: ScheduleStatus.ongoing, schedule: schedule);

  const ScheduleState.started(
    ScheduleWithPreparationEntity schedule, {
    bool isEarlyStarted = false,
  }) : this._(
          status: ScheduleStatus.started,
          schedule: schedule,
          isEarlyStarted: isEarlyStarted,
        );

  final ScheduleStatus status;
  final ScheduleWithPreparationEntity? schedule;
  final bool isEarlyStarted;

  ScheduleState copyWith({
    ScheduleStatus? status,
    ScheduleWithPreparationEntity? schedule,
    bool? isEarlyStarted,
  }) {
    return ScheduleState._(
      status: status ?? this.status,
      schedule: schedule ?? this.schedule,
      isEarlyStarted: isEarlyStarted ?? this.isEarlyStarted,
    );
  }

  Duration? get durationUntilPreparationStart {
    return durationUntilPreparationStartAt(DateTime.now());
  }

  Duration? durationUntilPreparationStartAt(DateTime now) {
    if (schedule == null) return null;
    final target = schedule!.preparationStartTime;
    if (target.isBefore(now) || target.isAtSameMomentAs(now)) return null;
    return target.difference(now);
  }

  @override
  List<Object?> get props => [
        status,
        schedule,
        schedule?.preparation,
        isEarlyStarted,
      ];
}
