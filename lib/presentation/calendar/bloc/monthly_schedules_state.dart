part of 'monthly_schedules_bloc.dart';

enum MonthlySchedulesStatus { initial, loading, success, error }

final class MonthlySchedulesState extends Equatable {
  const MonthlySchedulesState(
      {this.status = MonthlySchedulesStatus.initial,
      this.schedules = const {},
      this.startDate,
      this.endDate});

  final MonthlySchedulesStatus status;
  final Map<DateTime, List<ScheduleEntity>> schedules;
  final DateTime? startDate;
  final DateTime? endDate;

  MonthlySchedulesState copyWith({
    MonthlySchedulesStatus Function()? status,
    Map<DateTime, List<ScheduleEntity>> Function()? schedules,
    DateTime? Function()? startDate,
    DateTime? Function()? endDate,
  }) {
    return MonthlySchedulesState(
      status: status != null ? status() : this.status,
      schedules: schedules != null ? schedules() : this.schedules,
      startDate: startDate != null ? startDate() : this.startDate,
      endDate: endDate != null ? endDate() : this.endDate,
    );
  }

  @override
  List<Object?> get props => [status, schedules, startDate, endDate];
}
