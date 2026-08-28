import 'package:formz/formz.dart';
import 'package:on_time_front/core/validation/local_input_limits.dart';

/// Validation errors for the [ScheduleNameInputModel] [FormzInput].
enum ScheduleNameValidationError { empty, tooLong }

class ScheduleNameInputModel
    extends FormzInput<String, ScheduleNameValidationError> {
  const ScheduleNameInputModel.pure([super.value = '']) : super.pure();
  const ScheduleNameInputModel.dirty([super.value = '']) : super.dirty();

  @override
  ScheduleNameValidationError? validator(String value) {
    final trimmedValue = value.trim();
    if (trimmedValue.isEmpty) {
      return ScheduleNameValidationError.empty;
    }
    if (trimmedValue.length > LocalInputLimits.maxScheduleNameLength) {
      return ScheduleNameValidationError.tooLong;
    }
    return null;
  }
}
