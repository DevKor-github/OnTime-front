import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/presentation/onboarding/cubit/onboarding/onboarding_cubit.dart';

part 'preparation_order_state.dart';

class PreparationOrderCubit extends Cubit<PreparationOrderState> {
  PreparationOrderCubit({
    required this.onboardingCubit,
  }) : super(PreparationOrderState()) {
    initialize();
  }

  final OnboardingCubit onboardingCubit;

  void initialize() {
    emit(PreparationOrderState.fromOnboardingState(onboardingCubit.state));
  }

  void preparationOrderChanged() {}
}
