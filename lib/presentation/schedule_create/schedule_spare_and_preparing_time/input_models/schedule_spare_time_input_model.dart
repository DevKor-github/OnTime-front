import 'package:formz/formz.dart';
import 'package:on_time_front/core/validation/local_input_limits.dart';

/// Validation errors for the [ScheduleMovingTimeInputModel] [FormzInput].
enum ScheduleSpareTimeValidationError { zero, empty, negative, tooLarge }

class ScheduleSpareTimeInputModel
    extends FormzInput<Duration?, ScheduleSpareTimeValidationError> {
  const ScheduleSpareTimeInputModel.pure([super.value]) : super.pure();
  const ScheduleSpareTimeInputModel.dirty([super.value]) : super.dirty();

  @override
  ScheduleSpareTimeValidationError? validator(Duration? value) {
    if (value == null) {
      return ScheduleSpareTimeValidationError.empty;
    }
    final minutes = value.inMinutes;
    if (minutes < 0) {
      return ScheduleSpareTimeValidationError.negative;
    } else if (minutes == 0) {
      return ScheduleSpareTimeValidationError.zero;
    } else if (minutes > LocalInputLimits.maxMinuteValue) {
      return ScheduleSpareTimeValidationError.tooLarge;
    }
    return null;
  }
}
