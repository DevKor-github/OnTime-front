import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/services/navigation_service.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/use-cases/get_nearest_upcoming_schedule_use_case.dart';

part 'schedule_event.dart';
part 'schedule_state.dart';

@Singleton()
class ScheduleBloc extends Bloc<ScheduleEvent, ScheduleState> {
  ScheduleBloc(this._getNearestUpcomingScheduleUseCase, this._navigationService)
      : super(const ScheduleState.initial()) {
    on<ScheduleSubscriptionRequested>(_onSubscriptionRequested);
    on<ScheduleUpcomingReceived>(_onUpcomingReceived);
    on<ScheduleStarted>(_onScheduleStarted);
    on<ScheduleTick>(_onTick);
  }

  final GetNearestUpcomingScheduleUseCase _getNearestUpcomingScheduleUseCase;
  final NavigationService _navigationService;
  StreamSubscription<ScheduleWithPreparationEntity?>?
      _upcomingScheduleSubscription;
  Timer? _scheduleStartTimer;
  String? _currentScheduleId;
  Timer? _preparationTimer;

  Future<void> _onSubscriptionRequested(
      ScheduleSubscriptionRequested event, Emitter<ScheduleState> emit) async {
    await _upcomingScheduleSubscription?.cancel();

    _upcomingScheduleSubscription =
        _getNearestUpcomingScheduleUseCase().listen((upcomingSchedule) {
      // ✅ Safety check: Only add events if bloc is still active
      if (!isClosed) {
        add(ScheduleUpcomingReceived(upcomingSchedule));
      }
    });
  }

  Future<void> _onUpcomingReceived(
      ScheduleUpcomingReceived event, Emitter<ScheduleState> emit) async {
    // Cancel any existing timer
    _scheduleStartTimer?.cancel();
    _scheduleStartTimer = null;

    if (event.upcomingSchedule == null ||
        event.upcomingSchedule!.scheduleTime.isBefore(DateTime.now())) {
      emit(const ScheduleState.notExists());
      _currentScheduleId = null;
    } else if (_isPreparationOnGoing(
        event.upcomingSchedule!, event.preparation!)) {
      emit(ScheduleState.ongoing(event.upcomingSchedule!, event.preparation!));
      debugPrint(
          'ongoingSchedule: ${event.upcomingSchedule}, currentStep: ${event.preparation!.currentStep}');
    } else {
      emit(ScheduleState.upcoming(event.upcomingSchedule!, event.preparation!));
      debugPrint('upcomingSchedule: ${event.upcomingSchedule}');
      _currentScheduleId = event.upcomingSchedule!.id;
      _startScheduleTimer(event.upcomingSchedule!, event.preparation!);
    }
  }

  Future<void> _onScheduleStarted(
      ScheduleStarted event, Emitter<ScheduleState> emit) async {
    // Only process if this event is for the current schedule
    if (state.schedule != null && state.schedule!.id == _currentScheduleId) {
      // Mark the schedule as started by updating the state
      debugPrint('scheddle started: ${state.schedule}');
      emit(ScheduleState.started(state.schedule!, state.preparation!));
      _navigationService.push('/scheduleStart');

      _preparationTimer = Timer.periodic(Duration(seconds: 1), (_) {
        if (!isClosed) add(const ScheduleTick(Duration(seconds: 1)));
      });
    }
  }

  Future<void> _onTick(ScheduleTick event, Emitter<ScheduleState> emit) async {
    if (state.preparation == null) return;
    emit(state.copyWith(
        preparation: state.preparation!.timeElapsed(event.elapsed)));
  }

  void _startScheduleTimer(
      ScheduleEntity schedule, PreparationWithTime preparation) {
    final duration = state.durationUntilPreparationStart;
    if (duration == null) return;
    _scheduleStartTimer = Timer(duration, () {
      // Only add event if bloc is still active and schedule ID matches
      if (!isClosed && _currentScheduleId == schedule.id) {
        add(const ScheduleStarted());
      }
    });
  }

  @override
  Future<void> close() {
    // ✅ Proper cleanup: Cancel subscription and timer before closing
    _upcomingScheduleSubscription?.cancel();
    _scheduleStartTimer?.cancel();
    _preparationTimer?.cancel();
    return super.close();
  }

  bool _isPreparationOnGoing(
      ScheduleEntity schedule, PreparationWithTime preparation) {
    final totalDuration = schedule.moveTime +
        preparation.totalDuration +
        (schedule.scheduleSpareTime ?? Duration.zero);
    final preparationStartTime = schedule.scheduleTime.subtract(totalDuration);
    return preparationStartTime.isBefore(DateTime.now()) &&
        schedule.scheduleTime.isAfter(DateTime.now());
  }

  // Removed unused helper since we now split in the event
}
