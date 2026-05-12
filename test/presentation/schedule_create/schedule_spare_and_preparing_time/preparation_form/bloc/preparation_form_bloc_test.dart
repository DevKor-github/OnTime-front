import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/bloc/preparation_form_bloc.dart';

void main() {
  late PreparationFormBloc bloc;

  final preparation = PreparationEntity(
    preparationStepList: [
      PreparationStepEntity(
        id: 'step-1',
        preparationName: 'Shower',
        preparationTime: const Duration(minutes: 10),
        nextPreparationId: null,
      ),
    ],
  );

  setUp(() {
    bloc = PreparationFormBloc();
  });

  tearDown(() async {
    await bloc.close();
  });

  Future<PreparationFormState> waitForState(
    bool Function(PreparationFormState state) predicate,
  ) {
    return bloc.stream.firstWhere(predicate);
  }

  test('validates and serializes the visible draft preparation step', () async {
    final editState = waitForState(
      (state) => state.preparationStepList.length == 1 && state.isValid,
    );
    bloc.add(PreparationFormEditRequested(preparationEntity: preparation));
    await editState;

    final addingState = waitForState(
      (state) =>
          state.status == PreparationFormStatus.adding &&
          state.draftStep != null &&
          !state.isValid,
    );
    bloc.add(const PreparationFormPreparationStepCreationRequested());
    await addingState;

    final validWithDraftState = waitForState(
      (state) => state.visiblePreparationStepList.length == 2 && state.isValid,
    );
    bloc
      ..add(
        const PreparationFormDraftStepNameChanged(
          preparationStepName: 'Pack bag',
        ),
      )
      ..add(
        const PreparationFormDraftStepTimeChanged(
          preparationStepTime: Duration(minutes: 5),
        ),
      );

    final state = await validWithDraftState;
    final entity = state.toPreparationEntity();

    expect(entity.preparationStepList, hasLength(2));
    expect(entity.preparationStepList.last.preparationName, 'Pack bag');
    expect(entity.preparationStepList.last.preparationTime.inMinutes, 5);
  });

  test('shows validation errors after validation is requested', () async {
    final editState = waitForState(
      (state) => state.preparationStepList.length == 1 && state.isValid,
    );
    bloc.add(PreparationFormEditRequested(preparationEntity: preparation));
    await editState;

    final validationState = waitForState(
      (state) => state.showValidationErrors && !state.isValid,
    );
    bloc
      ..add(
        const PreparationFormPreparationStepNameChanged(
          index: 0,
          preparationStepName: '',
        ),
      )
      ..add(const PreparationFormValidationRequested());

    final state = await validationState;

    expect(state.firstInvalidStep?.id, 'step-1');
    expect(
      state.invalidFieldFor(state.firstInvalidStep!),
      PreparationFormInvalidField.name,
    );
  });
}
