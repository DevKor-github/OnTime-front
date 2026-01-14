import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/input_models/preparation_name_input_model.dart';
import 'package:on_time_front/presentation/onboarding/preparation_time/input_models/preparation_time_input_model.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/bloc/preparation_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/cubit/preparation_step_form_cubit.dart';
import 'package:on_time_front/domain/errors/domain_failures.dart';

void main() {
  group('PreparationFormState Tests', () {
    PreparationStepFormState createStepForm({
      required String id,
      required String name,
      required Duration time,
    }) {
      return PreparationStepFormState(
        id: id,
        preparationName: PreparationNameInputModel.dirty(name),
        preparationTime: PreparationTimeInputModel.dirty(time),
      );
    }

    PreparationStepEntity stepEntity({
      required String id,
      required String name,
      required Duration time,
      required String? nextId,
    }) {
      return PreparationStepEntity(
        id: id,
        preparationName: name,
        preparationTime: time,
        nextPreparationId: nextId,
      );
    }

    group('fromEntity (nextPreparationId ordering)', () {
      test('1-1. Single tail-only step -> list contains it, status=success',
          () {
        final entity = PreparationEntity(preparationStepList: [
          stepEntity(
            id: 'A',
            name: 'A',
            time: const Duration(minutes: 1),
            nextId: null,
          ),
        ]);

        final result = PreparationFormState.fromEntity(entity);
        expect(result.isSuccess, true);
        final state = result.successOrNull!;

        expect(state.status, PreparationFormStatus.success);
        expect(state.preparationStepList.map((e) => e.id).toList(), ['A']);
        expect(state.preparationStepList[0].preparationName.value, 'A');
        expect(state.preparationStepList[0].preparationTime.value,
            const Duration(minutes: 1));
        expect(state.preparationStepList[0].preparationName.isPure, true);
        expect(state.preparationStepList[0].preparationTime.isPure, true);
      });

      test('1-2. Valid chain A->B->C reconstructs to [A,B,C] (scrambled input)',
          () {
        final a = stepEntity(
          id: 'A',
          name: 'A',
          time: const Duration(minutes: 1),
          nextId: 'B',
        );
        final b = stepEntity(
          id: 'B',
          name: 'B',
          time: const Duration(minutes: 2),
          nextId: 'C',
        );
        final c = stepEntity(
          id: 'C',
          name: 'C',
          time: const Duration(minutes: 3),
          nextId: null,
        );

        final entity = PreparationEntity(preparationStepList: [b, c, a]);
        final result = PreparationFormState.fromEntity(entity);
        expect(result.isSuccess, true);
        final state = result.successOrNull!;

        expect(state.status, PreparationFormStatus.success);
        expect(state.preparationStepList.map((e) => e.id).toList(),
            ['A', 'B', 'C']);
      });

      test('1-3. Broken chain (no tail with next=null) -> failure PREP_NO_TAIL',
          () {
        final entity = PreparationEntity(preparationStepList: [
          stepEntity(
            id: 'A',
            name: 'A',
            time: const Duration(minutes: 1),
            nextId: 'B',
          ),
          stepEntity(
            id: 'B',
            name: 'B',
            time: const Duration(minutes: 1),
            nextId: 'C', // missing C (also no tail)
          ),
        ]);

        final result = PreparationFormState.fromEntity(entity);
        expect(result.isFailure, true);
        final failure = result.failureOrNull!;
        expect(failure, isA<PreparationChainFailure>());
        expect(failure.code, 'PREP_NO_TAIL');
      });

      test('1-4. Pure cycle (no tail) -> failure PREP_NO_TAIL', () {
        final entity = PreparationEntity(preparationStepList: [
          stepEntity(
            id: 'A',
            name: 'A',
            time: const Duration(minutes: 1),
            nextId: 'B',
          ),
          stepEntity(
            id: 'B',
            name: 'B',
            time: const Duration(minutes: 1),
            nextId: 'A',
          ),
        ]);

        final result = PreparationFormState.fromEntity(entity);
        expect(result.isFailure, true);
        final failure = result.failureOrNull!;
        expect(failure, isA<PreparationChainFailure>());
        expect(failure.code, 'PREP_NO_TAIL');
      });

      test('1-5. Two tails -> failure PREP_MULTIPLE_TAILS', () {
        final a = stepEntity(
          id: 'A',
          name: 'A',
          time: const Duration(minutes: 1),
          nextId: 'B',
        );
        final b = stepEntity(
          id: 'B',
          name: 'B',
          time: const Duration(minutes: 1),
          nextId: null,
        );
        final c = stepEntity(
          id: 'C',
          name: 'C',
          time: const Duration(minutes: 1),
          nextId: null,
        );

        final entity = PreparationEntity(preparationStepList: [c, b, a]);
        final result = PreparationFormState.fromEntity(entity);
        expect(result.isFailure, true);
        final failure = result.failureOrNull!;
        expect(failure, isA<PreparationChainFailure>());
        expect(failure.code, 'PREP_MULTIPLE_TAILS');
      });
    });

    group('toPreparationEntity (nextPreparationId generation)', () {
      test('2-1. [A,B,C] -> A.next=B, B.next=C, C.next=null', () {
        final a = createStepForm(
          id: 'A',
          name: 'A',
          time: const Duration(minutes: 1),
        );
        final b = createStepForm(
          id: 'B',
          name: 'B',
          time: const Duration(minutes: 2),
        );
        final c = createStepForm(
          id: 'C',
          name: 'C',
          time: const Duration(minutes: 3),
        );

        final state = PreparationFormState(
          preparationStepList: [a, b, c],
        );

        final entity = state.toPreparationEntity();
        final steps = entity.preparationStepList;

        expect(steps.map((e) => e.id).toList(), ['A', 'B', 'C']);
        expect(steps[0].nextPreparationId, 'B');
        expect(steps[1].nextPreparationId, 'C');
        expect(steps[2].nextPreparationId, isNull);
      });

      test('2-2. [B,A] -> B.next=A, A.next=null (order is list order)', () {
        final b = createStepForm(
          id: 'B',
          name: 'B',
          time: const Duration(minutes: 2),
        );
        final a = createStepForm(
          id: 'A',
          name: 'A',
          time: const Duration(minutes: 1),
        );

        final state = PreparationFormState(preparationStepList: [b, a]);
        final entity = state.toPreparationEntity();

        expect(
            entity.preparationStepList.map((e) => e.id).toList(), ['B', 'A']);
        expect(entity.preparationStepList[0].nextPreparationId, 'A');
        expect(entity.preparationStepList[1].nextPreparationId, isNull);
      });
    });

    group('copyWith / equality', () {
      test('3-1. copyWith updates only provided fields', () {
        const initial = PreparationFormState();
        final next = initial.copyWith(status: PreparationFormStatus.adding);

        expect(next.status, PreparationFormStatus.adding);
        expect(next.preparationStepList, isEmpty);
        expect(next.isValid, false);
      });

      test('3-2. Equatable: states with same props are equal', () {
        const a = PreparationFormState();
        const b = PreparationFormState();
        expect(a, b);
      });
    });
  });
}
