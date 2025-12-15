import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/services/navigation_service.dart';
import 'package:on_time_front/core/services/notification_service.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/use-cases/get_nearest_upcoming_schedule_use_case.dart';
import 'package:on_time_front/domain/use-cases/save_timed_preparation_use_case.dart';

part 'schedule_event.dart';
part 'schedule_state.dart';

@Singleton()
class ScheduleBloc extends Bloc<ScheduleEvent, ScheduleState> {
  ScheduleBloc(this._getNearestUpcomingScheduleUseCase, this._navigationService,
      this._saveTimedPreparationUseCase)
      : super(const ScheduleState.initial()) {
    on<ScheduleSubscriptionRequested>(_onSubscriptionRequested);
    on<ScheduleUpcomingReceived>(_onUpcomingReceived);
    on<ScheduleStarted>(_onScheduleStarted);
    on<ScheduleTick>(_onTick);
    on<ScheduleStepSkipped>(_onStepSkipped);
  }

  final GetNearestUpcomingScheduleUseCase _getNearestUpcomingScheduleUseCase;
  final NavigationService _navigationService;
  final SaveTimedPreparationUseCase _saveTimedPreparationUseCase;
  StreamSubscription<ScheduleWithPreparationEntity?>?
      _upcomingScheduleSubscription;
  Timer? _scheduleStartTimer;
  String? _currentScheduleId;
  Timer? _preparationTimer;
  final Map<String, Set<String>> _notifiedStepIdsByScheduleId = {};

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
      _notifiedStepIdsByScheduleId.clear();
    } else if (_isPreparationOnGoing(event.upcomingSchedule!)) {
      emit(ScheduleState.ongoing(event.upcomingSchedule!));
      debugPrint(
          'ongoingSchedule: ${event.upcomingSchedule}, currentStep: ${event.upcomingSchedule!.preparation.currentStep}');
      _initializeNotificationTracking(event.upcomingSchedule!);
      _startPreparationTimer();
    } else {
      emit(ScheduleState.upcoming(event.upcomingSchedule!));
      debugPrint('upcomingSchedule: ${event.upcomingSchedule}');
      _currentScheduleId = event.upcomingSchedule!.id;
      _initializeNotificationTracking(event.upcomingSchedule!);
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
      _initializeNotificationTracking(state.schedule!);
      _navigationService.push('/scheduleStart');
      _startPreparationTimer();
    }
  }

  Future<void> _onTick(ScheduleTick event, Emitter<ScheduleState> emit) async {
    if (state.schedule == null) return;
    final updatedPreparation =
        state.schedule!.preparation.timeElapsed(event.elapsed);
    debugPrint('elapsedTime: ${updatedPreparation.elapsedTime}');

    final newSchedule =
        ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
            state.schedule!, updatedPreparation);

    _checkAndNotifyStepChange(state.schedule!, newSchedule);

    emit(state.copyWith(schedule: newSchedule));
  }

  Future<void> _onStepSkipped(
      ScheduleStepSkipped event, Emitter<ScheduleState> emit) async {
    if (state.schedule == null) return;
    final updated = state.schedule!.preparation.skipCurrentStep();
    emit(state.copyWith(
        schedule:
            ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
                state.schedule!, updated)));
    await _saveTimedPreparationUseCase(state.schedule!.id, updated);
  }

  void _startScheduleTimer(ScheduleWithPreparationEntity schedule) {
    final duration = state.durationUntilPreparationStart;
    if (duration == null) return;
    _scheduleStartTimer = Timer(duration, () {
      // Only add event if bloc is still active and schedule ID matches
      if (!isClosed && _currentScheduleId == schedule.id) {
        add(const ScheduleStarted());
      }
    });
  }

  void _startPreparationTimer() {
    if (state.schedule == null) return;
    _preparationTimer?.cancel();
    final elapsedTimeAfterLastTick =
        DateTime.now().difference(state.schedule!.preparationStartTime) -
            state.schedule!.preparation.elapsedTime;
    debugPrint('elapsedTimeAfterLastTick: $elapsedTimeAfterLastTick');
    add(ScheduleTick(elapsedTimeAfterLastTick));
    _preparationTimer = Timer.periodic(Duration(seconds: 1), (_) {
      if (!isClosed) add(ScheduleTick(Duration(seconds: 1)));
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

  bool _isPreparationOnGoing(ScheduleWithPreparationEntity schedule) {
    final start = schedule.preparationStartTime;
    return start.isBefore(DateTime.now()) &&
        schedule.scheduleTime.isAfter(DateTime.now());
  }

  void _initializeNotificationTracking(ScheduleWithPreparationEntity schedule) {
    final scheduleId = schedule.id;
    if (!_notifiedStepIdsByScheduleId.containsKey(scheduleId)) {
      _notifiedStepIdsByScheduleId[scheduleId] = {};
    }
  }

  void _checkAndNotifyStepChange(
    ScheduleWithPreparationEntity oldSchedule,
    ScheduleWithPreparationEntity newSchedule,
  ) {
    if (newSchedule.preparation.isAllStepsDone) {
      return;
    }

    final scheduleId = newSchedule.id;
    final oldCurrentStep = oldSchedule.preparation.currentStep;
    final newCurrentStep = newSchedule.preparation.currentStep;

    if (oldCurrentStep?.id == newCurrentStep?.id || newCurrentStep == null) {
      return;
    }

    final lastStep = newSchedule.preparation.preparationStepList.isNotEmpty
        ? newSchedule.preparation.preparationStepList.last
        : null;
    if (lastStep != null && newCurrentStep.id == lastStep.id) {
      return;
    }

    final firstStep = newSchedule.preparation.preparationStepList.isNotEmpty
        ? newSchedule.preparation.preparationStepList.first
        : null;
    if (firstStep != null && newCurrentStep.id == firstStep.id) {
      return;
    }

    final notifiedStepIds = _notifiedStepIdsByScheduleId[scheduleId] ?? {};
    if (notifiedStepIds.contains(newCurrentStep.id)) {
      return;
    }

    final title =
        '[${newSchedule.scheduleName}] ${newCurrentStep.preparationName}';
    const body = '이어서 준비하세요.';

    NotificationService.instance.showLocalNotification(
      title: title,
      body: body,
      payload: {
        'type': 'preparation_step',
        'scheduleId': scheduleId,
        'stepId': newCurrentStep.id,
      },
    );

    notifiedStepIds.add(newCurrentStep.id);
    _notifiedStepIdsByScheduleId[scheduleId] = notifiedStepIds;

    debugPrint(
        '[ScheduleBloc] 단계 변경 알림 표시: $title, stepId: ${newCurrentStep.id}');
  }
}
