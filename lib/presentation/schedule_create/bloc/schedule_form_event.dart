part of 'schedule_form_bloc.dart';

sealed class ScheduleFormEvent extends Equatable {
  const ScheduleFormEvent();

  @override
  List<Object> get props => [];
}

final class ScheduleFormEditRequested extends ScheduleFormEvent {
  final String scheduleId;

  final RecurringEditScope scope;
  const ScheduleFormEditRequested({
    required this.scheduleId,
    this.scope = RecurringEditScope.occurrence,
  });

  @override
  List<Object> get props => [scheduleId, scope];
}

final class ScheduleFormCreateRequested extends ScheduleFormEvent {
  final DateTime? initialDate;
  final Duration? currentUserSpareTime;

  const ScheduleFormCreateRequested({
    this.initialDate,
    this.currentUserSpareTime,
  });

  @override
  List<Object> get props => [
    initialDate ?? DateTime.fromMillisecondsSinceEpoch(0),
    currentUserSpareTime ?? Duration.zero,
  ];
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
  final int occurrenceOffsetSeconds;
  final Duration? maxAvailableTime;
  final String? previousScheduleName;

  const ScheduleFormScheduleDateTimeChanged({
    required this.scheduleDate,
    required this.scheduleTime,
    required this.occurrenceOffsetSeconds,
    this.maxAvailableTime,
    this.previousScheduleName,
  });

  @override
  List<Object> get props => [
    scheduleDate,
    scheduleTime,
    occurrenceOffsetSeconds,
    maxAvailableTime ?? const Duration(days: -999999),
    previousScheduleName ?? '',
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
  final bool confirmed;
  final Set<String> excludedSlots;
  const ScheduleFormUpdated({
    this.confirmed = false,
    this.excludedSlots = const {},
  });
  @override
  List<Object> get props => [confirmed, excludedSlots];
}

final class ScheduleFormCreated extends ScheduleFormEvent {
  final bool confirmed;
  final Set<String> excludedSlots;
  const ScheduleFormCreated({
    this.confirmed = false,
    this.excludedSlots = const {},
  });
  @override
  List<Object> get props => [confirmed, excludedSlots];
}

final class ScheduleFormValidated extends ScheduleFormEvent {
  final bool isValid;

  const ScheduleFormValidated({required this.isValid});

  @override
  List<Object> get props => [isValid];
}

final class ScheduleFormRecurringChanged extends ScheduleFormEvent {
  const ScheduleFormRecurringChanged(this.rule, {this.countChanged = false});
  final RecurrenceRule? rule;
  final bool countChanged;
  @override
  List<Object> get props => [rule ?? '', countChanged];
}

final class ScheduleFormReviewDismissed extends ScheduleFormEvent {
  const ScheduleFormReviewDismissed();
}

final class ScheduleFormRepeatedTimeChosen extends ScheduleFormEvent {
  const ScheduleFormRepeatedTimeChosen(this.choice);
  final RepeatedCivilTime choice;
  @override
  List<Object> get props => [choice];
}

final class ScheduleFormBaselineAccepted extends ScheduleFormEvent {
  const ScheduleFormBaselineAccepted(this.owner, this.baseline, this.current);
  final Object owner;
  final ScheduleEditBaseline baseline;
  final ScheduleEntity? current;
  @override
  List<Object> get props => [owner, baseline, ?current];
}
