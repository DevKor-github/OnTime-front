import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';
import 'package:on_time_front/domain/use-cases/onboard_use_case.dart';
import 'package:on_time_front/presentation/onboarding/cubit/onboarding_cubit.dart';

void main() {
  test(
    'OnboardingPreparationStepState copyWith updates and clears linkage',
    () {
      const step = OnboardingPreparationStepState(
        id: 'step-1',
        preparationName: 'Shower',
        preparationTime: Duration(minutes: 10),
        nextPreparationId: 'step-2',
      );

      expect(step.copyWith(preparationName: 'Pack').preparationName, 'Pack');
      expect(step.copyWith(nextPreparationId: '').nextPreparationId, isNull);
    },
  );

  test('OnboardingState copies form values and converts steps to entity', () {
    const step = OnboardingPreparationStepState(
      id: 'step-1',
      preparationName: 'Shower',
      preparationTime: Duration(minutes: 10),
      nextPreparationId: 'step-2',
    );

    final state = const OnboardingState().copyWith(
      preparationStepList: [step],
      spareTime: const Duration(minutes: 5),
      note: 'Leave early',
      isValid: true,
    );
    final entity = state.toEntity();

    expect(state.preparationStepList, [step]);
    expect(state.spareTime, const Duration(minutes: 5));
    expect(state.note, 'Leave early');
    expect(state.isValid, isTrue);
    expect(entity.preparationStepList.single.id, 'step-1');
    expect(entity.preparationStepList.single.preparationName, 'Shower');
    expect(
      entity.preparationStepList.single.preparationTime,
      const Duration(minutes: 10),
    );
    expect(entity.preparationStepList.single.nextPreparationId, 'step-2');
  });

  test(
    'OnboardingCubit emits form changes and submits onboarding payload',
    () async {
      final useCase = _FakeOnboardUseCase();
      final cubit = OnboardingCubit(useCase);
      addTearDown(cubit.close);
      const step = OnboardingPreparationStepState(
        id: 'step-1',
        preparationName: 'Shower',
        preparationTime: Duration(minutes: 10),
      );

      cubit.onboardingFormChanged(
        preparationStepList: [step],
        spareTime: const Duration(minutes: 5),
      );
      cubit.onboardingFormValidated(isValid: true);
      await cubit.onboardingFormSubmitted();

      expect(cubit.state.preparationStepList, [step]);
      expect(cubit.state.spareTime, const Duration(minutes: 5));
      expect(cubit.state.isValid, isTrue);
      expect(useCase.submissions.single.spareTime, const Duration(minutes: 5));
      expect(useCase.submissions.single.note, '');
      expect(
        useCase
            .submissions
            .single
            .preparationEntity
            .preparationStepList
            .single
            .id,
        'step-1',
      );
    },
  );
}

class _OnboardingSubmission {
  const _OnboardingSubmission({
    required this.preparationEntity,
    required this.spareTime,
    required this.note,
  });

  final PreparationEntity preparationEntity;
  final Duration spareTime;
  final String note;
}

class _FakeOnboardUseCase extends OnboardUseCase {
  _FakeOnboardUseCase()
    : super(_FakePreparationRepository(), _FakeUserRepository());

  final submissions = <_OnboardingSubmission>[];

  @override
  Future<void> call({
    required PreparationEntity preparationEntity,
    required Duration spareTime,
    required String note,
  }) async {
    submissions.add(
      _OnboardingSubmission(
        preparationEntity: preparationEntity,
        spareTime: spareTime,
        note: note,
      ),
    );
  }
}

class _FakePreparationRepository implements PreparationRepository {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserRepository implements UserRepository {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
