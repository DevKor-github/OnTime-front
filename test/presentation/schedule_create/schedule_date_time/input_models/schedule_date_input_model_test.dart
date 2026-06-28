import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_date_time/input_models/schedule_date_input_model.dart';

void main() {
  test(
    'schedule date input validates independently from the date model file',
    () {
      final validDate = DateTime(2026, 7, 1);

      expect(
        const ScheduleDateInputModel.dirty().error,
        ScheduleDateValidationError.empty,
      );
      expect(ScheduleDateInputModel.dirty(validDate).isValid, isTrue);
    },
  );
}
