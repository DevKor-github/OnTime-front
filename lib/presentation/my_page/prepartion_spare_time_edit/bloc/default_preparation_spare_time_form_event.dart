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
  List<Object?> get props => [];
}
