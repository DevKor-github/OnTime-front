import 'package:formz/formz.dart';

/// Validation errors for the [SchedulePlaceInputModel] [FormzInput].
enum SchedulePlaceValidationError {
  empty,
}

class SchedulePlaceInputModel
    extends FormzInput<String, SchedulePlaceValidationError> {
  const SchedulePlaceInputModel.pure([super.value = '']) : super.pure();
  const SchedulePlaceInputModel.dirty([super.value = '']) : super.dirty();

  @override
  SchedulePlaceValidationError? validator(String value) {
    return value.isEmpty ? SchedulePlaceValidationError.empty : null;
  }
}
