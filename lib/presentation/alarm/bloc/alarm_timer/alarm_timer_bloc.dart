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

  AlarmTimerBloc({
    required List<PreparationStepEntity> preparationSteps,
    required int beforeOutTime,
    required bool isLate,
  }) : super(AlarmTimerInitial(
          preparationSteps: preparationSteps,
          currentStepIndex: 0,
          stepElapsedTimes: List.generate(preparationSteps.length, (_) => 0),
          preparationStepStates: List.generate(
              preparationSteps.length, (_) => PreparationStateEnum.yet),
          preparationRemainingTime:
              preparationSteps.first.preparationTime.inSeconds,
          totalRemainingTime: preparationSteps.fold(
              0, (sum, step) => sum + step.preparationTime.inSeconds),
          totalPreparationTime: preparationSteps.fold(
              0, (sum, step) => sum + step.preparationTime.inSeconds),
          progress: 0.0,
          beforeOutTime: beforeOutTime,
          isLate: isLate,
        )) {
    on<AlarmTimerStepStarted>(_onStepStarted);
    on<AlarmTimerStepTicked>(_onStepTicked);
    on<AlarmTimerStepSkipped>(_onStepSkipped);
    on<AlarmTimerStepNextShifted>(_onStepNext);
    on<AlarmTimerStepFinalized>(_onStepFinalized);
    on<AlarmTimerStepsUpdated>(_onStepUpdated);
    on<AlarmTimerPreparationsTimeOvered>(_onPreparationsTimeOvered);
  }

  void _onStepUpdated(
      AlarmTimerStepsUpdated event, Emitter<AlarmTimerState> emit) {
    emit(state.copyWith(
      preparationSteps: event.preparationSteps,
    ));

    if (event.preparationSteps.isNotEmpty) {
      add(AlarmTimerStepStarted(
          event.preparationSteps.first.preparationTime.inSeconds));
    }
  }

  void _onStepStarted(
      AlarmTimerStepStarted event, Emitter<AlarmTimerState> emit) {
    final updatedStates =
        List<PreparationStateEnum>.from(state.preparationStepStates);
    updatedStates[state.currentStepIndex] = PreparationStateEnum.now;

    final updatedBeforeOutTime = state.beforeOutTime;
    final updatedIsLate = updatedBeforeOutTime <= 0;

    emit(state.copyWith(
      preparationStepStates: updatedStates,
      preparationRemainingTime: event.duration,
      stepElapsedTimes: List.from(state.stepElapsedTimes),
      beforeOutTime: updatedBeforeOutTime,
      isLate: updatedIsLate,
    ));

    _startTicker(event.duration, emit);
  }

  void _onStepTicked(
      AlarmTimerStepTicked event, Emitter<AlarmTimerState> emit) {
    final updatedStepElapsedTimes = List<int>.from(state.stepElapsedTimes);
    updatedStepElapsedTimes[state.currentStepIndex] =
        event.preparationElapsedTime;

    final updatedTotalRemaining = state.totalRemainingTime - 1;

    final double updatedProgress =
        1.0 - (updatedTotalRemaining / state.totalPreparationTime);

    if (event.preparationRemainingTime > 0) {
      emit(state.copyWith(
        preparationRemainingTime: event.preparationRemainingTime,
        stepElapsedTimes: updatedStepElapsedTimes,
        totalRemainingTime: updatedTotalRemaining,
        progress: updatedProgress,
        beforeOutTime: event.beforeOutTime,
        isLate: event.isLate,
      ));
    } else {
      add(const AlarmTimerStepNextShifted());
    }
  }

  void _startTicker(int duration, Emitter<AlarmTimerState> emit) {
    _tickerSubscription?.cancel();
    _tickerSubscription = Stream.periodic(const Duration(seconds: 1), (x) => x)
        .take(duration)
        .listen((tick) {
      final newElapsed = tick + 1;
      final newRemaining = duration - newElapsed;
      final updatedTotalRemaining = state.totalRemainingTime - 1;

      final updatedBeforeOutTime = state.beforeOutTime - 1;
      final updatedIsLate = updatedBeforeOutTime <= 0;

      add(AlarmTimerStepTicked(
        preparationRemainingTime: newRemaining,
        preparationElapsedTime: newElapsed,
        totalRemainingTime: updatedTotalRemaining,
        beforeOutTime: updatedBeforeOutTime,
        isLate: updatedIsLate,
      ));
    });
  }

  void _onStepSkipped(
      AlarmTimerStepSkipped event, Emitter<AlarmTimerState> emit) {
    final updatedStates =
        List<PreparationStateEnum>.from(state.preparationStepStates);
    updatedStates[state.currentStepIndex] = PreparationStateEnum.done;

    final updatedRemainingTime =
        state.totalRemainingTime - state.preparationRemainingTime;

    final updatedProgress =
        1.0 - (updatedRemainingTime / state.totalPreparationTime);

    _tickerSubscription?.cancel();
    emit(state.copyWith(
      preparationStepStates: updatedStates,
      totalRemainingTime: updatedRemainingTime,
      progress: updatedProgress,
    ));

    add(const AlarmTimerStepNextShifted());
  }

  void _onStepNext(
      AlarmTimerStepNextShifted event, Emitter<AlarmTimerState> emit) {
    _tickerSubscription?.cancel();

    final isLastStep =
        state.currentStepIndex + 1 >= state.preparationSteps.length;

    if (!isLastStep) {
      final nextStepIndex = state.currentStepIndex + 1;
      final nextStepDuration =
          state.preparationSteps[nextStepIndex].preparationTime.inSeconds;

      final updatedStepStates =
          List<PreparationStateEnum>.from(state.preparationStepStates);

      updatedStepStates[state.currentStepIndex] = PreparationStateEnum.done;
      updatedStepStates[nextStepIndex] = PreparationStateEnum.now;

      emit(state.copyWith(
        currentStepIndex: nextStepIndex,
        preparationStepStates: updatedStepStates,
        preparationRemainingTime: nextStepDuration,
      ));

      add(AlarmTimerStepStarted(nextStepDuration));
    } else {
      final wasSkipped = state.preparationStepStates[state.currentStepIndex] ==
          PreparationStateEnum.done;
      if (wasSkipped) {
        add(const AlarmTimerStepFinalized());
      } else {
        add(const AlarmTimerPreparationsTimeOvered());
      }
    }
  }

  Future<void> _onStepFinalized(
      AlarmTimerStepFinalized event, Emitter<AlarmTimerState> emit) async {
    await _tickerSubscription?.cancel();

    emit(state.copyWith(progress: 1.0));

    await Future.delayed(const Duration(milliseconds: 500));

    emit(AlarmTimerPreparationCompletion(
      preparationSteps: state.preparationSteps,
      currentStepIndex: state.currentStepIndex,
      stepElapsedTimes: state.stepElapsedTimes,
      preparationStepStates: state.preparationStepStates,
      preparationRemainingTime: 0,
      totalRemainingTime: 0,
      totalPreparationTime: state.totalPreparationTime,
      progress: 1.0,
      beforeOutTime: state.beforeOutTime,
      isLate: state.isLate,
    ));
  }

  @override
  Future<void> close() {
    _tickerSubscription?.cancel();
    return super.close();
  }

  void _onPreparationsTimeOvered(
    AlarmTimerPreparationsTimeOvered event,
    Emitter<AlarmTimerState> emit,
  ) {
    final updatedStates =
        List<PreparationStateEnum>.from(state.preparationStepStates);
    updatedStates[state.currentStepIndex] = PreparationStateEnum.done;

    emit(AlarmTimerPreparationsTimeOver(
      preparationSteps: state.preparationSteps,
      currentStepIndex: state.currentStepIndex,
      stepElapsedTimes: state.stepElapsedTimes,
      preparationStepStates: updatedStates,
      preparationRemainingTime: 0,
      totalRemainingTime: 0,
      totalPreparationTime: state.totalPreparationTime,
      progress: 1.0,
      beforeOutTime: state.beforeOutTime,
      isLate: state.isLate,
    ));

    _tickerSubscription?.cancel();
    _tickerSubscription =
        Stream.periodic(const Duration(seconds: 1), (x) => x).listen((tick) {
      final updatedBeforeOutTime = state.beforeOutTime - 1;
      final updatedIsLate = updatedBeforeOutTime <= 0;

      emit(
        (state as AlarmTimerPreparationsTimeOver).copyWith(
          beforeOutTime: updatedBeforeOutTime,
          isLate: updatedIsLate,
        ),
      );
    });
  }
}
