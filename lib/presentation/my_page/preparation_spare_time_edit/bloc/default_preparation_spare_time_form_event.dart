part of 'default_preparation_spare_time_form_bloc.dart';

class DefaultPreparationSpareTimeFormEvent extends Equatable {
  const DefaultPreparationSpareTimeFormEvent();

  @override
  List<Object?> get props => [];
}

class FormEditRequested extends DefaultPreparationSpareTimeFormEvent {
  const FormEditRequested({required this.spareTime});
  final Duration spareTime;

  @override
  List<Object?> get props => [spareTime];
}

class SpareTimeIncreased extends DefaultPreparationSpareTimeFormEvent {
  const SpareTimeIncreased();

  @override
  List<Object?> get props => [];
}

class SpareTimeDecreased extends DefaultPreparationSpareTimeFormEvent {
  const SpareTimeDecreased();

  @override
  List<Object?> get props => [];
}

class FormSubmitted extends DefaultPreparationSpareTimeFormEvent {
  const FormSubmitted({required this.note, required this.preparation});
  final String note;
  final PreparationEntity preparation;

  @override
  List<Object?> get props => [note];
}
