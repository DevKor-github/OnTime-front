import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form_bloc.dart';

void main() {
  test('ScheduleFormEvent props capture user input payloads', () {
    final date = DateTime(2026, 5, 15);
    final time = DateTime(2026, 5, 15, 9);
    final preparation = _preparation();

    expect(const ScheduleFormEditRequested(scheduleId: 's-1').props, ['s-1']);
    expect(ScheduleFormCreateRequested(initialDate: date).props, [date]);
    expect(const ScheduleFormCreateRequested().props.single, isA<DateTime>());
    expect(
      const ScheduleFormScheduleNameChanged(scheduleName: 'Meeting').props,
      ['Meeting'],
    );
    expect(
      ScheduleFormScheduleDateTimeChanged(
        scheduleDate: date,
        scheduleTime: time,
        maxAvailableTime: const Duration(minutes: 20),
        previousScheduleName: 'Previous',
      ).props,
      [date, time, const Duration(minutes: 20), 'Previous'],
    );
    expect(const ScheduleFormPlaceNameChanged(placeName: 'Office').props, [
      'Office',
    ]);
    expect(
      const ScheduleFormMoveTimeChanged(moveTime: Duration(minutes: 10)).props,
      [const Duration(minutes: 10)],
    );
    expect(
      const ScheduleFormScheduleSpareTimeChanged(
        scheduleSpareTime: Duration(minutes: 5),
      ).props,
      [const Duration(minutes: 5)],
    );
    expect(ScheduleFormPreparationChanged(preparation: preparation).props, [
      preparation,
    ]);
    expect(const ScheduleFormValidated(isValid: true).props, [true]);
  });

  test('ScheduleFormState copyWith updates fields and can clear error', () {
    final initial = ScheduleFormState(
      id: 'schedule-1',
      submissionError: 'backend down',
    );
    final updated = initial.copyWith(
      status: ScheduleFormStatus.loading,
      submissionStatus: ScheduleFormSubmissionStatus.submitting,
      submissionError: null,
      placeId: 'place-1',
      placeName: 'Office',
      scheduleName: 'Meeting',
      scheduleTime: DateTime(2026, 5, 15, 9),
      moveTime: const Duration(minutes: 10),
      isChanged: IsPreparationChanged.changed,
      scheduleSpareTime: const Duration(minutes: 5),
      scheduleNote: 'Bring notes',
      preparation: _preparation(),
      isValid: true,
      maxAvailableTime: const Duration(minutes: 30),
      previousScheduleName: 'Previous',
    );

    expect(updated.id, 'schedule-1');
    expect(updated.status, ScheduleFormStatus.loading);
    expect(updated.submissionStatus, ScheduleFormSubmissionStatus.submitting);
    expect(updated.submissionError, isNull);
    expect(updated.placeName, 'Office');
    expect(updated.totalPreparationTime, const Duration(minutes: 15));
    expect(updated.isValid, isTrue);
  });

  test('ScheduleFormState creates schedule entity from valid form fields', () {
    final state = ScheduleFormState(
      id: 'schedule-1',
      placeId: 'place-1',
      placeName: 'Office',
      scheduleName: 'Meeting',
      scheduleTime: DateTime(2026, 5, 15, 9),
      moveTime: const Duration(minutes: 10),
      isChanged: IsPreparationChanged.changed,
      scheduleSpareTime: const Duration(minutes: 5),
      scheduleNote: 'Bring notes',
    );

    final entity = state.createEntity(state);

    expect(entity.id, 'schedule-1');
    expect(entity.place.id, 'place-1');
    expect(entity.place.placeName, 'Office');
    expect(entity.scheduleName, 'Meeting');
    expect(entity.isChanged, isTrue);
    expect(entity.isStarted, isFalse);
    expect(entity.scheduleNote, 'Bring notes');
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
