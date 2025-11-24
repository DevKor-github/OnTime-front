part of 'schedule_form_bloc.dart';

sealed class ScheduleFormEvent extends Equatable {
  const ScheduleFormEvent();

  @override
  List<Object> get props => [];
}

final class ScheduleFormEditRequested extends ScheduleFormEvent {
  final String scheduleId;

  const ScheduleFormEditRequested({required this.scheduleId});

  @override
  List<Object> get props => [scheduleId];
}

final class ScheduleFormCreateRequested extends ScheduleFormEvent {
  const ScheduleFormCreateRequested();
}

final class ScheduleFormScheduleNameChanged extends ScheduleFormEvent {
  final String scheduleName;

  const ScheduleFormScheduleNameChanged({required this.scheduleName});

  @override
  List<Object> get props => [scheduleName];
}

final class ScheduleFormScheduleDateTimeChanged extends ScheduleFormEvent {
  final DateTime scheduleDate;
  final DateTime scheduleTime;
  final Duration? timeLeftUntilNextSchedulePreparation;
  final String? nextScheduleName;

  const ScheduleFormScheduleDateTimeChanged({
    required this.scheduleDate,
    required this.scheduleTime,
    this.timeLeftUntilNextSchedulePreparation,
    this.nextScheduleName,
  });

  @override
  List<Object> get props => [
        scheduleDate,
        scheduleTime,
        timeLeftUntilNextSchedulePreparation ?? const Duration(days: -999999),
        nextScheduleName ?? '',
      ];
}

final class ScheduleFormPlaceNameChanged extends ScheduleFormEvent {
  final String placeName;

  const ScheduleFormPlaceNameChanged({required this.placeName});

  @override
  List<Object> get props => [placeName];
}

final class ScheduleFormMoveTimeChanged extends ScheduleFormEvent {
  final Duration moveTime;

  const ScheduleFormMoveTimeChanged({required this.moveTime});

  @override
  List<Object> get props => [moveTime];
}

final class ScheduleFormScheduleSpareTimeChanged extends ScheduleFormEvent {
  final Duration scheduleSpareTime;

  const ScheduleFormScheduleSpareTimeChanged({required this.scheduleSpareTime});

  @override
  List<Object> get props => [scheduleSpareTime];
}

final class ScheduleFormPreparationChanged extends ScheduleFormEvent {
  final PreparationEntity preparation;

  const ScheduleFormPreparationChanged({required this.preparation});

  @override
  List<Object> get props => [preparation];
}

final class ScheduleFormUpdated extends ScheduleFormEvent {
  const ScheduleFormUpdated();
}

final class ScheduleFormCreated extends ScheduleFormEvent {
  const ScheduleFormCreated();
}

final class ScheduleFormValidated extends ScheduleFormEvent {
  final bool isValid;

  const ScheduleFormValidated({required this.isValid});

  @override
  List<Object> get props => [isValid];
}
