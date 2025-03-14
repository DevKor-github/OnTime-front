import 'package:formz/formz.dart';

/// Validation errors for the [PreparationTimeInputModel] [FormzInput].
enum PreparationTimeValidationError {
  zero,
}

class PreparationTimeInputModel
    extends FormzInput<Duration, PreparationTimeValidationError> {
  const PreparationTimeInputModel.pure([super.value = Duration.zero])
      : super.pure();
  const PreparationTimeInputModel.dirty([super.value = Duration.zero])
      : super.dirty();

  @override
  PreparationTimeValidationError? validator(Duration value) {
    return value.inMinutes == 0 ? PreparationTimeValidationError.zero : null;
  }
}
