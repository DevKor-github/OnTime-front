import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_date_time/input_models/schedule_time_input_model.dart';

void main() {
  test(
    'schedule time input validates independently from the time model file',
    () {
      final validTime = DateTime(2026, 7, 1, 9, 30);

      expect(
        const ScheduleTimeInputModel.dirty().error,
        ScheduleTimeValidationError.empty,
      );
      expect(ScheduleTimeInputModel.dirty(validTime).isValid, isTrue);
    },
  );
}
