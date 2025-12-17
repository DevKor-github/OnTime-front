part of 'schedule_date_time_cubit.dart';

class ScheduleDateTimeState extends Equatable {
  const ScheduleDateTimeState({
    this.scheduleDate = const ScheduleDateInputModel.pure(),
    this.scheduleTime = const ScheduleTimeInputModel.pure(),
    this.isOverlapping = false,
    this.nextScheduleName,
    this.nextPreparationStartTime,
    this.previousOverlapDuration,
    this.previousScheduleName,
  });

  final ScheduleDateInputModel scheduleDate;
  final ScheduleTimeInputModel scheduleTime;
  final bool isOverlapping;
  final String? nextScheduleName;
  final DateTime? nextPreparationStartTime;
  final Duration? previousOverlapDuration;
  final String? previousScheduleName;

  bool get isValid =>
      Formz.validate([scheduleDate, scheduleTime]) && !isOverlapping;

  /// Returns true if there's an overlap warning or error to display (for next schedule)
  bool get hasOverlapMessage => isOverlapping;

  /// Returns true if there's an overlap warning or error to display (for previous schedule)
  bool get hasPreviousOverlapMessage {
    if (previousOverlapDuration == null) return false;
    // Warning only if small time (< 3 hours)
    return previousOverlapDuration!.inMinutes < 180;
  }

  /// Returns true if there's any overlap message to display
  bool get hasAnyOverlapMessage =>
      hasOverlapMessage || hasPreviousOverlapMessage;

  /// Returns the overlap message for next schedule based on whether it's an error or warning
  /// Requires BuildContext for localization
  String? getOverlapMessage(BuildContext context) {
    if (!isOverlapping) return null;

    final localizations = AppLocalizations.of(context)!;
    final scheduleName = nextScheduleName ?? '';

    String startTime = '';
    if (nextPreparationStartTime != null) {
      final timeOfDay = TimeOfDay.fromDateTime(nextPreparationStartTime!);
      startTime = timeOfDay.format(context);
    }

    return localizations.scheduleOverlapError(scheduleName, startTime);
  }

  /// Returns the overlap message for previous schedule based on whether it's an error or warning
  /// Requires BuildContext for localization
  String? getPreviousOverlapMessage(BuildContext context) {
    if (previousOverlapDuration == null) return null;

    final localizations = AppLocalizations.of(context)!;
    final minutes = previousOverlapDuration!.inMinutes.abs();
    final scheduleName = previousScheduleName ?? '';

    return localizations.scheduleOverlapWarning(minutes, scheduleName);
  }

  ScheduleDateTimeState copyWith({
    ScheduleDateInputModel? scheduleDate,
    ScheduleTimeInputModel? scheduleTime,
    bool? isOverlapping,
    String? nextScheduleName,
    DateTime? nextPreparationStartTime,
    Duration? previousOverlapDuration,
    String? previousScheduleName,
    bool clearOverlap = false,
    bool clearPreviousOverlap = false,
  }) {
    return ScheduleDateTimeState(
      scheduleDate: scheduleDate ?? this.scheduleDate,
      scheduleTime: scheduleTime ?? this.scheduleTime,
      isOverlapping:
          clearOverlap ? false : (isOverlapping ?? this.isOverlapping),
      nextScheduleName:
          clearOverlap ? null : (nextScheduleName ?? this.nextScheduleName),
      nextPreparationStartTime: clearOverlap
          ? null
          : (nextPreparationStartTime ?? this.nextPreparationStartTime),
      previousOverlapDuration: clearPreviousOverlap
          ? null
          : (previousOverlapDuration ?? this.previousOverlapDuration),
      previousScheduleName: clearPreviousOverlap
          ? null
          : (previousScheduleName ?? this.previousScheduleName),
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
        isOverlapping,
        nextScheduleName ?? '',
        nextPreparationStartTime ?? DateTime(0),
        previousOverlapDuration ?? const Duration(),
        previousScheduleName ?? '',
      ];
}
