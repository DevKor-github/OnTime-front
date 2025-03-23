import 'package:formz/formz.dart';

/// Validation errors for the [PreparationNameInputModel] [FormzInput].
enum PreparationNameValidationError {
  empty,
}

class PreparationNameInputModel
    extends FormzInput<String, PreparationNameValidationError> {
  const PreparationNameInputModel.pure([super.value = '']) : super.pure();
  const PreparationNameInputModel.dirty([super.value = '']) : super.dirty();

  @override
  PreparationNameValidationError? validator(String value) {
    return value.isEmpty ? PreparationNameValidationError.empty : null;
  }
}
