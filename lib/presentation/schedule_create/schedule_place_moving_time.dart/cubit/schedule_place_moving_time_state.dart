part of 'schedule_place_moving_time_cubit.dart';

class SchedulePlaceMovingTimeState extends Equatable {
  const SchedulePlaceMovingTimeState({
    this.placeName = const SchedulePlaceInputModel.pure(),
    this.moveTime = const ScheduleMovingTimeInputModel.pure(),
    this.overlapDuration,
    this.isOverlapping = false,
  });

  final SchedulePlaceInputModel placeName;
  final ScheduleMovingTimeInputModel moveTime;
  final Duration? overlapDuration;
  final bool isOverlapping;

  bool get isValid => Formz.validate([placeName, moveTime]) && !isOverlapping;

  /// Returns true if there's an overlap warning or error to display
  bool get hasOverlapMessage => overlapDuration != null;

  /// Returns true if the overlap is an error (already overlapping, minutes <= 0)
  bool get isOverlapError => isOverlapping;

  /// Returns the overlap message based on whether it's an error or warning
  /// Requires BuildContext for localization
  String? getOverlapMessage(BuildContext context) {
    if (overlapDuration == null) return null;

    final localizations = AppLocalizations.of(context)!;
    final minutes = overlapDuration!.inMinutes.abs();
    final scheduleName =
        context.read<ScheduleFormBloc>().state.nextScheduleName ?? '';

    if (isOverlapping) {
      return localizations.scheduleOverlapError(minutes, scheduleName);
    } else {
      return localizations.scheduleOverlapWarning(minutes, scheduleName);
    }
  }

  SchedulePlaceMovingTimeState copyWith({
    SchedulePlaceInputModel? placeName,
    ScheduleMovingTimeInputModel? moveTime,
    Duration? overlapDuration,
    bool? isOverlapping,
    bool clearOverlap = false,
  }) {
    return SchedulePlaceMovingTimeState(
      placeName: placeName ?? this.placeName,
      moveTime: moveTime ?? this.moveTime,
      overlapDuration:
          clearOverlap ? null : (overlapDuration ?? this.overlapDuration),
      isOverlapping:
          clearOverlap ? false : (isOverlapping ?? this.isOverlapping),
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
  List<Object> get props => [
        placeName,
        moveTime,
        overlapDuration ?? const Duration(),
        isOverlapping,
      ];
}
