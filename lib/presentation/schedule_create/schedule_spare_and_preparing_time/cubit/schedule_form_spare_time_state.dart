part of 'schedule_form_spare_time_cubit.dart';

class ScheduleFormSpareTimeState extends Equatable {
  const ScheduleFormSpareTimeState({
    this.spareTime = const ScheduleSpareTimeInputModel.pure(),
  });

  final ScheduleSpareTimeInputModel spareTime;
  bool get isValid => Formz.validate([spareTime]);

  ScheduleFormSpareTimeState copyWith({
    ScheduleSpareTimeInputModel? spareTime,
  }) {
    return ScheduleFormSpareTimeState(
      spareTime: spareTime ?? this.spareTime,
    );
  }

  static ScheduleFormSpareTimeState fromScheduleFormState(
      ScheduleFormState state) {
    return ScheduleFormSpareTimeState(
      spareTime: ScheduleSpareTimeInputModel.pure(
          state.scheduleSpareTime ?? Duration.zero),
    );
  }

  @override
  List<Object> get props => [spareTime, isValid];
}
