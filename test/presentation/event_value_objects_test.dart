import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/presentation/home/bloc/schedule_timer_bloc.dart';
import 'package:on_time_front/presentation/my_page/preparation_spare_time_edit/bloc/default_preparation_spare_time_form_bloc.dart';

void main() {
  test('default preparation edit events compare user-edited fields', () {
    const preparation = PreparationEntity(preparationStepList: []);

    expect(const DefaultPreparationSpareTimeFormEvent().props, isEmpty);
    expect(const FormEditRequested(spareTime: Duration(minutes: 7)).props, [
      const Duration(minutes: 7),
    ]);
    expect(const SpareTimeIncreased().props, isEmpty);
    expect(const SpareTimeDecreased().props, isEmpty);
    expect(
      const FormSubmitted(note: 'Bring bag', preparation: preparation).props,
      ['Bring bag'],
    );
  });

  test('schedule timer events compare schedule and tick times', () {
    final scheduleTime = DateTime.utc(2026, 5, 15, 9);
    final currentTime = DateTime.utc(2026, 5, 15, 8, 30);

    expect(ScheduleTimerStarted(scheduleTime).props, [scheduleTime]);
    expect(ScheduleTimerTicked(currentTime).props, [currentTime]);
    expect(const ScheduleTimerStopped().props, isEmpty);
    expect(ScheduleTimerUpdated(scheduleTime).props, [scheduleTime]);
    expect(const ScheduleTimerUpdated(null).props, [null]);
  });
}
