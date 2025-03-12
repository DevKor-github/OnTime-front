import 'package:formz/formz.dart';

/// Validation errors for the [ScheduleMovingTimeInputModel] [FormzInput].
enum ScheduleSpareTimeValidationError {
  zero,
}

class ScheduleSpareTimeInputModel
    extends FormzInput<Duration, ScheduleSpareTimeValidationError> {
  const ScheduleSpareTimeInputModel.pure([super.value = Duration.zero])
      : super.pure();
  const ScheduleSpareTimeInputModel.dirty([super.value = Duration.zero])
      : super.dirty();

  @override
  ScheduleSpareTimeValidationError? validator(Duration value) {
    return value.inMinutes == 0 ? ScheduleSpareTimeValidationError.zero : null;
  }
}
