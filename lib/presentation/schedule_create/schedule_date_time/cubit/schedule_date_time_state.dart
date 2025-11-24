part of 'schedule_date_time_cubit.dart';

class ScheduleDateTimeState extends Equatable {
  const ScheduleDateTimeState({
    this.scheduleDate = const ScheduleDateInputModel.pure(),
    this.scheduleTime = const ScheduleTimeInputModel.pure(),
    this.overlapMinutes,
    this.isOverlapping = false,
  });

  final ScheduleDateInputModel scheduleDate;
  final ScheduleTimeInputModel scheduleTime;
  final int? overlapMinutes;
  final bool isOverlapping;

  bool get isValid => Formz.validate([scheduleDate, scheduleTime]);

  /// Returns true if there's an overlap warning or error to display
  bool get hasOverlapMessage => overlapMinutes != null;

  /// Returns true if the overlap is an error (already overlapping, minutes <= 0)
  bool get isOverlapError => isOverlapping;

  /// Returns the overlap message based on whether it's an error or warning
  /// Requires BuildContext for localization
  String? getOverlapMessage(BuildContext context) {
    if (overlapMinutes == null) return null;

    final localizations = AppLocalizations.of(context)!;
    final minutes = overlapMinutes!.abs();

    if (isOverlapping) {
      return localizations.scheduleOverlapError(minutes);
    } else {
      return localizations.scheduleOverlapWarning(minutes);
    }
  }

  ScheduleDateTimeState copyWith({
    ScheduleDateInputModel? scheduleDate,
    ScheduleTimeInputModel? scheduleTime,
    int? overlapMinutes,
    bool? isOverlapping,
    bool clearOverlap = false,
  }) {
    return ScheduleDateTimeState(
      scheduleDate: scheduleDate ?? this.scheduleDate,
      scheduleTime: scheduleTime ?? this.scheduleTime,
      overlapMinutes:
          clearOverlap ? null : (overlapMinutes ?? this.overlapMinutes),
      isOverlapping:
          clearOverlap ? false : (isOverlapping ?? this.isOverlapping),
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
        overlapMinutes ?? 0,
        isOverlapping,
      ];
}
