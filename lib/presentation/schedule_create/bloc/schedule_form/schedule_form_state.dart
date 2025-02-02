part of 'schedule_form_bloc.dart';

enum ScheduleFormStatus { initial, loading, success, error }

enum IsPreparationChanged { changed, unchanged, orderChanged }

final class ScheduleFormState extends Equatable {
  final ScheduleFormStatus status;
  final String id;
  final String? placeName;
  final String? scheduleName;
  final DateTime? scheduleTime;
  final Duration? moveTime;
  final IsPreparationChanged isChanged;
  final Duration? scheduleSpareTime;
  final String? scheduleNote;
  final Duration? spareTime;
  final PreparationEntity? preparation;

  ScheduleFormState({
    this.status = ScheduleFormStatus.initial,
    String? id,
    this.placeName,
    this.scheduleName,
    this.scheduleTime,
    this.moveTime,
    this.isChanged = IsPreparationChanged.unchanged,
    this.scheduleSpareTime,
    this.scheduleNote,
    this.spareTime,
    this.preparation,
  }) : id = id ?? Uuid().v7();

  ScheduleFormState copyWith({
    ScheduleFormStatus? status,
    String? id,
    String? placeName,
    String? scheduleName,
    DateTime? scheduleTime,
    Duration? moveTime,
    IsPreparationChanged? isChanged,
    Duration? scheduleSpareTime,
    String? scheduleNote,
    Duration? spareTime,
    PreparationEntity? preparation,
  }) {
    return ScheduleFormState(
      status: status ?? this.status,
      id: id ?? this.id,
      placeName: placeName ?? this.placeName,
      scheduleName: scheduleName ?? this.scheduleName,
      scheduleTime: scheduleTime ?? this.scheduleTime,
      moveTime: moveTime ?? this.moveTime,
      isChanged: isChanged ?? this.isChanged,
      scheduleSpareTime: scheduleSpareTime ?? this.scheduleSpareTime,
      scheduleNote: scheduleNote ?? this.scheduleNote,
      spareTime: spareTime ?? this.spareTime,
      preparation: preparation ?? this.preparation,
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
      place: PlaceEntity(id: Uuid().v7(), placeName: state.placeName!),
      scheduleName: state.scheduleName!,
      scheduleTime: state.scheduleTime!,
      moveTime: state.moveTime!,
      isChanged: !(state.isChanged == IsPreparationChanged.unchanged),
      scheduleSpareTime: state.scheduleSpareTime!,
      scheduleNote: state.scheduleNote ?? '',
      isStarted: false,
    );
  }

  @override
  List<Object?> get props => [
        id,
        placeName,
        scheduleName,
        scheduleTime,
        moveTime,
        isChanged,
        scheduleSpareTime,
        scheduleNote,
        spareTime,
        preparation,
      ];
}
