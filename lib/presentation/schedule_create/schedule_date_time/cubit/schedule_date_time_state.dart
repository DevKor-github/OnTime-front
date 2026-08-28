part of 'schedule_date_time_cubit.dart';

class ScheduleDateTimeState extends Equatable {
  static const _unset = Object();

  const ScheduleDateTimeState({
    this.scheduleDate = const ScheduleDateInputModel.pure(),
    this.scheduleTime = const ScheduleTimeInputModel.pure(),
    this.isOverlapping = false,
    this.nextScheduleName,
    this.nextPreparationStartTime,
    this.previousOverlapDuration,
    this.previousScheduleName,
    this.timeZoneId = 'UTC',
    this.civilTimeResolved = false,
    this.occurrenceOffsetOptions = const [],
    this.selectedOccurrenceOffsetSeconds,
  });

  final ScheduleDateInputModel scheduleDate;
  final ScheduleTimeInputModel scheduleTime;
  final bool isOverlapping;
  final String? nextScheduleName;
  final DateTime? nextPreparationStartTime;
  final Duration? previousOverlapDuration;
  final String? previousScheduleName;
  final String timeZoneId;
  final bool civilTimeResolved;
  final List<int> occurrenceOffsetOptions;
  final int? selectedOccurrenceOffsetSeconds;

  bool get isNonexistentCivilTime =>
      civilTimeResolved && occurrenceOffsetOptions.isEmpty;

  bool get requiresOccurrenceChoice =>
      civilTimeResolved &&
      occurrenceOffsetOptions.length > 1 &&
      selectedOccurrenceOffsetSeconds == null;

  bool get hasAmbiguousCivilTime =>
      civilTimeResolved && occurrenceOffsetOptions.length > 1;

  bool get isValid =>
      Formz.validate([scheduleDate, scheduleTime]) &&
      !isOverlapping &&
      !isPastScheduleTime &&
      !isNonexistentCivilTime &&
      !requiresOccurrenceChoice &&
      selectedOccurrenceOffsetSeconds != null;

  DateTime? get selectedScheduleDateTime {
    if (scheduleDate.value == null || scheduleTime.value == null) {
      return null;
    }
    final selectedDate = scheduleDate.value!;
    final selectedTime = scheduleTime.value!;
    return DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
  }

  bool get isPastScheduleTime {
    final selectedDateTime = selectedScheduleDateTime;
    if (selectedDateTime == null) {
      return false;
    }
    return selectedDateTime.isBefore(DateTime.now());
  }

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

  bool get hasPastScheduleTimeMessage => isPastScheduleTime;

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

  String? getPastScheduleTimeMessage(BuildContext context) {
    if (!isPastScheduleTime) return null;
    return AppLocalizations.of(context)!.scheduleTimePastError;
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
    String? timeZoneId,
    bool? civilTimeResolved,
    List<int>? occurrenceOffsetOptions,
    Object? selectedOccurrenceOffsetSeconds = _unset,
  }) {
    return ScheduleDateTimeState(
      scheduleDate: scheduleDate ?? this.scheduleDate,
      scheduleTime: scheduleTime ?? this.scheduleTime,
      isOverlapping: clearOverlap
          ? false
          : (isOverlapping ?? this.isOverlapping),
      nextScheduleName: clearOverlap
          ? null
          : (nextScheduleName ?? this.nextScheduleName),
      nextPreparationStartTime: clearOverlap
          ? null
          : (nextPreparationStartTime ?? this.nextPreparationStartTime),
      previousOverlapDuration: clearPreviousOverlap
          ? null
          : (previousOverlapDuration ?? this.previousOverlapDuration),
      previousScheduleName: clearPreviousOverlap
          ? null
          : (previousScheduleName ?? this.previousScheduleName),
      timeZoneId: timeZoneId ?? this.timeZoneId,
      civilTimeResolved: civilTimeResolved ?? this.civilTimeResolved,
      occurrenceOffsetOptions:
          occurrenceOffsetOptions ?? this.occurrenceOffsetOptions,
      selectedOccurrenceOffsetSeconds:
          identical(selectedOccurrenceOffsetSeconds, _unset)
          ? this.selectedOccurrenceOffsetSeconds
          : selectedOccurrenceOffsetSeconds as int?,
    );
  }

  static ScheduleDateTimeState fromScheduleFormState(ScheduleFormState state) {
    return ScheduleDateTimeState(
      scheduleDate: ScheduleDateInputModel.pure(state.scheduleTime),
      scheduleTime: ScheduleTimeInputModel.pure(state.scheduleTime),
      timeZoneId: state.timeZoneId,
      selectedOccurrenceOffsetSeconds: state.occurrenceOffsetSeconds,
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
    timeZoneId,
    civilTimeResolved,
    occurrenceOffsetOptions,
    selectedOccurrenceOffsetSeconds ?? 0,
  ];
}
