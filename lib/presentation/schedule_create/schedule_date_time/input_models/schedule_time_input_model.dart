import 'package:formz/formz.dart';

/// Validation errors for the [ScheduleDateInputModel] [FormzInput].
enum ScheduleDateValidationError {
  empty,
}

class ScheduleDateInputModel
    extends FormzInput<DateTime?, ScheduleDateValidationError> {
  const ScheduleDateInputModel.pure([super.value]) : super.pure();
  const ScheduleDateInputModel.dirty([super.value]) : super.dirty();

  @override
  ScheduleDateValidationError? validator(DateTime? value) {
    return value == null ? ScheduleDateValidationError.empty : null;
  }
}
