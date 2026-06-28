import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_place_moving_time/cubit/schedule_place_moving_time_cubit.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/cubit/schedule_form_spare_time_cubit.dart';

void main() {
  test(
    'place and moving time cubit validates fields and submits to form bloc',
    () {
      final formBloc = _FakeScheduleFormBloc(
        ScheduleFormState(
          placeName: 'Office',
          moveTime: const Duration(minutes: 10),
          scheduleTime: DateTime(2026, 5, 15, 9),
          maxAvailableTime: const Duration(minutes: 20),
          previousScheduleName: 'Previous',
        ),
      );
      final cubit = SchedulePlaceMovingTimeCubit(scheduleFormBloc: formBloc);
      addTearDown(cubit.close);

      cubit.initialize();
      cubit.placeNameChanged('Cafe');
      cubit.moveTimeChanged(const Duration(minutes: 25));

      expect(cubit.state.placeName.value, 'Cafe');
      expect(cubit.state.moveTime.value, const Duration(minutes: 25));
      expect(cubit.state.isOverlapping, isFalse);
      expect(cubit.state.hasOverlapMessage, isTrue);

      cubit.moveTimeChanged(const Duration(minutes: 5));
      expect(cubit.state.isOverlapping, isFalse);
      expect(cubit.state.hasOverlapMessage, isTrue);

      cubit.schedulePlaceMovingTimeSubmitted();
      expect(
        formBloc.addedEvents
            .whereType<ScheduleFormMoveTimeChanged>()
            .last
            .moveTime,
        const Duration(minutes: 5),
      );
      expect(
        formBloc.addedEvents
            .whereType<ScheduleFormPlaceNameChanged>()
            .last
            .placeName,
        'Cafe',
      );
    },
  );

  test('spare time cubit detects overlap and submits spare time', () {
    final preparation = _preparation(minutes: 20);
    final formBloc = _FakeScheduleFormBloc(
      ScheduleFormState(
        scheduleTime: DateTime(2026, 5, 15, 9),
        moveTime: const Duration(minutes: 10),
        scheduleSpareTime: const Duration(minutes: 5),
        preparation: preparation,
        maxAvailableTime: const Duration(minutes: 45),
        previousScheduleName: 'Previous',
      ),
    );
    final cubit = ScheduleFormSpareTimeCubit(scheduleFormBloc: formBloc);
    addTearDown(cubit.close);

    cubit.initialize();
    expect(cubit.state.totalPreparationTime, const Duration(minutes: 20));
    expect(cubit.state.overlapDuration, const Duration(minutes: 10));
    expect(cubit.state.isOverlapping, isFalse);

    cubit.spareTimeChanged(const Duration(minutes: 30));
    expect(cubit.state.isOverlapping, isTrue);
    expect(cubit.state.isValid, isFalse);

    cubit.spareTimeChanged(const Duration(minutes: 5));
    cubit.scheduleSpareTimeSubmitted();
    expect(
      formBloc.addedEvents
          .whereType<ScheduleFormScheduleSpareTimeChanged>()
          .last
          .scheduleSpareTime,
      const Duration(minutes: 5),
    );
  });

  test('preparation changes update total time and notify the form bloc', () {
    final formBloc = _FakeScheduleFormBloc(
      ScheduleFormState(
        scheduleTime: DateTime(2026, 5, 15, 9),
        moveTime: const Duration(minutes: 10),
        scheduleSpareTime: const Duration(minutes: 5),
        maxAvailableTime: const Duration(minutes: 60),
      ),
    );
    final cubit = ScheduleFormSpareTimeCubit(scheduleFormBloc: formBloc);
    addTearDown(cubit.close);
    final preparation = _preparation(minutes: 25);

    cubit.preparationChanged(preparation);

    expect(cubit.state.preparation, preparation);
    expect(cubit.state.totalPreparationTime, const Duration(minutes: 25));
    expect(
      formBloc.addedEvents
          .whereType<ScheduleFormPreparationChanged>()
          .single
          .preparation,
      preparation,
    );
    expect(formBloc.addedEvents.whereType<ScheduleFormValidated>(), isNotEmpty);
  });
}

PreparationEntity _preparation({required int minutes}) {
  return PreparationEntity(
    preparationStepList: [
      PreparationStepEntity(
        id: 'step-$minutes',
        preparationName: 'Prepare',
        preparationTime: Duration(minutes: minutes),
      ),
    ],
  );
}

class _FakeScheduleFormBloc implements ScheduleFormBloc {
  _FakeScheduleFormBloc(this._state);

  final ScheduleFormState _state;
  final addedEvents = <ScheduleFormEvent>[];

  @override
  ScheduleFormState get state => _state;

  @override
  void add(ScheduleFormEvent event) {
    addedEvents.add(event);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
