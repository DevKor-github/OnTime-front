part of 'schedule_form_bloc.dart';

enum ScheduleFormStatus { initial, loading, success, error }

enum ScheduleFormSubmissionStatus { idle, submitting, success, failure }

enum IsPreparationChanged { changed, unchanged }

final class ScheduleFormState extends Equatable {
  static const _unset = Object();

  final ScheduleFormStatus status;
  final ScheduleFormSubmissionStatus submissionStatus;
  final String? submissionError;
  final String id;
  final String? placeId;
  final String? placeName;
  final String? scheduleName;
  final DateTime? scheduleTime;
  final Duration? moveTime;
  final IsPreparationChanged isChanged;
  final Duration? scheduleSpareTime;
  final String? scheduleNote;
  final PreparationEntity? preparation;
  final bool isValid;
  final Duration? maxAvailableTime;
  final String? previousScheduleName;

  ScheduleFormState({
    this.status = ScheduleFormStatus.initial,
    this.submissionStatus = ScheduleFormSubmissionStatus.idle,
    this.submissionError,
    String? id,
    this.placeId,
    this.placeName,
    this.scheduleName,
    this.scheduleTime,
    this.moveTime,
    this.isChanged = IsPreparationChanged.unchanged,
    this.scheduleSpareTime,
    this.scheduleNote,
    this.preparation,
    this.isValid = false,
    this.maxAvailableTime,
    this.previousScheduleName,
  }) : id = id ?? Uuid().v7();

  ScheduleFormState copyWith({
    ScheduleFormStatus? status,
    ScheduleFormSubmissionStatus? submissionStatus,
    Object? submissionError = _unset,
    String? id,
    String? placeId,
    String? placeName,
    String? scheduleName,
    DateTime? scheduleTime,
    Duration? moveTime,
    IsPreparationChanged? isChanged,
    Duration? scheduleSpareTime,
    String? scheduleNote,
    PreparationEntity? preparation,
    bool? isValid,
    Duration? maxAvailableTime,
    String? previousScheduleName,
  }) {
    return ScheduleFormState(
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
      moveTime: moveTime ?? this.moveTime,
      isChanged: isChanged ?? this.isChanged,
      scheduleSpareTime: scheduleSpareTime ?? this.scheduleSpareTime,
      scheduleNote: scheduleNote ?? this.scheduleNote,
      preparation: preparation ?? this.preparation,
      isValid: isValid ?? this.isValid,
      maxAvailableTime: maxAvailableTime ?? this.maxAvailableTime,
      previousScheduleName: previousScheduleName ?? this.previousScheduleName,
    );
  }

  Duration get totalPreparationTime {
    return preparation?.preparationStepList
            .map((e) => e.preparationTime)
            .reduce((value, element) => value + element) ??
        Duration.zero;
  }

  ScheduleEntity createEntity(ScheduleFormState state) {
    return ScheduleEntity(
      id: state.id,
      place: PlaceEntity(
        id: state.placeId ?? Uuid().v7(),
        placeName: state.placeName!,
      ),
      scheduleName: state.scheduleName!,
      scheduleTime: state.scheduleTime!,
      moveTime: state.moveTime!,
      isChanged: !(state.isChanged == IsPreparationChanged.unchanged),
      scheduleSpareTime: state.scheduleSpareTime,
      scheduleNote: state.scheduleNote ?? '',
      isStarted: false,
    );
  }

  @override
  List<Object?> get props => [
        status,
        submissionStatus,
        submissionError,
        id,
        placeId,
        placeName,
        scheduleName,
        scheduleTime,
        moveTime,
        isChanged,
        scheduleSpareTime,
        scheduleNote,
        preparation,
        isValid,
        maxAvailableTime,
        previousScheduleName,
      ];
}
