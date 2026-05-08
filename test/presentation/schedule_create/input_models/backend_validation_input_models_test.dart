import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/presentation/onboarding/preparation_time/input_models/preparation_time_input_model.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_name/input_models/schedule_name_input_model.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_place_moving_time.dart/input_models/schedule_moving_time_input_model.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/input_models/schedule_spare_time_input_model.dart';

void main() {
  test('schedule name rejects blank and values over 30 chars', () {
    expect(
      const ScheduleNameInputModel.dirty('   ').error,
      ScheduleNameValidationError.empty,
    );
    expect(
      ScheduleNameInputModel.dirty('a' * 31).error,
      ScheduleNameValidationError.tooLong,
    );
    expect(ScheduleNameInputModel.dirty('a' * 30).isValid, isTrue);
  });

  test('moving time rejects negative, zero, and over 1440 minutes', () {
    expect(
      const ScheduleMovingTimeInputModel.dirty(Duration(minutes: -1)).error,
      ScheduleMovingTimeValidationError.negative,
    );
    expect(
      const ScheduleMovingTimeInputModel.dirty(Duration.zero).error,
      ScheduleMovingTimeValidationError.zero,
    );
    expect(
      const ScheduleMovingTimeInputModel.dirty(Duration(minutes: 1441)).error,
      ScheduleMovingTimeValidationError.tooLarge,
    );
    expect(
      const ScheduleMovingTimeInputModel.dirty(Duration(minutes: 1440)).isValid,
      isTrue,
    );
  });

  test('spare time rejects negative, zero, empty, and over 1440 minutes', () {
    expect(
      const ScheduleSpareTimeInputModel.dirty().error,
      ScheduleSpareTimeValidationError.empty,
    );
    expect(
      const ScheduleSpareTimeInputModel.dirty(Duration(minutes: -1)).error,
      ScheduleSpareTimeValidationError.negative,
    );
    expect(
      const ScheduleSpareTimeInputModel.dirty(Duration.zero).error,
      ScheduleSpareTimeValidationError.zero,
    );
    expect(
      const ScheduleSpareTimeInputModel.dirty(Duration(minutes: 1441)).error,
      ScheduleSpareTimeValidationError.tooLarge,
    );
  });

  test('preparation time rejects negative, zero, and over 1440 minutes', () {
    expect(
      const PreparationTimeInputModel.dirty(Duration(minutes: -1)).error,
      PreparationTimeValidationError.negative,
    );
    expect(
      const PreparationTimeInputModel.dirty(Duration.zero).error,
      PreparationTimeValidationError.zero,
    );
    expect(
      const PreparationTimeInputModel.dirty(Duration(minutes: 1441)).error,
      PreparationTimeValidationError.tooLarge,
    );
  });
}
