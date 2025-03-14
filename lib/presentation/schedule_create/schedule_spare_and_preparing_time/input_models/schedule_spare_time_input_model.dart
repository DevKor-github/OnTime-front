import 'package:formz/formz.dart';

/// Validation errors for the [ScheduleMovingTimeInputModel] [FormzInput].
enum ScheduleSpareTimeValidationError {
  zero,
  empty,
}

class ScheduleSpareTimeInputModel
    extends FormzInput<Duration?, ScheduleSpareTimeValidationError> {
  const ScheduleSpareTimeInputModel.pure([super.value]) : super.pure();
  const ScheduleSpareTimeInputModel.dirty([super.value]) : super.dirty();

  @override
  ScheduleSpareTimeValidationError? validator(Duration? value) {
    if (value == null) {
      return ScheduleSpareTimeValidationError.empty;
    } else if (value.inMinutes == 0) {
      return ScheduleSpareTimeValidationError.zero;
    }
    return null;
  }
}
