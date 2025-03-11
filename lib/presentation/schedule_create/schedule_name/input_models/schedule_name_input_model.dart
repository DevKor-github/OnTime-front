import 'package:formz/formz.dart';

/// Validation errors for the [PreparationNameInputModel] [FormzInput].
enum ScheduleNameValidationError {
  empty,
}

class ScheduleNameInputModel
    extends FormzInput<String, ScheduleNameValidationError> {
  const ScheduleNameInputModel.pure([super.value = '']) : super.pure();
  const ScheduleNameInputModel.dirty([super.value = '']) : super.dirty();

  @override
  ScheduleNameValidationError? validator(String value) {
    return value.isEmpty ? ScheduleNameValidationError.empty : null;
  }
}
