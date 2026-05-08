import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_date_time/cubit/schedule_date_time_cubit.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_date_time/input_models/schedule_date_input_model.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_date_time/input_models/schedule_time_input_model.dart';

void main() {
  test('rejects selected schedule time in the past', () {
    final past = DateTime.now().subtract(const Duration(minutes: 5));
    final state = ScheduleDateTimeState(
      scheduleDate: ScheduleDateInputModel.dirty(past),
      scheduleTime: ScheduleTimeInputModel.dirty(past),
    );

    expect(state.isPastScheduleTime, isTrue);
    expect(state.isValid, isFalse);
  });

  test('accepts selected schedule time in the future', () {
    final future = DateTime.now().add(const Duration(days: 1));
    final state = ScheduleDateTimeState(
      scheduleDate: ScheduleDateInputModel.dirty(future),
      scheduleTime: ScheduleTimeInputModel.dirty(future),
    );

    expect(state.isPastScheduleTime, isFalse);
    expect(state.isValid, isTrue);
  });
}
