part of 'schedule_date_time_cubit.dart';

class ScheduleDateTimeState extends Equatable {
  const ScheduleDateTimeState({
    this.scheduleDate = const ScheduleDateInputModel.pure(),
    this.scheduleTime = const ScheduleTimeInputModel.pure(),
    this.overlapDuration,
    this.isOverlapping = false,
    this.nextScheduleName,
  });

  final ScheduleDateInputModel scheduleDate;
  final ScheduleTimeInputModel scheduleTime;
  final Duration? overlapDuration;
  final bool isOverlapping;
  final String? nextScheduleName;

  bool get isValid =>
      Formz.validate([scheduleDate, scheduleTime]) && !isOverlapping;

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
    final scheduleName = nextScheduleName ?? '';

    if (isOverlapping) {
      return localizations.scheduleOverlapError(minutes, scheduleName);
    } else {
      return localizations.scheduleOverlapWarning(minutes, scheduleName);
    }
  }

  ScheduleDateTimeState copyWith({
    ScheduleDateInputModel? scheduleDate,
    ScheduleTimeInputModel? scheduleTime,
    Duration? overlapDuration,
    bool? isOverlapping,
    String? nextScheduleName,
    bool clearOverlap = false,
  }) {
    return ScheduleDateTimeState(
      scheduleDate: scheduleDate ?? this.scheduleDate,
      scheduleTime: scheduleTime ?? this.scheduleTime,
      overlapDuration:
          clearOverlap ? null : (overlapDuration ?? this.overlapDuration),
      isOverlapping:
          clearOverlap ? false : (isOverlapping ?? this.isOverlapping),
      nextScheduleName:
          clearOverlap ? null : (nextScheduleName ?? this.nextScheduleName),
    );
  }

  static ScheduleDateTimeState fromScheduleFormState(ScheduleFormState state) {
    return ScheduleDateTimeState(
      scheduleDate: ScheduleDateInputModel.pure(state.scheduleTime),
      scheduleTime: ScheduleTimeInputModel.pure(state.scheduleTime),
    );
  }

  @override
  List<Object> get props => [
        scheduleDate,
        scheduleTime,
        overlapDuration ?? const Duration(),
        isOverlapping,
        nextScheduleName ?? '',
      ];
}
