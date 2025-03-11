import 'package:formz/formz.dart';

/// Validation errors for the [ScheduleMovingTimeInputModel] [FormzInput].
enum ScheduleMovingTimeValidationError {
  zero,
}

class ScheduleMovingTimeInputModel
    extends FormzInput<Duration, ScheduleMovingTimeValidationError> {
  const ScheduleMovingTimeInputModel.pure([super.value = Duration.zero])
      : super.pure();
  const ScheduleMovingTimeInputModel.dirty([super.value = Duration.zero])
      : super.dirty();

  @override
  ScheduleMovingTimeValidationError? validator(Duration value) {
    return value.inMinutes == 0 ? ScheduleMovingTimeValidationError.zero : null;
  }
}
