part of 'schedule_name_cubit.dart';

class ScheduleNameState extends Equatable {
  const ScheduleNameState({
    this.scheduleName = const ScheduleNameInputModel.pure(),
  });

  final ScheduleNameInputModel scheduleName;

  bool get isValid => Formz.validate([scheduleName]);

  ScheduleNameState copyWith({
    ScheduleNameInputModel? scheduleName,
  }) {
    return ScheduleNameState(
      scheduleName: scheduleName ?? this.scheduleName,
    );
  }

  static ScheduleNameState fromScheduleFormState(ScheduleFormState state) {
    return ScheduleNameState(
      scheduleName: ScheduleNameInputModel.pure(state.scheduleName ?? ''),
    );
  }

  ScheduleFormState toScheduleFormState(ScheduleFormState oldState) {
    return oldState.copyWith(
      scheduleName: scheduleName.value,
    );
  }

  @override
  List<Object> get props => [scheduleName];
}
