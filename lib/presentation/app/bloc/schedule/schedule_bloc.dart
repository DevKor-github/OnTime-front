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
import 'package:on_time_front/domain/use-cases/finish_schedule_use_case.dart';

part 'schedule_event.dart';
part 'schedule_state.dart';

void _defaultNotifyPreparationStep({
  required String scheduleName,
  required String preparationName,
  required String scheduleId,
  required String stepId,
}) {
  NotificationService.instance.showPreparationStepNotification(
    scheduleName: scheduleName,
    preparationName: preparationName,
    scheduleId: scheduleId,
    stepId: stepId,
  );
}

@Singleton()
class ScheduleBloc extends Bloc<ScheduleEvent, ScheduleState> {
  ScheduleBloc(
    this._getNearestUpcomingScheduleUseCase,
    this._navigationService,
    this._saveTimedPreparationUseCase,
    this._finishScheduleUseCase, {
    DateTime Function()? nowProvider,
    void Function({
      required String scheduleName,
      required String preparationName,
      required String scheduleId,
      required String stepId,
    })? notifyPreparationStep,
  })  : _nowProvider = nowProvider ?? DateTime.now,
        _notifyPreparationStep =
            notifyPreparationStep ?? _defaultNotifyPreparationStep,
        super(const ScheduleState.initial()) {
    on<ScheduleSubscriptionRequested>(_onSubscriptionRequested);
    on<ScheduleUpcomingReceived>(_onUpcomingReceived);
    on<ScheduleStarted>(_onScheduleStarted);
    on<ScheduleTick>(_onTick);
    on<ScheduleStepSkipped>(_onStepSkipped);
    on<ScheduleFinished>(_onFinished);
  }

  final GetNearestUpcomingScheduleUseCase _getNearestUpcomingScheduleUseCase;
  final NavigationService _navigationService;
  final SaveTimedPreparationUseCase _saveTimedPreparationUseCase;
  final FinishScheduleUseCase _finishScheduleUseCase;
  final DateTime Function() _nowProvider;
  final void Function({
    required String scheduleName,
    required String preparationName,
    required String scheduleId,
    required String stepId,
  }) _notifyPreparationStep;
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
        event.upcomingSchedule!.scheduleTime.isBefore(_nowProvider())) {
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

  Future<void> _onFinished(
      ScheduleFinished event, Emitter<ScheduleState> emit) async {
    if (state.schedule == null) return;
    final scheduleId = state.schedule!.id;
    try {
      await _finishScheduleUseCase(scheduleId, event.latenessTime);
      // After finishing, clear timers and set state to notExists
      _preparationTimer?.cancel();
      _scheduleStartTimer?.cancel();
      emit(const ScheduleState.notExists());
    } catch (_) {
      debugPrint('error finishing schedule: $_');
    }
  }

  void _startScheduleTimer(ScheduleWithPreparationEntity schedule) {
    final now = _nowProvider();
    final target = schedule.preparationStartTime;
    if (!target.isAfter(now)) return;
    final duration = target.difference(now);
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
        _nowProvider().difference(state.schedule!.preparationStartTime) -
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
    final now = _nowProvider();
    return start.isBefore(now) && schedule.scheduleTime.isAfter(now);
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

    _notifyPreparationStep(
      scheduleName: newSchedule.scheduleName,
      preparationName: newCurrentStep.preparationName,
      scheduleId: scheduleId,
      stepId: newCurrentStep.id,
    );

    notifiedStepIds.add(newCurrentStep.id);
    _notifiedStepIdsByScheduleId[scheduleId] = notifiedStepIds;

    debugPrint(
        '[ScheduleBloc] 단계 변경 알림 표시: [${newSchedule.scheduleName}] ${newCurrentStep.preparationName}, stepId: ${newCurrentStep.id}');
  }
}
