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
          elapsedTimes: List.generate(preparationSteps.length, (_) => 0),
          preparationStates: List.generate(
              preparationSteps.length, (_) => PreparationStateEnum.yet),
          preparationRemainingTime:
              preparationSteps.first.preparationTime.inSeconds,
          totalRemainingTime: preparationSteps.fold(
              0, (sum, step) => sum + step.preparationTime.inSeconds),
          totalPreparationTime: preparationSteps.fold(
              0, (sum, step) => sum + step.preparationTime.inSeconds),
        )) {
    on<TimerStepStarted>(_onStepStarted);
    on<TimerStepTicked>(_onStepTicked);
    on<TimerStepSkipped>(_onStepSkipped);
    on<TimerStepNextShifted>(_onStepNext);
    on<TimerStepFinalized>(_onStepFinalized);
    on<TimerStepsUpdated>(_onPreparationStepsUpdated);
  }

  void _onPreparationStepsUpdated(
      TimerStepsUpdated event, Emitter<AlarmTimerState> emit) {
    emit(state.copyWith(preparationSteps: event.preparationSteps));

    if (event.preparationSteps.isNotEmpty) {
      add(TimerStepStarted(
          event.preparationSteps.first.preparationTime.inSeconds));
    }
  }

  void _onStepStarted(TimerStepStarted event, Emitter<AlarmTimerState> emit) {
    final updatedStates =
        List<PreparationStateEnum>.from(state.preparationStates);
    updatedStates[state.currentStepIndex] = PreparationStateEnum.now;

    emit(state.copyWith(
      preparationStates: updatedStates,
      preparationRemainingTime: event.duration,
      elapsedTimes: List.from(state.elapsedTimes),
    ));

    _startTicker(event.duration, emit);
  }

  void _onStepTicked(TimerStepTicked event, Emitter<AlarmTimerState> emit) {
    final updatedElapsedTimes = List<int>.from(state.elapsedTimes);
    updatedElapsedTimes[state.currentStepIndex] = event.preparationElapsedTime;

    if (event.preparationRemainingTime > 0) {
      emit(state.copyWith(
        preparationRemainingTime: event.preparationRemainingTime,
        elapsedTimes: updatedElapsedTimes,
      ));
    } else {
      add(const TimerStepNextShifted());
    }
  }

  void _onStepSkipped(TimerStepSkipped event, Emitter<AlarmTimerState> emit) {
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

    add(const TimerStepNextShifted());
  }

  void _onStepNext(TimerStepNextShifted event, Emitter<AlarmTimerState> emit) {
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

      add(TimerStepStarted(nextStepDuration));
    } else {
      add(const TimerStepFinalized());
    }
  }

  Future<void> _onStepFinalized(
      TimerStepFinalized event, Emitter<AlarmTimerState> emit) async {
    await _tickerSubscription?.cancel();
    emit(AlarmTimerPreparationCompletion(
      preparationSteps: state.preparationSteps,
      currentStepIndex: state.currentStepIndex,
      elapsedTimes: state.elapsedTimes,
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

      add(TimerStepTicked(
        preparationRemainingTime: newRemaining,
        preparationElapsedTime: newElapsed,
      ));

      emit(state.copyWith(
        totalRemainingTime: updatedTotalRemaining,
        preparationRemainingTime: newRemaining,
      ));
    });
  }

  @override
  Future<void> close() {
    _tickerSubscription?.cancel();
    return super.close();
  }
}
