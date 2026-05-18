import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/cubit/schedule_form_spare_time_cubit.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/input_models/schedule_spare_time_input_model.dart';

void main() {
  test('validity follows spare-time input and overlap error state', () {
    const valid = ScheduleFormSpareTimeState(
      spareTime: ScheduleSpareTimeInputModel.dirty(Duration(minutes: 10)),
    );
    const overlapping = ScheduleFormSpareTimeState(
      spareTime: ScheduleSpareTimeInputModel.dirty(Duration(minutes: 10)),
      overlapDuration: Duration(minutes: 2),
      isOverlapping: true,
    );

    expect(valid.isValid, isTrue);
    expect(valid.hasOverlapMessage, isFalse);
    expect(valid.isOverlapError, isFalse);
    expect(overlapping.isValid, isFalse);
    expect(overlapping.hasOverlapMessage, isTrue);
    expect(overlapping.isOverlapError, isTrue);
  });

  test('copyWith can update or clear overlap state', () {
    const state = ScheduleFormSpareTimeState(
      spareTime: ScheduleSpareTimeInputModel.dirty(Duration(minutes: 5)),
      overlapDuration: Duration(minutes: 3),
      isOverlapping: true,
    );

    final updated = state.copyWith(
      totalPreparationTime: const Duration(minutes: 20),
      overlapDuration: const Duration(minutes: 1),
      isOverlapping: false,
    );
    final cleared = updated.copyWith(clearOverlap: true);

    expect(updated.totalPreparationTime, const Duration(minutes: 20));
    expect(updated.overlapDuration, const Duration(minutes: 1));
    expect(updated.isOverlapping, isFalse);
    expect(cleared.overlapDuration, isNull);
    expect(cleared.isOverlapping, isFalse);
  });

  test('fromScheduleFormState carries spare time and preparation duration', () {
    final preparation = _preparation();
    final formState = ScheduleFormState(
      scheduleSpareTime: const Duration(minutes: 8),
      preparation: preparation,
    );

    final state = ScheduleFormSpareTimeState.fromScheduleFormState(formState);

    expect(state.spareTime.value, const Duration(minutes: 8));
    expect(state.preparation, preparation);
    expect(state.totalPreparationTime, const Duration(minutes: 15));
    expect(state.props, [
      const ScheduleSpareTimeInputModel.pure(Duration(minutes: 8)),
      preparation,
      const Duration(minutes: 15),
      const Duration(),
      false,
    ]);
  });
}

PreparationEntity _preparation() {
  return const PreparationEntity(
    preparationStepList: [
      PreparationStepEntity(
        id: 'step-1',
        preparationName: 'Shower',
        preparationTime: Duration(minutes: 10),
        nextPreparationId: 'step-2',
      ),
      PreparationStepEntity(
        id: 'step-2',
        preparationName: 'Pack',
        preparationTime: Duration(minutes: 5),
      ),
    ],
  );
}
