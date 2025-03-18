part of 'early_late_screen_bloc.dart';

abstract class EarlyLateScreenEvent extends Equatable {
  const EarlyLateScreenEvent();

  @override
  List<Object> get props => [];
}

class LoadEarlyLateInfo extends EarlyLateScreenEvent {
  final int earlyLateTime;

  const LoadEarlyLateInfo({required this.earlyLateTime});

  @override
  List<Object> get props => [earlyLateTime];
}

class ChecklistLoaded extends EarlyLateScreenEvent {
  final List<bool> checklist;

  const ChecklistLoaded({required this.checklist});

  @override
  List<Object> get props => [checklist];
}

class ChecklistItemToggled extends EarlyLateScreenEvent {
  final int index;

  const ChecklistItemToggled(this.index);

  @override
  List<Object> get props => [index];
}
