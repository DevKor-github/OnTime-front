import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/services/navigation_service.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
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
  }

  final GetNearestUpcomingScheduleUseCase _getNearestUpcomingScheduleUseCase;
  final NavigationService _navigationService;
  StreamSubscription<ScheduleWithPreparationEntity?>?
      _upcomingScheduleSubscription;
  Timer? _scheduleStartTimer;
  String? _currentScheduleId;

  Future<void> _onSubscriptionRequested(
      ScheduleSubscriptionRequested event, Emitter<ScheduleState> emit) async {
    await _upcomingScheduleSubscription?.cancel();
    _upcomingScheduleSubscription =
        _getNearestUpcomingScheduleUseCase().listen((upcomingSchedule) {
      // ✅ Safety check: Only add events if bloc is still active
      if (!isClosed) {
        final scheduleWithTimePreparation = upcomingSchedule != null
            ? _convertToScheduleWithTimePreparation(upcomingSchedule)
            : null;
        add(ScheduleUpcomingReceived(scheduleWithTimePreparation));
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
    } else if (_isPreparationOnGoing(event.upcomingSchedule!)) {
      final currentStep = _findCurrentPreparationStep(
        event.upcomingSchedule!,
        DateTime.now(),
      );
      emit(ScheduleState.ongoing(event.upcomingSchedule!, currentStep));
      debugPrint(
          'ongoingSchedule: ${event.upcomingSchedule}, currentStep: $currentStep');
    } else {
      emit(ScheduleState.upcoming(event.upcomingSchedule!));
      debugPrint('upcomingSchedule: ${event.upcomingSchedule}');
      _currentScheduleId = event.upcomingSchedule!.id;
      _startScheduleTimer(event.upcomingSchedule!);
    }
  }

  Future<void> _onScheduleStarted(
      ScheduleStarted event, Emitter<ScheduleState> emit) async {
    // Only process if this event is for the current schedule
    if (state.schedule != null && state.schedule!.id == _currentScheduleId) {
      // Mark the schedule as started by updating the state
      debugPrint('scheddle started: ${state.schedule}');
      emit(ScheduleState.started(state.schedule!));
      _navigationService.push('/scheduleStart', extra: state.schedule);
    }
  }

  void _startScheduleTimer(ScheduleWithPreparationEntity schedule) {
    final now = DateTime.now();
    final preparationStartTime = schedule.preparationStartTime;

    // If the target time is in the past or now, don't set a timer
    if (preparationStartTime.isBefore(now) ||
        preparationStartTime.isAtSameMomentAs(now)) {
      return;
    }

    final duration = preparationStartTime.difference(now);

    debugPrint('duration: $duration');

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
    return super.close();
  }

  bool _isPreparationOnGoing(
      ScheduleWithPreparationEntity nearestUpcomingSchedule) {
    return nearestUpcomingSchedule.preparationStartTime
            .isBefore(DateTime.now()) &&
        nearestUpcomingSchedule.scheduleTime.isAfter(DateTime.now());
  }

  PreparationStepEntity _findCurrentPreparationStep(
      ScheduleWithPreparationEntity schedule, DateTime now) {
    final List<PreparationStepWithTime> steps = schedule
        .preparation.preparationStepList
        .cast<PreparationStepWithTime>();

    if (steps.isEmpty) {
      throw StateError('Preparation steps are empty');
    }

    final DateTime preparationStartTime = schedule.preparationStartTime;

    // If called when not in preparation window, clamp to bounds
    if (now.isBefore(preparationStartTime)) {
      return steps.first;
    }

    Duration elapsed = now.difference(preparationStartTime);

    for (final PreparationStepWithTime step in steps) {
      if (elapsed < step.preparationTime) {
        return step.copyWithElapsed(elapsed);
      }
      elapsed -= step.preparationTime;
    }

    // If elapsed exceeds total preparation duration (e.g., during move/spare time),
    // return the last preparation step as current by convention.
    return steps.last.copyWithElapsed(steps.last.preparationTime);
  }

  ScheduleWithPreparationEntity _convertToScheduleWithTimePreparation(
      ScheduleWithPreparationEntity schedule) {
    final preparationWithTime = PreparationWithTime(
      preparationStepList: schedule.preparation.preparationStepList
          .map((step) => PreparationStepWithTime(
                id: step.id,
                preparationName: step.preparationName,
                preparationTime: step.preparationTime,
                nextPreparationId: step.nextPreparationId,
              ))
          .toList(),
    );

    return ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
      schedule,
      preparationWithTime,
    );
  }
}
