import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/bloc/preparation_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/cubit/preparation_step_form_cubit.dart';

void main() {
  test('name and time edits update validity for a preparation step draft', () {
    final preparationFormBloc = _FakePreparationFormBloc();
    final cubit = PreparationStepFormCubit(
      PreparationStepFormState(id: 'step-1'),
      preparationFormBloc: preparationFormBloc,
    );
    addTearDown(cubit.close);

    cubit.nameChanged('Shower');
    expect(cubit.state.preparationName.value, 'Shower');
    expect(cubit.state.isValid, isTrue);

    cubit.timeChanged(const Duration(minutes: 10));
    expect(cubit.state.preparationTime.value, const Duration(minutes: 10));
    expect(cubit.state.isValid, isTrue);
  });

  test(
    'saving a step sends the current draft to the preparation form bloc',
    () {
      final preparationFormBloc = _FakePreparationFormBloc();
      final cubit = PreparationStepFormCubit(
        PreparationStepFormState(id: 'step-1'),
        preparationFormBloc: preparationFormBloc,
      );
      addTearDown(cubit.close);

      cubit.nameChanged('Pack');
      cubit.timeChanged(const Duration(minutes: 5));
      cubit.preparationStepSaved();

      final event = preparationFormBloc.addedEvents
          .whereType<PreparationFormPreparationStepCreated>()
          .single;
      expect(event.preparationStep.id, 'step-1');
      expect(event.preparationStep.preparationName.value, 'Pack');
      expect(
        event.preparationStep.preparationTime.value,
        const Duration(minutes: 5),
      );
    },
  );
}

class _FakePreparationFormBloc implements PreparationFormBloc {
  final addedEvents = <PreparationFormEvent>[];

  @override
  void add(PreparationFormEvent event) {
    addedEvents.add(event);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
