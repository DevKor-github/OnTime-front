part of 'weekly_schedules_bloc.dart';

enum WeeklySchedulesStatus { initial, loading, success, error }

final class WeeklySchedulesState extends Equatable {
  const WeeklySchedulesState({
    this.status = WeeklySchedulesStatus.initial,
    this.schedules = const [],
  });

  final WeeklySchedulesStatus status;
  final List<ScheduleEntity> schedules;

  List<DateTime> get dates =>
      schedules.map((schedule) => schedule.scheduleTime).toList();
  ScheduleEntity? get todaySchedule => todayScheduleAt(DateTime.now());

  ScheduleEntity? todayScheduleAt(DateTime now) {
    final day = DeviceCivilDay.at(now);
    final candidates = <(ScheduleEntity, DateTime)>[];
    for (final schedule in schedules) {
      if (schedule.doneStatus != ScheduleDoneStatus.notEnded ||
          schedule.retainedRecurringReference) {
        continue;
      }
      final instant = ScheduleTimeResolver.resolve(
        schedule,
        nowUtc: now,
      ).instantUtc;
      if (instant != null && day.contains(instant)) {
        candidates.add((schedule, instant));
      }
    }
    candidates.sort((a, b) {
      final compared = a.$2.compareTo(b.$2);
      return compared == 0 ? a.$1.id.compareTo(b.$1.id) : compared;
    });
    return candidates.firstOrNull?.$1;
  }

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
  List<Object> get props => [status, ...schedules];
}
