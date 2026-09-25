part of 'default_preparation_spare_time_form_bloc.dart';

sealed class DefaultPreparationSpareTimeFormEvent extends Equatable {
  const DefaultPreparationSpareTimeFormEvent();
  @override
  List<Object?> get props => [];
}

/// Requested initially or after explicitly discarding the old draft.
class FormEditRequested extends DefaultPreparationSpareTimeFormEvent {
  const FormEditRequested();
}

class SpareTimeIncreased extends DefaultPreparationSpareTimeFormEvent {
  const SpareTimeIncreased();
}

class SpareTimeDecreased extends DefaultPreparationSpareTimeFormEvent {
  const SpareTimeDecreased();
}

class FormSubmitted extends DefaultPreparationSpareTimeFormEvent {
  const FormSubmitted({required this.preparation});
  final PreparationEntity preparation;
  @override
  List<Object?> get props => [preparation];
}

class FormFollowUpRetried extends DefaultPreparationSpareTimeFormEvent {
  const FormFollowUpRetried();
}
