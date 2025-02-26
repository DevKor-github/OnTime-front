part of 'schedule_spare_time_cubit.dart';

class ScheduleSpareTimeState extends Equatable {
  ScheduleSpareTimeState({
    Duration? spareTime,
  }) : spareTime = spareTime ?? Duration(minutes: 10);

  final Duration spareTime;

  factory ScheduleSpareTimeState.fromOnboardingState(OnboardingState state) {
    return ScheduleSpareTimeState(
      spareTime: state.spareTime,
    );
  }

  ScheduleSpareTimeState copyWith({
    Duration? spareTime,
  }) {
    return ScheduleSpareTimeState(
      spareTime: spareTime ?? this.spareTime,
    );
  }

  @override
  List<Object> get props => [spareTime];
}
