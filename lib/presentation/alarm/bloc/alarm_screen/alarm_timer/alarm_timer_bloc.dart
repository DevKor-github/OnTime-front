library;

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/presentation/shared/constants/constants.dart';

part 'alarm_timer_event.dart';
part 'alarm_timer_state.dart';

@injectable
class AlarmTimerBloc extends Bloc<AlarmTimerEvent, AlarmTimerState> {
  StreamSubscription<int>? _tickerSubscription;

  AlarmTimerBloc({required List<PreparationStepEntity> preparationSteps})
      : super(AlarmTimerInitial(
          preparationSteps: preparationSteps,
          currentStepIndex: 0,
          stepElapsedTimes: List.generate(preparationSteps.length, (_) => 0),
          preparationStates: List.generate(
              preparationSteps.length, (_) => PreparationStateEnum.yet),
          preparationRemainingTime:
              preparationSteps.first.preparationTime.inSeconds,
          totalRemainingTime: preparationSteps.fold(
              0, (sum, step) => sum + step.preparationTime.inSeconds),
          totalPreparationTime: preparationSteps.fold(
              0, (sum, step) => sum + step.preparationTime.inSeconds),
        )) {
    on<AlarmTimerStepStarted>(_onStepStarted);
    on<AlarmTimerStepTicked>(_onStepTicked);
    on<AlarmTimerStepSkipped>(_onStepSkipped);
    on<AlarmTimerStepNextShifted>(_onStepNext);
    on<AlarmTimerStepFinalized>(_onStepFinalized);
    on<AlarmTimerStepsUpdated>(_onStepUpdated);
  }

  void _onStepUpdated(
      AlarmTimerStepsUpdated event, Emitter<AlarmTimerState> emit) {
    emit(state.copyWith(preparationSteps: event.preparationSteps));

    if (event.preparationSteps.isNotEmpty) {
      add(AlarmTimerStepStarted(
          event.preparationSteps.first.preparationTime.inSeconds));
    }
  }

  void _onStepStarted(
      AlarmTimerStepStarted event, Emitter<AlarmTimerState> emit) {
    final updatedStates =
        List<PreparationStateEnum>.from(state.preparationStates);
    updatedStates[state.currentStepIndex] = PreparationStateEnum.now;

    emit(state.copyWith(
      preparationStates: updatedStates,
      preparationRemainingTime: event.duration,
      stepElapsedTimes: List.from(state.stepElapsedTimes),
    ));

    _startTicker(event.duration, emit);
  }

  void _onStepTicked(
      AlarmTimerStepTicked event, Emitter<AlarmTimerState> emit) {
    final updatedStepElapsedTimes = List<int>.from(state.stepElapsedTimes);
    updatedStepElapsedTimes[state.currentStepIndex] =
        event.preparationElapsedTime;

    if (event.preparationRemainingTime > 0) {
      emit(state.copyWith(
        preparationRemainingTime: event.preparationRemainingTime,
        stepElapsedTimes: updatedStepElapsedTimes,
      ));
    } else {
      add(const AlarmTimerStepNextShifted());
    }
  }

  void _onStepSkipped(
      AlarmTimerStepSkipped event, Emitter<AlarmTimerState> emit) {
    final updatedStates =
        List<PreparationStateEnum>.from(state.preparationStates);
    updatedStates[state.currentStepIndex] = PreparationStateEnum.done;

    final updatedRemainingTime =
        state.totalRemainingTime - state.preparationRemainingTime;

    _tickerSubscription?.cancel();
    emit(state.copyWith(
      preparationStates: updatedStates,
      totalRemainingTime: updatedRemainingTime,
    ));

    add(const AlarmTimerStepNextShifted());
  }

  void _onStepNext(
      AlarmTimerStepNextShifted event, Emitter<AlarmTimerState> emit) {
    _tickerSubscription?.cancel();

    if (state.currentStepIndex + 1 < state.preparationSteps.length) {
      final nextIndex = state.currentStepIndex + 1;
      final nextStepDuration =
          state.preparationSteps[nextIndex].preparationTime.inSeconds;

      final updatedStates =
          List<PreparationStateEnum>.from(state.preparationStates);

      updatedStates[state.currentStepIndex] = PreparationStateEnum.done;

      updatedStates[nextIndex] = PreparationStateEnum.now;

      emit(state.copyWith(
        currentStepIndex: nextIndex,
        preparationStates: updatedStates,
        preparationRemainingTime: nextStepDuration,
      ));

      add(AlarmTimerStepStarted(nextStepDuration));
    } else {
      add(const AlarmTimerStepFinalized());
    }
  }

  Future<void> _onStepFinalized(
      AlarmTimerStepFinalized event, Emitter<AlarmTimerState> emit) async {
    await _tickerSubscription?.cancel();
    emit(AlarmTimerPreparationCompletion(
      preparationSteps: state.preparationSteps,
      currentStepIndex: state.currentStepIndex,
      stepElapsedTimes: state.stepElapsedTimes,
      preparationStates: state.preparationStates,
      preparationRemainingTime: 0,
      totalRemainingTime: 0,
      totalPreparationTime: state.totalPreparationTime,
    ));
  }

  void _startTicker(int duration, Emitter<AlarmTimerState> emit) {
    _tickerSubscription?.cancel();
    _tickerSubscription = Stream.periodic(const Duration(seconds: 1), (x) => x)
        .take(duration)
        .listen((tick) {
      final newElapsed = tick + 1;
      final newRemaining = duration - newElapsed;
      final updatedTotalRemaining = state.totalRemainingTime - 1;

      add(AlarmTimerStepTicked(
        preparationRemainingTime: newRemaining,
        preparationElapsedTime: newElapsed,
        totalRemainingTime: updatedTotalRemaining,
      ));
    });
  }

  @override
  Future<void> close() {
    _tickerSubscription?.cancel();
    return super.close();
  }
}
