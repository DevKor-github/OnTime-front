import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/input_models/preparation_name_input_model.dart';
import 'package:on_time_front/presentation/onboarding/preparation_time/input_models/preparation_time_input_model.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/bloc/preparation_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/cubit/preparation_step_form_cubit.dart';

void main() {
  group('PreparationFormBloc Tests', () {
    // Helpers (deterministic IDs so we can assert exact order)
    PreparationStepFormState createStep({
      required String id,
      required String name,
      required Duration time,
      bool dirty = false,
    }) {
      return PreparationStepFormState(
        id: id,
        preparationName: dirty
            ? PreparationNameInputModel.dirty(name)
            : PreparationNameInputModel.pure(name),
        preparationTime: dirty
            ? PreparationTimeInputModel.dirty(time)
            : PreparationTimeInputModel.pure(time),
      );
    }

    // NOTE: PreparationFormBloc works with an ordered list of steps.
    // This test suite intentionally avoids testing linked-list style ordering
    // via nextPreparationId.

    group('1. Initialization', () {
      test('1-1. Default State', () {
        final bloc = PreparationFormBloc();
        expect(bloc.state, const PreparationFormState());
      });
    });

    // NOTE: Validation is tested indirectly via `state.isValid` after events,
    // since the bloc's validation helper is intentionally private.

    // (Removed) Tests around nextPreparationId parsing/constraints.

    group('4. Creation Flow', () {
      blocTest<PreparationFormBloc, PreparationFormState>(
        '4-1. Request Creation -> status becomes adding',
        build: PreparationFormBloc.new,
        act: (bloc) =>
            bloc.add(const PreparationFormPreparationStepCreationRequested()),
        expect: () => [
          isA<PreparationFormState>().having(
            (s) => s.status,
            'status',
            PreparationFormStatus.adding,
          ),
        ],
      );

      blocTest<PreparationFormBloc, PreparationFormState>(
        '4-2. Add valid step when status=adding -> appended, status resets',
        build: PreparationFormBloc.new,
        seed: () {
          final a = createStep(
            id: 'A',
            name: 'A',
            time: const Duration(minutes: 1),
            dirty: true,
          );
          final list = [a];
          return PreparationFormState(
            status: PreparationFormStatus.adding,
            preparationStepList: list,
            isValid: false,
          );
        },
        act: (bloc) {
          final b = createStep(
            id: 'B',
            name: 'B',
            time: const Duration(minutes: 2),
            dirty: true,
          );
          bloc.add(PreparationFormPreparationStepCreated(preparationStep: b));
        },
        expect: () => [
          isA<PreparationFormState>()
              .having((s) => s.status, 'status', PreparationFormStatus.initial)
              .having((s) => s.preparationStepList.map((e) => e.id).toList(),
                  'ids', ['A', 'B']).having((s) => s.isValid, 'isValid', true),
        ],
      );

      blocTest<PreparationFormBloc, PreparationFormState>(
        '4-3. Add invalid step (empty name) when status=adding -> ignored (no append)',
        build: PreparationFormBloc.new,
        seed: () {
          final a = createStep(
            id: 'A',
            name: 'A',
            time: const Duration(minutes: 1),
            dirty: true,
          );
          final list = [a];
          return PreparationFormState(
            status: PreparationFormStatus.adding,
            preparationStepList: list,
            isValid: false,
          );
        },
        act: (bloc) {
          // Preconditions: bloc is in adding mode and currently has [A].
          expect(bloc.state.status, PreparationFormStatus.adding);
          expect(
              bloc.state.preparationStepList.map((e) => e.id).toList(), ['A']);

          final invalid = createStep(
            id: 'B',
            name: '',
            time: const Duration(minutes: 2),
            dirty: true,
          );
          // The bloc's create-step gate is `preparationName.isValid`.
          // Prove this step is invalid *specifically due to name* (time stays valid).
          expect(invalid.preparationName.isValid, isFalse);
          expect(invalid.preparationTime.isValid, isTrue);

          bloc.add(
              PreparationFormPreparationStepCreated(preparationStep: invalid));
        },
        expect: () => [
          isA<PreparationFormState>()
              .having((s) => s.status, 'status', PreparationFormStatus.initial)
              .having((s) => s.preparationStepList.map((e) => e.id).toList(),
                  'ids', ['A']).having((s) => s.isValid, 'isValid', true),
        ],
      );

      blocTest<PreparationFormBloc, PreparationFormState>(
        '4-4. Add step when status!=adding -> ignored (no emits)',
        build: PreparationFormBloc.new,
        seed: () {
          final a = createStep(
            id: 'A',
            name: 'A',
            time: const Duration(minutes: 1),
            dirty: true,
          );
          final list = [a];
          return PreparationFormState(
            status: PreparationFormStatus.initial,
            preparationStepList: list,
            isValid: false,
          );
        },
        act: (bloc) {
          final b = createStep(
            id: 'B',
            name: 'B',
            time: const Duration(minutes: 2),
            dirty: true,
          );
          bloc.add(PreparationFormPreparationStepCreated(preparationStep: b));
        },
        expect: () => const [],
      );

      blocTest<PreparationFormBloc, PreparationFormState>(
        '4-5. Add step with valid name but invalid time when status=adding -> appended but isValid=false',
        build: PreparationFormBloc.new,
        seed: () {
          final a = createStep(
            id: 'A',
            name: 'A',
            time: const Duration(minutes: 1),
            dirty: true,
          );
          final list = [a];
          return PreparationFormState(
            status: PreparationFormStatus.adding,
            preparationStepList: list,
            isValid: false,
          );
        },
        act: (bloc) {
          final bInvalidTime = createStep(
            id: 'B',
            name: 'B', // name valid => passes the gate
            time: Duration.zero, // invalid time
            dirty: true,
          );
          bloc.add(PreparationFormPreparationStepCreated(
              preparationStep: bInvalidTime));
        },
        expect: () => [
          isA<PreparationFormState>().having(
              (s) => s.preparationStepList.map((e) => e.id).toList(),
              'ids',
              ['A', 'B']).having((s) => s.isValid, 'isValid', false),
        ],
      );
    });

    group('5. Modification (Name/Time) triggers validity recalculation', () {
      blocTest<PreparationFormBloc, PreparationFormState>(
        '5-1. Name change valid -> isValid true',
        build: PreparationFormBloc.new,
        seed: () {
          final a = createStep(
            id: 'A',
            name: '',
            time: const Duration(minutes: 1),
            dirty: true,
          );
          final list = [a];
          return PreparationFormState(
            preparationStepList: list,
            isValid: false,
          );
        },
        act: (bloc) => bloc.add(const PreparationFormPreparationStepNameChanged(
          index: 0,
          preparationStepName: 'A',
        )),
        expect: () => [
          isA<PreparationFormState>()
              .having((s) => s.preparationStepList[0].preparationName.value,
                  'name', 'A')
              .having((s) => s.isValid, 'isValid', true),
        ],
      );

      blocTest<PreparationFormBloc, PreparationFormState>(
        '5-2. Name change invalid (empty) -> isValid false',
        build: PreparationFormBloc.new,
        seed: () {
          final a = createStep(
            id: 'A',
            name: 'A',
            time: const Duration(minutes: 1),
            dirty: true,
          );
          final list = [a];
          return PreparationFormState(
            preparationStepList: list,
            isValid: false,
          );
        },
        act: (bloc) => bloc.add(const PreparationFormPreparationStepNameChanged(
          index: 0,
          preparationStepName: '',
        )),
        expect: () => [
          isA<PreparationFormState>()
              .having((s) => s.preparationStepList[0].preparationName.value,
                  'name', '')
              .having((s) => s.isValid, 'isValid', false),
        ],
      );

      blocTest<PreparationFormBloc, PreparationFormState>(
        '5-3. Time change valid -> isValid true',
        build: PreparationFormBloc.new,
        seed: () {
          final a = createStep(
            id: 'A',
            name: 'A',
            time: Duration.zero,
            dirty: true,
          );
          final list = [a];
          return PreparationFormState(
            preparationStepList: list,
            isValid: false,
          );
        },
        act: (bloc) => bloc.add(const PreparationFormPreparationStepTimeChanged(
          index: 0,
          preparationStepTime: Duration(minutes: 10),
        )),
        expect: () => [
          isA<PreparationFormState>()
              .having((s) => s.preparationStepList[0].preparationTime.value,
                  'time', const Duration(minutes: 10))
              .having((s) => s.isValid, 'isValid', true),
        ],
      );

      blocTest<PreparationFormBloc, PreparationFormState>(
        '5-4. Time change invalid (0m) -> isValid false',
        build: PreparationFormBloc.new,
        seed: () {
          final a = createStep(
            id: 'A',
            name: 'A',
            time: const Duration(minutes: 1),
            dirty: true,
          );
          final list = [a];
          return PreparationFormState(
            preparationStepList: list,
            isValid: false,
          );
        },
        act: (bloc) => bloc.add(const PreparationFormPreparationStepTimeChanged(
          index: 0,
          preparationStepTime: Duration.zero,
        )),
        expect: () => [
          isA<PreparationFormState>()
              .having((s) => s.preparationStepList[0].preparationTime.value,
                  'time', Duration.zero)
              .having((s) => s.isValid, 'isValid', false),
        ],
      );

      blocTest<PreparationFormBloc, PreparationFormState>(
        '5-5. Name change with invalid index throws RangeError',
        build: PreparationFormBloc.new,
        seed: () {
          final a = createStep(
            id: 'A',
            name: 'A',
            time: const Duration(minutes: 1),
            dirty: true,
          );
          return PreparationFormState(
            preparationStepList: [a],
            isValid: true,
          );
        },
        act: (bloc) => bloc.add(const PreparationFormPreparationStepNameChanged(
          index: 1,
          preparationStepName: 'X',
        )),
        expect: () => const [],
        errors: () => [isA<RangeError>()],
      );
    });

    group('6. Removal', () {
      PreparationFormState seedABC() {
        final a = createStep(
          id: 'A',
          name: 'A',
          time: const Duration(minutes: 1),
          dirty: true,
        );
        final b = createStep(
          id: 'B',
          name: 'B',
          time: const Duration(minutes: 2),
          dirty: true,
        );
        final c = createStep(
          id: 'C',
          name: 'C',
          time: const Duration(minutes: 3),
          dirty: true,
        );
        final list = [a, b, c];
        return PreparationFormState(
          preparationStepList: list,
          isValid: false,
        );
      }

      blocTest<PreparationFormBloc, PreparationFormState>(
        '6-1. Remove head (A) from [A,B,C] -> [B,C]',
        build: PreparationFormBloc.new,
        seed: seedABC,
        act: (bloc) => bloc.add(const PreparationFormPreparationStepRemoved(
            preparationStepId: 'A')),
        expect: () => [
          isA<PreparationFormState>().having(
              (s) => s.preparationStepList.map((e) => e.id).toList(),
              'ids',
              ['B', 'C']).having((s) => s.isValid, 'isValid', true),
        ],
      );

      blocTest<PreparationFormBloc, PreparationFormState>(
        '6-2. Remove middle (B) from [A,B,C] -> [A,C]',
        build: PreparationFormBloc.new,
        seed: seedABC,
        act: (bloc) => bloc.add(const PreparationFormPreparationStepRemoved(
            preparationStepId: 'B')),
        expect: () => [
          isA<PreparationFormState>().having(
              (s) => s.preparationStepList.map((e) => e.id).toList(),
              'ids',
              ['A', 'C']).having((s) => s.isValid, 'isValid', true),
        ],
      );

      blocTest<PreparationFormBloc, PreparationFormState>(
        '6-3. Remove tail (C) from [A,B,C] -> [A,B]',
        build: PreparationFormBloc.new,
        seed: seedABC,
        act: (bloc) => bloc.add(const PreparationFormPreparationStepRemoved(
            preparationStepId: 'C')),
        expect: () => [
          isA<PreparationFormState>().having(
              (s) => s.preparationStepList.map((e) => e.id).toList(),
              'ids',
              ['A', 'B']).having((s) => s.isValid, 'isValid', true),
        ],
      );

      blocTest<PreparationFormBloc, PreparationFormState>(
        '6-4. Remove when size=1 -> blocked (no emits)',
        build: PreparationFormBloc.new,
        seed: () {
          final a = createStep(
            id: 'A',
            name: 'A',
            time: const Duration(minutes: 1),
            dirty: true,
          );
          final list = [a];
          return PreparationFormState(
            preparationStepList: list,
            isValid: false,
          );
        },
        act: (bloc) => bloc.add(const PreparationFormPreparationStepRemoved(
            preparationStepId: 'A')),
        expect: () => const [],
      );

      blocTest<PreparationFormBloc, PreparationFormState>(
        '6-5. Remove non-existent ID from list>1 -> no emit (deduped by equality)',
        build: PreparationFormBloc.new,
        seed: () {
          final a = createStep(
            id: 'A',
            name: 'A',
            time: const Duration(minutes: 1),
            dirty: true,
          );
          final b = createStep(
            id: 'B',
            name: 'B',
            time: const Duration(minutes: 2),
            dirty: true,
          );
          final list = [a, b];
          return PreparationFormState(
            preparationStepList: list,
            isValid: true,
          );
        },
        act: (bloc) => bloc.add(const PreparationFormPreparationStepRemoved(
            preparationStepId: 'Z')),
        expect: () => const [],
      );
    });

    group('7. Reordering', () {
      PreparationFormState seedABCD() {
        final a = createStep(
          id: 'A',
          name: 'A',
          time: const Duration(minutes: 1),
          dirty: true,
        );
        final b = createStep(
          id: 'B',
          name: 'B',
          time: const Duration(minutes: 2),
          dirty: true,
        );
        final c = createStep(
          id: 'C',
          name: 'C',
          time: const Duration(minutes: 3),
          dirty: true,
        );
        final d = createStep(
          id: 'D',
          name: 'D',
          time: const Duration(minutes: 4),
          dirty: true,
        );
        final list = [a, b, c, d];
        return PreparationFormState(
          preparationStepList: list,
          isValid: false,
        );
      }

      blocTest<PreparationFormBloc, PreparationFormState>(
        '7-1. Move head to next (0->1): Flutter newIndex=2 -> [B,A,C,D]',
        build: PreparationFormBloc.new,
        seed: seedABCD,
        act: (bloc) => bloc.add(
          const PreparationFormPreparationStepOrderChanged(
              oldIndex: 0, newIndex: 2),
        ),
        expect: () => [
          isA<PreparationFormState>().having(
            (s) => s.preparationStepList.map((e) => e.id).toList(),
            'ids',
            ['B', 'A', 'C', 'D'],
          ),
        ],
      );

      blocTest<PreparationFormBloc, PreparationFormState>(
        '7-2. Move next to head (1->0) -> [B,A,C,D]',
        build: PreparationFormBloc.new,
        seed: seedABCD,
        act: (bloc) => bloc.add(
          const PreparationFormPreparationStepOrderChanged(
              oldIndex: 1, newIndex: 0),
        ),
        expect: () => [
          isA<PreparationFormState>().having(
            (s) => s.preparationStepList.map((e) => e.id).toList(),
            'ids',
            ['B', 'A', 'C', 'D'],
          ),
        ],
      );

      blocTest<PreparationFormBloc, PreparationFormState>(
        '7-3. Move head to last (0->last): newIndex=list.length -> [B,C,D,A]',
        build: PreparationFormBloc.new,
        seed: seedABCD,
        act: (bloc) => bloc.add(
          const PreparationFormPreparationStepOrderChanged(
              oldIndex: 0, newIndex: 4),
        ),
        expect: () => [
          isA<PreparationFormState>().having(
            (s) => s.preparationStepList.map((e) => e.id).toList(),
            'ids',
            ['B', 'C', 'D', 'A'],
          ),
        ],
      );

      blocTest<PreparationFormBloc, PreparationFormState>(
        '7-4. Move tail to head (last->0) -> [D,A,B,C]',
        build: PreparationFormBloc.new,
        seed: seedABCD,
        act: (bloc) => bloc.add(
          const PreparationFormPreparationStepOrderChanged(
              oldIndex: 3, newIndex: 0),
        ),
        expect: () => [
          isA<PreparationFormState>().having(
            (s) => s.preparationStepList.map((e) => e.id).toList(),
            'ids',
            ['D', 'A', 'B', 'C'],
          ),
        ],
      );

      blocTest<PreparationFormBloc, PreparationFormState>(
        '7-5. Move middle down one (1->2): newIndex=3 -> [A,C,B,D]',
        build: PreparationFormBloc.new,
        seed: seedABCD,
        act: (bloc) => bloc.add(
          const PreparationFormPreparationStepOrderChanged(
              oldIndex: 1, newIndex: 3),
        ),
        expect: () => [
          isA<PreparationFormState>().having(
            (s) => s.preparationStepList.map((e) => e.id).toList(),
            'ids',
            ['A', 'C', 'B', 'D'],
          ),
        ],
      );

      blocTest<PreparationFormBloc, PreparationFormState>(
        '7-6. Move middle up one (2->1) -> [A,C,B,D]',
        build: PreparationFormBloc.new,
        seed: seedABCD,
        act: (bloc) => bloc.add(
          const PreparationFormPreparationStepOrderChanged(
              oldIndex: 2, newIndex: 1),
        ),
        expect: () => [
          isA<PreparationFormState>().having(
            (s) => s.preparationStepList.map((e) => e.id).toList(),
            'ids',
            ['A', 'C', 'B', 'D'],
          ),
        ],
      );
    });
  });
}
