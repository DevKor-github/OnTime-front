part of 'monthly_schedules_bloc.dart';

enum MonthlySchedulesStatus { initial, loading, success, error }

final class MonthlySchedulesState extends Equatable {
  const MonthlySchedulesState(
      {this.status = MonthlySchedulesStatus.initial,
      this.schedules = const {},
      this.preparationDurationByScheduleId = const {},
      this.lastDeletedSchedule,
      this.startDate,
      this.endDate,
      this.visibleDate});

  final MonthlySchedulesStatus status;
  final Map<DateTime, List<ScheduleEntity>> schedules;
  final Map<String, Duration> preparationDurationByScheduleId;
  final ScheduleEntity? lastDeletedSchedule;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? visibleDate;

  MonthlySchedulesState copyWith({
    MonthlySchedulesStatus Function()? status,
    Map<DateTime, List<ScheduleEntity>> Function()? schedules,
    Map<String, Duration> Function()? preparationDurationByScheduleId,
    ScheduleEntity? Function()? lastDeletedSchedule,
    DateTime? Function()? startDate,
    DateTime? Function()? endDate,
    DateTime? Function()? visibleDate,
  }) {
    return MonthlySchedulesState(
      status: status != null ? status() : this.status,
      schedules: schedules != null ? schedules() : this.schedules,
      preparationDurationByScheduleId: preparationDurationByScheduleId != null
          ? preparationDurationByScheduleId()
          : this.preparationDurationByScheduleId,
      lastDeletedSchedule: lastDeletedSchedule != null
          ? lastDeletedSchedule()
          : this.lastDeletedSchedule,
      startDate: startDate != null ? startDate() : this.startDate,
      endDate: endDate != null ? endDate() : this.endDate,
      visibleDate: visibleDate != null ? visibleDate() : this.visibleDate,
    );
  }

  @override
  List<Object?> get props => [
        status,
        schedules,
        preparationDurationByScheduleId,
        lastDeletedSchedule,
        startDate,
        endDate,
        visibleDate,
      ];
}
