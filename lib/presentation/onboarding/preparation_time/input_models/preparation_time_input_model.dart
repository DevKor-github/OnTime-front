import 'package:formz/formz.dart';
import 'package:on_time_front/core/validation/backend_constraints.dart';

/// Validation errors for the [PreparationTimeInputModel] [FormzInput].
enum PreparationTimeValidationError { zero, negative, tooLarge }

class PreparationTimeInputModel
    extends FormzInput<Duration, PreparationTimeValidationError> {
  const PreparationTimeInputModel.pure([super.value = Duration.zero])
    : super.pure();
  const PreparationTimeInputModel.dirty([super.value = Duration.zero])
    : super.dirty();

  @override
  PreparationTimeValidationError? validator(Duration value) {
    final minutes = value.inMinutes;
    if (minutes < 0) {
      return PreparationTimeValidationError.negative;
    }
    if (minutes == 0) {
      return PreparationTimeValidationError.zero;
    }
    if (minutes > BackendConstraints.maxMinuteValue) {
      return PreparationTimeValidationError.tooLarge;
    }
    return null;
  }
}
