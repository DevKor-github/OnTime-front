import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/input_models/preparation_name_input_model.dart';
import 'package:on_time_front/presentation/onboarding/preparation_time/input_models/preparation_time_input_model.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/bloc/preparation_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/cubit/preparation_step_form_cubit.dart';

void main() {
  test('PreparationFormEvent props capture step edits', () {
    final preparation = _preparation();
    final stepState = PreparationStepFormState(
      id: 'step-1',
      preparationName: const PreparationNameInputModel.pure('Shower'),
      preparationTime: const PreparationTimeInputModel.pure(
        Duration(minutes: 10),
      ),
    );

    expect(
      PreparationFormEditRequested(
        preparationEntity: preparation,
      ).preparationEntity,
      preparation,
    );
    expect(
      PreparationFormPreparationStepCreated(preparationStep: stepState).props,
      [stepState],
    );
    expect(
      const PreparationFormPreparationStepRemoved(
        preparationStepId: 'step-1',
      ).props,
      ['step-1'],
    );
    expect(
      const PreparationFormPreparationStepNameChanged(
        index: 1,
        preparationStepName: 'Pack',
      ).props,
      [1, 'Pack'],
    );
    expect(
      const PreparationFormPreparationStepNameFocusLost(
        index: 1,
        preparationStepName: 'Pack',
      ).props,
      [1, 'Pack'],
    );
    expect(
      const PreparationFormPreparationStepInteractionEnded(
        index: 1,
        preparationStepName: 'Pack',
      ).props,
      [1, 'Pack'],
    );
    expect(
      const PreparationFormPreparationStepTimeChanged(
        index: 1,
        preparationStepTime: Duration(minutes: 15),
      ).props,
      [1, const Duration(minutes: 15)],
    );
    expect(
      const PreparationFormDraftStepNameChanged(
        preparationStepName: 'Draft',
      ).props,
      ['Draft'],
    );
    expect(
      const PreparationFormDraftStepTimeChanged(
        preparationStepTime: Duration(minutes: 3),
      ).props,
      [const Duration(minutes: 3)],
    );
    expect(
      const PreparationFormPreparationStepOrderChanged(
        oldIndex: 0,
        newIndex: 1,
      ).props,
      [0, 1],
    );
    expect(const PreparationFormPreparationStepCreationRequested().props, []);
    expect(const PreparationFormValidationRequested().props, []);
  });

  test('PreparationFormState orders linked entity steps for editing', () {
    final state = PreparationFormState.fromEntity(_preparation());

    expect(state.status, PreparationFormStatus.success);
    expect(state.preparationStepList.map((step) => step.id), [
      'step-1',
      'step-2',
    ]);
  });

  test('PreparationFormState validates fields and converts visible steps', () {
    final validStep = PreparationStepFormState(
      id: 'step-1',
      preparationName: const PreparationNameInputModel.dirty('Shower'),
      preparationTime: const PreparationTimeInputModel.dirty(
        Duration(minutes: 10),
      ),
    );
    final invalidNameStep = PreparationStepFormState(
      id: 'step-2',
      preparationName: const PreparationNameInputModel.dirty(''),
      preparationTime: const PreparationTimeInputModel.dirty(
        Duration(minutes: 5),
      ),
    );
    final state = PreparationFormState(
      preparationStepList: [validStep, invalidNameStep],
      addingStepId: 'step-2',
      showValidationErrors: true,
    );

    expect(state.visiblePreparationStepList, [validStep, invalidNameStep]);
    expect(state.firstInvalidStep, invalidNameStep);
    expect(
      state.invalidFieldFor(invalidNameStep),
      PreparationFormInvalidField.name,
    );
    expect(state.invalidFieldFor(validStep), isNull);

    final cleared = state.copyWith(clearAddingStepId: true, isValid: true);
    expect(cleared.addingStepId, isNull);
    expect(cleared.isValid, isTrue);

    final entity = PreparationFormState(
      preparationStepList: [validStep],
    ).toPreparationEntity();
    expect(entity.preparationStepList.single.id, 'step-1');
    expect(entity.preparationStepList.single.nextPreparationId, isNull);
  });
}

PreparationEntity _preparation() {
  return const PreparationEntity(
    preparationStepList: [
      PreparationStepEntity(
        id: 'step-2',
        preparationName: 'Pack',
        preparationTime: Duration(minutes: 5),
      ),
      PreparationStepEntity(
        id: 'step-1',
        preparationName: 'Shower',
        preparationTime: Duration(minutes: 10),
        nextPreparationId: 'step-2',
      ),
    ],
  );
}
