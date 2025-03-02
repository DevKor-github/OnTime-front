import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/use-cases/onboard_use_case.dart';

part 'onboarding_state.dart';

@Injectable()
class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit(
    this._createDefaultPreparationUseCase,
  ) : super(OnboardingState());

  final OnboardUseCase _createDefaultPreparationUseCase;

  Future<void> onboardingFormSubmitted() async {
    return await _createDefaultPreparationUseCase(
      preparationEntity: state.toEntity(),
      spareTime: state.spareTime!,
      note: state.note ?? '',
    );
  }

  void onboardingFormChanged({
    List<OnboardingPreparationStepState>? preparationStepList,
    Duration? spareTime,
  }) {
    emit(state.copyWith(
        preparationStepList: preparationStepList, spareTime: spareTime));
  }

  void onboardingFormValidated({
    required bool isValid,
  }) {
    emit(state.copyWith(isValid: isValid));
  }
}
