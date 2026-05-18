import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/bloc/preparation_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/cubit/preparation_step_form_cubit.dart';

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

  test('validates and serializes the newly added preparation step', () async {
    final editState = waitForState(
      (state) => state.preparationStepList.length == 1 && state.isValid,
    );
    bloc.add(PreparationFormEditRequested(preparationEntity: preparation));
    await editState;

    final addingState = waitForState(
      (state) =>
          state.status == PreparationFormStatus.adding &&
          state.addingStepId != null &&
          state.preparationStepList.length == 2 &&
          !state.isValid,
    );
    bloc.add(const PreparationFormPreparationStepCreationRequested());
    await addingState;

    final validWithAddedStepState = waitForState(
      (state) => state.visiblePreparationStepList.length == 2 && state.isValid,
    );
    bloc
      ..add(
        const PreparationFormPreparationStepNameChanged(
          index: 1,
          preparationStepName: 'Pack bag',
        ),
      )
      ..add(
        const PreparationFormPreparationStepTimeChanged(
          index: 1,
          preparationStepTime: Duration(minutes: 5),
        ),
      );

    final state = await validWithAddedStepState;
    final entity = state.toPreparationEntity();

    expect(state.status, PreparationFormStatus.initial);
    expect(state.addingStepId, isNull);
    expect(entity.preparationStepList, hasLength(2));
    expect(entity.preparationStepList.last.preparationName, 'Pack bag');
    expect(entity.preparationStepList.last.preparationTime.inMinutes, 5);
  });

  test('can remove a newly added preparation step', () async {
    final editState = waitForState(
      (state) => state.preparationStepList.length == 1 && state.isValid,
    );
    bloc.add(PreparationFormEditRequested(preparationEntity: preparation));
    await editState;

    final addingState = waitForState(
      (state) =>
          state.status == PreparationFormStatus.adding &&
          state.addingStepId != null &&
          state.preparationStepList.length == 2,
    );
    bloc.add(const PreparationFormPreparationStepCreationRequested());
    final stateWithAddedStep = await addingState;

    final removedState = waitForState(
      (state) =>
          state.status == PreparationFormStatus.initial &&
          state.addingStepId == null &&
          state.preparationStepList.length == 1,
    );
    bloc.add(
      PreparationFormPreparationStepRemoved(
        preparationStepId: stateWithAddedStep.addingStepId!,
      ),
    );

    final state = await removedState;

    expect(state.preparationStepList.single.id, 'step-1');
  });

  test('removes a blank newly added step when name focus is lost', () async {
    final editState = waitForState(
      (state) => state.preparationStepList.length == 1 && state.isValid,
    );
    bloc.add(PreparationFormEditRequested(preparationEntity: preparation));
    await editState;

    final addingState = waitForState(
      (state) =>
          state.status == PreparationFormStatus.adding &&
          state.addingStepId != null &&
          state.preparationStepList.length == 2,
    );
    bloc.add(const PreparationFormPreparationStepCreationRequested());
    await addingState;

    final removedState = waitForState(
      (state) =>
          state.status == PreparationFormStatus.initial &&
          state.addingStepId == null &&
          state.preparationStepList.length == 1,
    );
    bloc.add(
      const PreparationFormPreparationStepNameFocusLost(
        index: 1,
        preparationStepName: '',
      ),
    );

    final state = await removedState;

    expect(state.preparationStepList.single.id, 'step-1');
    expect(state.isValid, isTrue);
  });

  test('removes a blank newly added step when row interaction ends', () async {
    final editState = waitForState(
      (state) => state.preparationStepList.length == 1 && state.isValid,
    );
    bloc.add(PreparationFormEditRequested(preparationEntity: preparation));
    await editState;

    final addingState = waitForState(
      (state) =>
          state.status == PreparationFormStatus.adding &&
          state.addingStepId != null &&
          state.preparationStepList.length == 2,
    );
    bloc.add(const PreparationFormPreparationStepCreationRequested());
    await addingState;

    final removedState = waitForState(
      (state) =>
          state.status == PreparationFormStatus.initial &&
          state.addingStepId == null &&
          state.preparationStepList.length == 1,
    );
    bloc.add(
      const PreparationFormPreparationStepInteractionEnded(
        index: 1,
        preparationStepName: '',
      ),
    );

    final state = await removedState;

    expect(state.preparationStepList.single.id, 'step-1');
    expect(state.isValid, isTrue);
  });

  test('marks time dirty when named newly added step leaves row', () async {
    final editState = waitForState(
      (state) => state.preparationStepList.length == 1 && state.isValid,
    );
    bloc.add(PreparationFormEditRequested(preparationEntity: preparation));
    await editState;

    final addingState = waitForState(
      (state) =>
          state.status == PreparationFormStatus.adding &&
          state.addingStepId != null &&
          state.preparationStepList.length == 2,
    );
    bloc.add(const PreparationFormPreparationStepCreationRequested());
    await addingState;

    final nameChangedState = waitForState(
      (state) => state.preparationStepList.last.preparationName.value == 'Pack',
    );
    bloc.add(
      const PreparationFormPreparationStepNameChanged(
        index: 1,
        preparationStepName: 'Pack',
      ),
    );
    await nameChangedState;

    final rowEndedState = waitForState(
      (state) =>
          state.preparationStepList.length == 2 &&
          state.preparationStepList.last.preparationTime.isNotValid &&
          !state.preparationStepList.last.preparationTime.isPure,
    );
    bloc.add(
      const PreparationFormPreparationStepInteractionEnded(
        index: 1,
        preparationStepName: 'Pack',
      ),
    );

    final state = await rowEndedState;

    expect(state.addingStepId, isNotNull);
    expect(state.preparationStepList.last.preparationName.isValid, isTrue);
    expect(state.isValid, isFalse);
  });

  test(
    'keeps name pure when newly added step gets time before leaving',
    () async {
      final editState = waitForState(
        (state) => state.preparationStepList.length == 1 && state.isValid,
      );
      bloc.add(PreparationFormEditRequested(preparationEntity: preparation));
      await editState;

      final addingState = waitForState(
        (state) =>
            state.status == PreparationFormStatus.adding &&
            state.addingStepId != null &&
            state.preparationStepList.length == 2,
      );
      bloc.add(const PreparationFormPreparationStepCreationRequested());
      await addingState;

      final timeChangedState = waitForState(
        (state) =>
            state.preparationStepList.last.preparationTime.value.inMinutes == 5,
      );
      bloc.add(
        const PreparationFormPreparationStepTimeChanged(
          index: 1,
          preparationStepTime: Duration(minutes: 5),
        ),
      );

      final state = await timeChangedState;

      expect(state.addingStepId, isNotNull);
      expect(state.preparationStepList.last.preparationTime.isValid, isTrue);
      expect(state.preparationStepList.last.preparationName.isPure, isTrue);
      expect(state.preparationStepList.last.preparationName.isNotValid, isTrue);
    },
  );

  test('marks name dirty when timed newly added step leaves row', () async {
    final editState = waitForState(
      (state) => state.preparationStepList.length == 1 && state.isValid,
    );
    bloc.add(PreparationFormEditRequested(preparationEntity: preparation));
    await editState;

    final addingState = waitForState(
      (state) =>
          state.status == PreparationFormStatus.adding &&
          state.addingStepId != null &&
          state.preparationStepList.length == 2,
    );
    bloc.add(const PreparationFormPreparationStepCreationRequested());
    await addingState;

    final timeChangedState = waitForState(
      (state) =>
          state.preparationStepList.last.preparationTime.value.inMinutes == 5,
    );
    bloc.add(
      const PreparationFormPreparationStepTimeChanged(
        index: 1,
        preparationStepTime: Duration(minutes: 5),
      ),
    );
    await timeChangedState;

    final rowEndedState = waitForState(
      (state) =>
          state.preparationStepList.length == 2 &&
          state.preparationStepList.last.preparationName.isNotValid &&
          !state.preparationStepList.last.preparationName.isPure,
    );
    bloc.add(
      const PreparationFormPreparationStepInteractionEnded(
        index: 1,
        preparationStepName: '',
      ),
    );

    final state = await rowEndedState;

    expect(state.addingStepId, isNotNull);
    expect(state.preparationStepList.last.preparationTime.isValid, isTrue);
    expect(state.isValid, isFalse);
  });

  test(
    'ignores stale time changes after a newly added step is removed',
    () async {
      final editState = waitForState(
        (state) => state.preparationStepList.length == 1 && state.isValid,
      );
      bloc.add(PreparationFormEditRequested(preparationEntity: preparation));
      await editState;

      final addingState = waitForState(
        (state) =>
            state.status == PreparationFormStatus.adding &&
            state.addingStepId != null &&
            state.preparationStepList.length == 2,
      );
      bloc.add(const PreparationFormPreparationStepCreationRequested());
      await addingState;

      final removedState = waitForState(
        (state) =>
            state.status == PreparationFormStatus.initial &&
            state.addingStepId == null &&
            state.preparationStepList.length == 1,
      );
      bloc.add(
        const PreparationFormPreparationStepNameFocusLost(
          index: 1,
          preparationStepName: '',
        ),
      );
      final stateAfterRemoval = await removedState;

      bloc.add(
        const PreparationFormPreparationStepTimeChanged(
          index: 1,
          preparationStepTime: Duration(minutes: 5),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state, stateAfterRemoval);
    },
  );

  test('keeps a newly added step with time when name focus is lost', () async {
    final editState = waitForState(
      (state) => state.preparationStepList.length == 1 && state.isValid,
    );
    bloc.add(PreparationFormEditRequested(preparationEntity: preparation));
    await editState;

    final addingState = waitForState(
      (state) =>
          state.status == PreparationFormStatus.adding &&
          state.addingStepId != null &&
          state.preparationStepList.length == 2,
    );
    bloc.add(const PreparationFormPreparationStepCreationRequested());
    await addingState;

    final timeChangedState = waitForState(
      (state) =>
          state.preparationStepList.last.preparationTime.value.inMinutes == 5,
    );
    bloc.add(
      const PreparationFormPreparationStepTimeChanged(
        index: 1,
        preparationStepTime: Duration(minutes: 5),
      ),
    );
    await timeChangedState;

    final focusLostState = waitForState(
      (state) =>
          state.preparationStepList.length == 2 &&
          state.preparationStepList.last.preparationName.isNotValid,
    );
    bloc.add(
      const PreparationFormPreparationStepNameFocusLost(
        index: 1,
        preparationStepName: '',
      ),
    );

    final state = await focusLostState;

    expect(state.addingStepId, isNotNull);
    expect(state.isValid, isFalse);
  });

  test('can reorder a newly added preparation step', () async {
    final editState = waitForState(
      (state) => state.preparationStepList.length == 1 && state.isValid,
    );
    bloc.add(PreparationFormEditRequested(preparationEntity: preparation));
    await editState;

    final addingState = waitForState(
      (state) =>
          state.status == PreparationFormStatus.adding &&
          state.addingStepId != null &&
          state.preparationStepList.length == 2,
    );
    bloc.add(const PreparationFormPreparationStepCreationRequested());
    final stateWithAddedStep = await addingState;

    final reorderedState = waitForState(
      (state) =>
          state.preparationStepList.first.id == stateWithAddedStep.addingStepId,
    );
    bloc.add(
      const PreparationFormPreparationStepOrderChanged(
        oldIndex: 1,
        newIndex: 0,
      ),
    );

    final state = await reorderedState;

    expect(state.preparationStepList.last.id, 'step-1');
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

  test('does not remove the last remaining preparation step', () async {
    final editState = waitForState(
      (state) => state.preparationStepList.length == 1 && state.isValid,
    );
    bloc.add(PreparationFormEditRequested(preparationEntity: preparation));
    final originalState = await editState;

    bloc.add(
      const PreparationFormPreparationStepRemoved(preparationStepId: 'step-1'),
    );
    await pumpEventQueue();

    expect(bloc.state, originalState);
  });

  test('ignores duplicate add requests while a draft row is active', () async {
    final editState = waitForState(
      (state) => state.preparationStepList.length == 1 && state.isValid,
    );
    bloc.add(PreparationFormEditRequested(preparationEntity: preparation));
    await editState;

    final addingState = waitForState(
      (state) =>
          state.status == PreparationFormStatus.adding &&
          state.preparationStepList.length == 2,
    );
    bloc.add(const PreparationFormPreparationStepCreationRequested());
    final stateAfterFirstAdd = await addingState;

    bloc.add(const PreparationFormPreparationStepCreationRequested());
    await pumpEventQueue();

    expect(
      bloc.state.preparationStepList,
      stateAfterFirstAdd.preparationStepList,
    );
    expect(bloc.state.addingStepId, stateAfterFirstAdd.addingStepId);
  });

  test(
    'created event exits adding mode without appending invalid step',
    () async {
      final editState = waitForState(
        (state) => state.preparationStepList.length == 1 && state.isValid,
      );
      bloc.add(PreparationFormEditRequested(preparationEntity: preparation));
      await editState;

      final addingState = waitForState(
        (state) =>
            state.status == PreparationFormStatus.adding &&
            state.preparationStepList.length == 2,
      );
      bloc.add(const PreparationFormPreparationStepCreationRequested());
      await addingState;

      final createdState = waitForState(
        (state) =>
            state.status == PreparationFormStatus.initial &&
            state.addingStepId == null,
      );
      bloc.add(
        PreparationFormPreparationStepCreated(
          preparationStep: PreparationStepFormState(),
        ),
      );

      final state = await createdState;

      expect(state.preparationStepList, hasLength(2));
      expect(state.preparationStepList.first.id, 'step-1');
      expect(state.preparationStepList.last.preparationName.isValid, isFalse);
      expect(state.isValid, isFalse);
    },
  );

  test(
    'draft name and time changes are ignored without active draft',
    () async {
      final editState = waitForState(
        (state) => state.preparationStepList.length == 1 && state.isValid,
      );
      bloc.add(PreparationFormEditRequested(preparationEntity: preparation));
      final originalState = await editState;

      bloc
        ..add(
          const PreparationFormDraftStepNameChanged(
            preparationStepName: 'Pack',
          ),
        )
        ..add(
          const PreparationFormDraftStepTimeChanged(
            preparationStepTime: Duration(minutes: 5),
          ),
        );
      await pumpEventQueue();

      expect(bloc.state, originalState);
    },
  );

  test('invalid reorder indices leave preparation order unchanged', () async {
    final twoStepPreparation = PreparationEntity(
      preparationStepList: [
        ...preparation.preparationStepList,
        const PreparationStepEntity(
          id: 'step-2',
          preparationName: 'Pack',
          preparationTime: Duration(minutes: 5),
          nextPreparationId: null,
        ),
      ],
    );
    bloc.add(
      PreparationFormEditRequested(preparationEntity: twoStepPreparation),
    );
    await pumpEventQueue();
    final originalState = bloc.state;

    bloc
      ..add(
        const PreparationFormPreparationStepOrderChanged(
          oldIndex: -1,
          newIndex: 0,
        ),
      )
      ..add(
        const PreparationFormPreparationStepOrderChanged(
          oldIndex: 0,
          newIndex: 3,
        ),
      );
    await pumpEventQueue();

    expect(
      bloc.state.preparationStepList.map((step) => step.id),
      originalState.preparationStepList.map((step) => step.id),
    );
  });
}
