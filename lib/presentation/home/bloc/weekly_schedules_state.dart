part of 'weekly_schedules_bloc.dart';

enum WeeklySchedulesStatus { initial, loading, success, error }

final class WeeklySchedulesState extends Equatable {
  const WeeklySchedulesState(
      {this.status = WeeklySchedulesStatus.initial, this.schedules = const []});

  final WeeklySchedulesStatus status;
  final List<ScheduleEntity> schedules;

  List<DateTime> get dates =>
      schedules.map((schedule) => schedule.scheduleTime).toList();

  WeeklySchedulesState copyWith({
    WeeklySchedulesStatus Function()? status,
    List<ScheduleEntity> Function()? schedules,
  }) {
    return WeeklySchedulesState(
      status: status != null ? status() : this.status,
      schedules: schedules != null ? schedules() : this.schedules,
    );
  }

  @override
  List<Object> get props => [
        status,
        ...schedules,
      ];
}
