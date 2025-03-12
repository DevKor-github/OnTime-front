part of 'schedule_spare_time_cubit.dart';

class ScheduleSpareTimeState extends Equatable {
  const ScheduleSpareTimeState({
    this.spareTime = const ScheduleSpareTimeInputModel.pure(),
  });

  final ScheduleSpareTimeInputModel spareTime;
  bool get isValid => Formz.validate([spareTime]);

  ScheduleSpareTimeState copyWith({
    ScheduleSpareTimeInputModel? spareTime,
  }) {
    return ScheduleSpareTimeState(
      spareTime: spareTime ?? this.spareTime,
    );
  }

  static ScheduleSpareTimeState fromScheduleFormState(ScheduleFormState state) {
    return ScheduleSpareTimeState(
      spareTime: ScheduleSpareTimeInputModel.pure(
          state.scheduleSpareTime ?? Duration.zero),
    );
  }

  @override
  List<Object> get props => [spareTime, isValid];
}
