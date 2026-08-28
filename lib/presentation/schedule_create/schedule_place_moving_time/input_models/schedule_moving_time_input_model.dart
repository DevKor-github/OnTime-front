import 'package:formz/formz.dart';
import 'package:on_time_front/core/validation/local_input_limits.dart';

/// Validation errors for the [ScheduleMovingTimeInputModel] [FormzInput].
enum ScheduleMovingTimeValidationError { zero, negative, tooLarge }

class ScheduleMovingTimeInputModel
    extends FormzInput<Duration, ScheduleMovingTimeValidationError> {
  const ScheduleMovingTimeInputModel.pure([super.value = Duration.zero])
    : super.pure();
  const ScheduleMovingTimeInputModel.dirty([super.value = Duration.zero])
    : super.dirty();

  @override
  ScheduleMovingTimeValidationError? validator(Duration value) {
    final minutes = value.inMinutes;
    if (minutes < 0) {
      return ScheduleMovingTimeValidationError.negative;
    }
    if (minutes == 0) {
      return ScheduleMovingTimeValidationError.zero;
    }
    if (minutes > LocalInputLimits.maxMinuteValue) {
      return ScheduleMovingTimeValidationError.tooLarge;
    }
    return null;
  }
}
