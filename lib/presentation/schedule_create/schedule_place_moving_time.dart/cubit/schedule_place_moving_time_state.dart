part of 'schedule_place_moving_time_cubit.dart';

class SchedulePlaceMovingTimeState extends Equatable {
  const SchedulePlaceMovingTimeState({
    this.placeName = const SchedulePlaceInputModel.pure(),
    this.moveTime = const ScheduleMovingTimeInputModel.pure(),
  });

  final SchedulePlaceInputModel placeName;
  final ScheduleMovingTimeInputModel moveTime;

  bool get isValid => Formz.validate([placeName, moveTime]);

  SchedulePlaceMovingTimeState copyWith({
    SchedulePlaceInputModel? placeName,
    ScheduleMovingTimeInputModel? moveTime,
  }) {
    return SchedulePlaceMovingTimeState(
      placeName: placeName ?? this.placeName,
      moveTime: moveTime ?? this.moveTime,
    );
  }

  static SchedulePlaceMovingTimeState fromScheduleFormState(
      ScheduleFormState state) {
    return SchedulePlaceMovingTimeState(
      placeName: SchedulePlaceInputModel.pure(state.placeName ?? ''),
      moveTime:
          ScheduleMovingTimeInputModel.pure(state.moveTime ?? Duration.zero),
    );
  }

  @override
  List<Object> get props => [placeName, moveTime];
}
