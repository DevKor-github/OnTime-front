import 'package:formz/formz.dart';

/// Validation errors for the [ScheduleTimeInputModel] [FormzInput].
enum ScheduleTimeValidationError {
  empty,
}

class ScheduleTimeInputModel
    extends FormzInput<DateTime?, ScheduleTimeValidationError> {
  const ScheduleTimeInputModel.pure([super.value]) : super.pure();
  const ScheduleTimeInputModel.dirty([super.value]) : super.dirty();

  @override
  ScheduleTimeValidationError? validator(DateTime? value) {
    return value == null ? ScheduleTimeValidationError.empty : null;
  }
}
