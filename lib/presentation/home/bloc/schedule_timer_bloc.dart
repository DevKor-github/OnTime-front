library;

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

part 'schedule_timer_event.dart';
part 'schedule_timer_state.dart';

class ScheduleTimerBloc extends Bloc<ScheduleTimerEvent, ScheduleTimerState> {
  StreamSubscription<DateTime>? _tickerSubscription;
  Timer? _initialTimer;
  DateTime? _scheduleTime;

  ScheduleTimerBloc() : super(const ScheduleTimerInitial()) {
    on<ScheduleTimerStarted>(_onTimerStarted);
    on<ScheduleTimerTicked>(_onTimerTicked);
    on<ScheduleTimerStopped>(_onTimerStopped);
    on<ScheduleTimerUpdated>(_onTimerUpdated);
  }

  @override
  Future<void> close() {
    _tickerSubscription?.cancel();
    _initialTimer?.cancel();
    return super.close();
  }

  void _onTimerStarted(
      ScheduleTimerStarted event, Emitter<ScheduleTimerState> emit) {
    _scheduleTime = event.scheduleTime;
    _tickerSubscription?.cancel();
    _initialTimer?.cancel();

    // Calculate initial time difference
    final now = DateTime.now();
    final difference = event.scheduleTime.difference(now);

    if (difference.inSeconds <= 0) {
      emit(ScheduleTimerFinished(scheduleTime: event.scheduleTime));
      return;
    }

    emit(ScheduleTimerRunning(
      scheduleTime: event.scheduleTime,
      currentTime: now,
      remainingDuration: difference,
    ));

    // Calculate time until next minute boundary (when seconds = 0)
    final secondsUntilNextMinute = 60 - now.second;

    // Create an initial timer to sync with minute boundaries
    _initialTimer = Timer(Duration(seconds: secondsUntilNextMinute), () {
      // Check if bloc is still active before adding events
      if (isClosed) return;

      // After the initial sync, start the regular minute timer
      add(ScheduleTimerTicked(DateTime.now()));

      // Now create a periodic timer that runs exactly every minute
      _tickerSubscription = Stream.periodic(
        const Duration(minutes: 1),
        (_) => DateTime.now(),
      ).listen((currentTime) {
        // Check if bloc is still active before adding events
        if (!isClosed) {
          add(ScheduleTimerTicked(currentTime));
        }
      });
    });
  }

  void _onTimerTicked(
      ScheduleTimerTicked event, Emitter<ScheduleTimerState> emit) {
    if (_scheduleTime == null) return;

    final difference = _scheduleTime!.difference(event.currentTime);

    if (difference.inSeconds <= 0) {
      emit(ScheduleTimerFinished(scheduleTime: _scheduleTime!));
      _tickerSubscription?.cancel();
    } else {
      emit(ScheduleTimerRunning(
        scheduleTime: _scheduleTime!,
        currentTime: event.currentTime,
        remainingDuration: difference,
      ));
    }
  }

  void _onTimerStopped(
      ScheduleTimerStopped event, Emitter<ScheduleTimerState> emit) {
    _tickerSubscription?.cancel();
    _initialTimer?.cancel();
    _scheduleTime = null;
    emit(const ScheduleTimerInitial());
  }

  void _onTimerUpdated(
      ScheduleTimerUpdated event, Emitter<ScheduleTimerState> emit) {
    if (event.scheduleTime == null) {
      _tickerSubscription?.cancel();
      _initialTimer?.cancel();
      _scheduleTime = null;
      emit(const ScheduleTimerInitial());
    } else {
      add(ScheduleTimerStarted(event.scheduleTime!));
    }
  }
}
