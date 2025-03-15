part of 'schedule_date_time_cubit.dart';

class ScheduleDateTimeState extends Equatable {
  const ScheduleDateTimeState({
    this.scheduleDate = const ScheduleDateInputModel.pure(),
    this.scheduleTime = const ScheduleTimeInputModel.pure(),
  });

  final ScheduleDateInputModel scheduleDate;
  final ScheduleTimeInputModel scheduleTime;

  bool get isValid => Formz.validate([scheduleDate, scheduleTime]);

  ScheduleDateTimeState copyWith({
    ScheduleDateInputModel? scheduleDate,
    ScheduleTimeInputModel? scheduleTime,
  }) {
    return ScheduleDateTimeState(
      scheduleDate: scheduleDate ?? this.scheduleDate,
      scheduleTime: scheduleTime ?? this.scheduleTime,
    );
  }

  static ScheduleDateTimeState fromScheduleFormState(ScheduleFormState state) {
    return ScheduleDateTimeState(
      scheduleDate: ScheduleDateInputModel.pure(state.scheduleTime),
      scheduleTime: ScheduleTimeInputModel.pure(state.scheduleTime),
    );
  }

  @override
  List<Object> get props => [scheduleDate, scheduleTime];
}
