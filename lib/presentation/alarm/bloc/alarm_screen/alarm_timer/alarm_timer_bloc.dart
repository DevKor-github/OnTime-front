library;

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';

part 'alarm_timer_event.dart';
part 'alarm_timer_state.dart';

@injectable
class AlarmTimerBloc extends Bloc<AlarmTimerEvent, AlarmTimerState> {
  final List<PreparationStepEntity> preparationSteps; // preparation 데이터

  StreamSubscription<int>? _tickerSubscription;

  int _currentStepIndex = 0;
  int _currentRemaining = 0;
  int _currentElapsed = 0;

  // 각 준비과정 상태 (yet, now, done)
  final List<String> _preparationStates;

  final List<int> _elapsedTimes;

  final int _totalPreparationTime;
  int _totalRemaining;

  AlarmTimerBloc({required this.preparationSteps})
      : _preparationStates =
            List.generate(preparationSteps.length, (index) => 'yet'),
        _elapsedTimes = List.generate(preparationSteps.length, (index) => 0),
        _totalPreparationTime = preparationSteps.fold<int>(
            0, (sum, step) => sum + step.preparationTime.inSeconds),
        _totalRemaining = preparationSteps.fold<int>(
            0, (sum, step) => sum + step.preparationTime.inSeconds),
        super(AlarmTimerInitial(
          duration: preparationSteps[0].preparationTime.inSeconds,
          currentStepIndex: 0,
          elapsedTime: 0,
          preparationName: preparationSteps[0].preparationName,
          preparationState: 'yet',
        )) {
    on<TimerStepStarted>(_onStepStarted);
    on<TimerStepTicked>(_onStepTicked);
    on<TimerStepSkipped>(_onStepSkipped);
    on<TimerStepNextShifted>(_onStepNext);
    on<TimerStepFinalized>(_onStepFinalized);
  }

  int get currentStepIndex => _currentStepIndex;

  List<String> get preparationStates => List.unmodifiable(_preparationStates);
  List<int> get elapsedTimes => List.unmodifiable(_elapsedTimes);

  void _onStepStarted(TimerStepStarted event, Emitter<AlarmTimerState> emit) {
    _currentRemaining = event.duration;
    _currentElapsed = 0;

    String preparationName =
        preparationSteps[_currentStepIndex].preparationName;

    _preparationStates[_currentStepIndex] = 'now';

    emit(AlarmTimerRunInProgress(
      preparationRemainingTime: _currentRemaining,
      currentStepIndex: _currentStepIndex,
      preparationStepelapsedTime: _currentElapsed,
      progress: progress,
      preparationStepName: preparationName,
      preparationState: _preparationStates[_currentStepIndex],
    ));
    _startTicker(event.duration);
  }

  void _onStepTicked(TimerStepTicked event, Emitter<AlarmTimerState> emit) {
    if (event.preparationRemainingTime > 0) {
      _currentElapsed = event.preparationElapsedTime;
      _elapsedTimes[_currentStepIndex] = _currentElapsed;

      emit(AlarmTimerRunInProgress(
        preparationRemainingTime: event.preparationRemainingTime,
        currentStepIndex: _currentStepIndex,
        preparationStepelapsedTime: _currentElapsed,
        progress: progress,
        preparationStepName:
            preparationSteps[_currentStepIndex].preparationName,
        preparationState: _preparationStates[_currentStepIndex],
      ));
    } else {
      _preparationStates[_currentStepIndex] = "done";
      add(const TimerStepNextShifted());
    }
  }

  void _onStepSkipped(TimerStepSkipped event, Emitter<AlarmTimerState> emit) {
    _preparationStates[_currentStepIndex] = "done"; // 건너뛰기 시 상태 변경

    _tickerSubscription?.cancel();
    _totalRemaining -= _currentRemaining;
    emit(AlarmTimerPreparationStepCompletion(_currentStepIndex));
    add(TimerStepNextShifted());
  }

  void _onStepNext(TimerStepNextShifted event, Emitter<AlarmTimerState> emit) {
    _tickerSubscription?.cancel();
    if (_currentStepIndex + 1 < preparationSteps.length) {
      _currentStepIndex++;
      _currentRemaining =
          preparationSteps[_currentStepIndex].preparationTime.inSeconds;
      _currentElapsed = 0;
      _preparationStates[_currentStepIndex] = "now";
      add(TimerStepStarted(_currentRemaining));
    } else {
      add(const TimerStepFinalized());
    }
  }

  void _onStepFinalized(
      TimerStepFinalized event, Emitter<AlarmTimerState> emit) {
    _tickerSubscription?.cancel();
    emit(const AlarmTimerPreparationCompletion());
  }

  void _startTicker(int duration) {
    _tickerSubscription?.cancel();
    _tickerSubscription = Stream.periodic(const Duration(seconds: 1), (x) => x)
        .take(duration)
        .listen((tick) {
      final int newElapsed = tick + 1;
      final int newRemaining = duration - newElapsed;
      _totalRemaining = _totalRemaining > 0 ? _totalRemaining - 1 : 0;
      add(TimerStepTicked(newRemaining, newElapsed));
    });
  }

  double get progress => _totalPreparationTime == 0
      ? 0.0
      : 1.0 - (_totalRemaining / _totalPreparationTime);

  @override
  Future<void> close() {
    _tickerSubscription?.cancel();
    return super.close();
  }
}
