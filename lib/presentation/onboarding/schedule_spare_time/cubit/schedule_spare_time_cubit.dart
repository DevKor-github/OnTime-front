import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/presentation/onboarding/cubit/onboarding_cubit.dart';

part 'schedule_spare_time_state.dart';

class ScheduleSpareTimeCubit extends Cubit<ScheduleSpareTimeState> {
  ScheduleSpareTimeCubit({
    required this.onboardingCubit,
  }) : super(ScheduleSpareTimeState());

  final OnboardingCubit onboardingCubit;
  final Duration lowerBound = Duration(minutes: 10);
  final Duration stepSize = Duration(minutes: 5);

  void initialize() {
    emit(ScheduleSpareTimeState.fromOnboardingState(onboardingCubit.state));
    onboardingCubit.onboardingFormValidated(isValid: true);
  }

  void spareTimeDecreased() {
    if (state.spareTime - stepSize >= lowerBound) {
      emit(state.copyWith(spareTime: state.spareTime - stepSize));
    }
  }

  void spareTimeIncreased() {
    emit(state.copyWith(spareTime: state.spareTime + stepSize));
  }

  void spareTimeSaved() {
    onboardingCubit.onboardingFormChanged(spareTime: state.spareTime);
  }
}
