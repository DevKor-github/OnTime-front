part of 'schedule_form_bloc.dart';

enum ScheduleFormStatus { initial, loading, success, error }

enum ScheduleFormSubmissionStatus {
  idle,
  submitting,
  success,
  failure,
  review,
  timeChoice,
  deliveryPending,
}

enum IsPreparationChanged { changed, unchanged }

final class ScheduleFormState extends Equatable {
  static const _unset = Object();

  final ScheduleEditBaseline? baseline;
  final String mutationId;
  final ScheduleSaveReceipt? saveReceipt;
  final ScheduleSaveFailure? saveFailure;
  final ScheduleFormStatus status;
  final ScheduleFormSubmissionStatus submissionStatus;
  final String? submissionError;
  final String id;
  final String? placeId;
  final String? placeName;
  final String? scheduleName;
  final DateTime? scheduleTime;
  final String timeZoneId;
  final int? occurrenceOffsetSeconds;
  final Duration? moveTime;
  final IsPreparationChanged isChanged;
  final Duration? scheduleSpareTime;
  final String? scheduleNote;
  final PreparationEntity? preparation;
  final SchedulePreparationMode? originalPreparationMode;
  final ScheduleEntity? originalSchedule;
  final PreparationEntity? originalPreparation;
  final RecurrenceRule? recurrenceRule;
  final RecurringEditScope recurringScope;
  final bool recurrenceCountChanged;
  final RecurrenceReview? recurrenceReview;
  final DateTime? repeatedTimeDate;
  final bool isValid;
  final Duration? maxAvailableTime;
  final String? previousScheduleName;

  ScheduleFormState({
    this.baseline,
    String? mutationId,
    this.saveReceipt,
    this.saveFailure,
    this.status = ScheduleFormStatus.initial,
    this.submissionStatus = ScheduleFormSubmissionStatus.idle,
    this.submissionError,
    String? id,
    this.placeId,
    this.placeName,
    this.scheduleName,
    this.scheduleTime,
    this.timeZoneId = 'UTC',
    this.occurrenceOffsetSeconds,
    this.moveTime,
    this.isChanged = IsPreparationChanged.unchanged,
    this.scheduleSpareTime,
    this.scheduleNote,
    this.preparation,
    this.originalPreparationMode,
    this.originalSchedule,
    this.originalPreparation,
    this.recurrenceRule,
    this.recurringScope = RecurringEditScope.occurrence,
    this.recurrenceCountChanged = false,
    this.recurrenceReview,
    this.repeatedTimeDate,
    this.isValid = false,
    this.maxAvailableTime,
    this.previousScheduleName,
  }) : mutationId = mutationId ?? const Uuid().v7(),
       id = id ?? Uuid().v7();

  ScheduleFormState copyWith({
    ScheduleEditBaseline? baseline,
    String? mutationId,
    ScheduleSaveReceipt? saveReceipt,
    Object? saveFailure = _unset,
    ScheduleFormStatus? status,
    ScheduleFormSubmissionStatus? submissionStatus,
    Object? submissionError = _unset,
    String? id,
    String? placeId,
    String? placeName,
    String? scheduleName,
    DateTime? scheduleTime,
    String? timeZoneId,
    int? occurrenceOffsetSeconds,
    Duration? moveTime,
    IsPreparationChanged? isChanged,
    Duration? scheduleSpareTime,
    String? scheduleNote,
    PreparationEntity? preparation,
    SchedulePreparationMode? originalPreparationMode,
    ScheduleEntity? originalSchedule,
    PreparationEntity? originalPreparation,
    Object? recurrenceRule = _unset,
    RecurringEditScope? recurringScope,
    bool? recurrenceCountChanged,
    Object? recurrenceReview = _unset,
    DateTime? repeatedTimeDate,
    bool? isValid,
    Object? maxAvailableTime = _unset,
    Object? previousScheduleName = _unset,
  }) {
    return ScheduleFormState(
      baseline: baseline ?? this.baseline,
      mutationId: mutationId ?? this.mutationId,
      saveReceipt: saveReceipt ?? this.saveReceipt,
      saveFailure: identical(saveFailure, _unset)
          ? this.saveFailure
          : saveFailure as ScheduleSaveFailure?,
      status: status ?? this.status,
      submissionStatus: submissionStatus ?? this.submissionStatus,
      submissionError: identical(submissionError, _unset)
          ? this.submissionError
          : submissionError as String?,
      id: id ?? this.id,
      placeId: placeId ?? this.placeId,
      placeName: placeName ?? this.placeName,
      scheduleName: scheduleName ?? this.scheduleName,
      scheduleTime: scheduleTime ?? this.scheduleTime,
      timeZoneId: timeZoneId ?? this.timeZoneId,
      occurrenceOffsetSeconds:
          occurrenceOffsetSeconds ?? this.occurrenceOffsetSeconds,
      moveTime: moveTime ?? this.moveTime,
      isChanged: isChanged ?? this.isChanged,
      scheduleSpareTime: scheduleSpareTime ?? this.scheduleSpareTime,
      scheduleNote: scheduleNote ?? this.scheduleNote,
      preparation: preparation ?? this.preparation,
      originalPreparationMode:
          originalPreparationMode ?? this.originalPreparationMode,
      originalSchedule: originalSchedule ?? this.originalSchedule,
      originalPreparation: originalPreparation ?? this.originalPreparation,
      recurrenceRule: identical(recurrenceRule, _unset)
          ? this.recurrenceRule
          : recurrenceRule as RecurrenceRule?,
      recurringScope: recurringScope ?? this.recurringScope,
      recurrenceCountChanged:
          recurrenceCountChanged ?? this.recurrenceCountChanged,
      recurrenceReview: identical(recurrenceReview, _unset)
          ? this.recurrenceReview
          : recurrenceReview as RecurrenceReview?,
      repeatedTimeDate: repeatedTimeDate ?? this.repeatedTimeDate,
      isValid: isValid ?? this.isValid,
      maxAvailableTime: identical(maxAvailableTime, _unset)
          ? this.maxAvailableTime
          : maxAvailableTime as Duration?,
      previousScheduleName: identical(previousScheduleName, _unset)
          ? this.previousScheduleName
          : previousScheduleName as String?,
    );
  }

  Duration get totalPreparationTime =>
      preparation?.totalDuration ?? Duration.zero;

  ScheduleEntity createEntity(ScheduleFormState state) {
    return ScheduleEntity(
      id: state.id,
      place: PlaceEntity(
        id: state.placeId ?? Uuid().v7(),
        placeName: state.placeName!,
      ),
      scheduleName: state.scheduleName!,
      scheduleTime: state.scheduleTime!,
      timeZoneId: state.timeZoneId,
      occurrenceOffsetSeconds:
          state.occurrenceOffsetSeconds ??
          state.scheduleTime!.timeZoneOffset.inSeconds,
      moveTime: state.moveTime!,
      isChanged: !(state.isChanged == IsPreparationChanged.unchanged),
      scheduleSpareTime: state.scheduleSpareTime,
      scheduleNote: state.scheduleNote ?? '',
      isStarted: false,
      preparationMode: state.isChanged == IsPreparationChanged.changed
          ? SchedulePreparationMode.custom
          : (originalSchedule?.preparationMode ??
                SchedulePreparationMode.defaultPreparation),
      preparationTemplateId: state.isChanged == IsPreparationChanged.changed
          ? null
          : originalSchedule?.preparationTemplateId,
      preparationTemplateName: state.isChanged == IsPreparationChanged.changed
          ? null
          : originalSchedule?.preparationTemplateName,
      recurringSegmentId: originalSchedule?.recurringSegmentId,
      recurringSlotKey: originalSchedule?.recurringSlotKey,
      recurringOrdinal: originalSchedule?.recurringOrdinal,
      recurringOverrides: originalSchedule?.recurringOverrides ?? '',
      preparationDefinitionId: originalSchedule?.preparationDefinitionId,
    );
  }

  @override
  List<Object?> get props => [
    baseline,
    mutationId,
    saveReceipt,
    saveFailure,
    status,
    submissionStatus,
    submissionError,
    id,
    placeId,
    placeName,
    scheduleName,
    scheduleTime,
    timeZoneId,
    occurrenceOffsetSeconds,
    moveTime,
    isChanged,
    scheduleSpareTime,
    scheduleNote,
    preparation,
    originalPreparationMode,
    originalSchedule,
    originalPreparation,
    recurrenceRule,
    recurringScope,
    recurrenceCountChanged,
    recurrenceReview,
    repeatedTimeDate,
    isValid,
    maxAvailableTime,
    previousScheduleName,
  ];
}
