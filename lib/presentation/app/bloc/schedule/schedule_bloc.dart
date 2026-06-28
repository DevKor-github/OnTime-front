import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/logging/app_logger.dart';
import 'package:on_time_front/core/services/navigation_service.dart';
import 'package:on_time_front/core/services/notification_service.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/use-cases/get_nearest_upcoming_schedule_use_case.dart';
import 'package:on_time_front/domain/use-cases/schedule_preparation_session_use_case.dart';

part 'schedule_event.dart';
part 'schedule_state.dart';

typedef NowProvider = DateTime Function();
typedef NotifyPreparationStep =
    void Function({
      required String scheduleName,
      required String preparationName,
      required String scheduleId,
      required String stepId,
    });

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
    this._schedulePreparationSessionUseCase,
  ) : _nowProvider = DateTime.now,
      _notifyPreparationStep = _defaultNotifyPreparationStep,
      super(const ScheduleState.initial()) {
    _registerHandlers();
  }

  @visibleForTesting
  ScheduleBloc.test(
    this._getNearestUpcomingScheduleUseCase,
    this._navigationService,
    this._schedulePreparationSessionUseCase, {
    NowProvider? nowProvider,
    NotifyPreparationStep? notifyPreparationStep,
  }) : _nowProvider = nowProvider ?? DateTime.now,
       _notifyPreparationStep =
           notifyPreparationStep ?? _defaultNotifyPreparationStep,
       super(const ScheduleState.initial()) {
    _registerHandlers();
  }

  void _registerHandlers() {
    on<ScheduleSubscriptionRequested>(_onSubscriptionRequested);
    on<ScheduleUpcomingReceived>(_onUpcomingReceived);
    on<ScheduleAlarmPromptRequested>(_onAlarmPromptRequested);
    on<ScheduleStarted>(_onScheduleStarted);
    on<SchedulePreparationStarted>(_onPreparationStarted);
    on<ScheduleTick>(_onTick);
    on<ScheduleStepSkipped>(_onStepSkipped);
    on<ScheduleFinished>(_onFinished);
  }

  final GetNearestUpcomingScheduleUseCase _getNearestUpcomingScheduleUseCase;
  final NavigationService _navigationService;
  final SchedulePreparationSessionUseCase _schedulePreparationSessionUseCase;
  final NowProvider _nowProvider;
  final NotifyPreparationStep _notifyPreparationStep;
  StreamSubscription<ScheduleWithPreparationEntity?>?
  _upcomingScheduleSubscription;
  Timer? _scheduleStartTimer;
  String? _currentScheduleId;
  String? _activeEarlyStartScheduleId;
  Timer? _preparationTimer;
  DateTime? _lastSnapshotSavedAt;
  bool _suppressNextCatchUpStepNotification = false;
  final Map<String, Set<String>> _notifiedStepIdsByScheduleId = {};

  Future<void> _onSubscriptionRequested(
    ScheduleSubscriptionRequested event,
    Emitter<ScheduleState> emit,
  ) async {
    await _upcomingScheduleSubscription?.cancel();

    _upcomingScheduleSubscription = _getNearestUpcomingScheduleUseCase().listen(
      (upcomingSchedule) {
        // ✅ Safety check: Only add events if bloc is still active
        if (!isClosed) {
          add(ScheduleUpcomingReceived(upcomingSchedule));
        }
      },
    );
  }

  Future<void> _onUpcomingReceived(
    ScheduleUpcomingReceived event,
    Emitter<ScheduleState> emit,
  ) async {
    if (isClosed) return;
    _scheduleStartTimer?.cancel();
    _scheduleStartTimer = null;
    final now = _nowProvider();

    if (event.upcomingSchedule == null ||
        event.upcomingSchedule!.scheduleTime.isBefore(now)) {
      final staleId = event.upcomingSchedule?.id ?? _currentScheduleId;
      if (staleId != null) {
        await _clearPersistedState(staleId);
      }
      _stopPreparationTimer();
      emit(const ScheduleState.notExists());
      _currentScheduleId = null;
      _activeEarlyStartScheduleId = null;
      _lastSnapshotSavedAt = null;
      _notifiedStepIdsByScheduleId.clear();
      return;
    }

    final incoming = event.upcomingSchedule!;
    if (_currentScheduleId != null && _currentScheduleId != incoming.id) {
      await _clearPersistedState(_currentScheduleId!);
      _notifiedStepIdsByScheduleId.remove(_currentScheduleId);
    }
    _currentScheduleId = incoming.id;

    final hasEarlyStartSession = await _hasEarlyStartSession(incoming.id);
    if (isClosed) return;

    ScheduleWithPreparationEntity resolvedSchedule;
    if (!hasEarlyStartSession && incoming.preparationStartTime.isAfter(now)) {
      // Prevent stale pre-start cache from reviving outdated progress.
      await _schedulePreparationSessionUseCase.clearPersistedState(incoming.id);
      resolvedSchedule = incoming;
    } else {
      resolvedSchedule = await _restoreFromSnapshotIfValid(incoming);
    }
    if (isClosed) return;
    _initializeNotificationTracking(resolvedSchedule);

    if (hasEarlyStartSession) {
      _activeEarlyStartScheduleId = resolvedSchedule.id;
      await _startScheduleOnServer(resolvedSchedule.id);
      if (isClosed) return;
      emit(ScheduleState.started(resolvedSchedule, isEarlyStarted: true));
      await _saveTimedPreparationSnapshot(resolvedSchedule, force: true);
      _startPreparationTimer();
      return;
    }

    _activeEarlyStartScheduleId = null;
    if (_isAtPreparationStartBoundary(resolvedSchedule, now)) {
      emit(ScheduleState.upcoming(resolvedSchedule));
      AppLogger.debug(
        'preparation boundary reached scheduleId=${resolvedSchedule.id}',
      );
      add(const ScheduleStarted());
      return;
    }

    if (_isPreparationOnGoing(resolvedSchedule, now)) {
      await _startScheduleOnServer(resolvedSchedule.id);
      if (isClosed) return;
      emit(ScheduleState.ongoing(resolvedSchedule));
      AppLogger.debug(
        'ongoing scheduleId=${resolvedSchedule.id} '
        'currentStepId=${resolvedSchedule.preparation.currentStep?.id}',
      );
      _startPreparationTimer();
      return;
    }

    _stopPreparationTimer();
    emit(ScheduleState.upcoming(resolvedSchedule));
    AppLogger.debug('upcoming scheduleId=${resolvedSchedule.id}');
    _startScheduleTimer(resolvedSchedule);
  }

  Future<void> _onScheduleStarted(
    ScheduleStarted event,
    Emitter<ScheduleState> emit,
  ) async {
    if (state.schedule != null && state.schedule!.id == _currentScheduleId) {
      if (_activeEarlyStartScheduleId == _currentScheduleId) return;
      AppLogger.debug('schedule started scheduleId=${state.schedule!.id}');
      await _startScheduleOnServer(state.schedule!.id);
      if (isClosed) return;
      emit(ScheduleState.started(state.schedule!));
      _initializeNotificationTracking(state.schedule!);
      _navigationService.push('/scheduleStart');
      _startPreparationTimer();
    }
  }

  Future<void> _onAlarmPromptRequested(
    ScheduleAlarmPromptRequested event,
    Emitter<ScheduleState> emit,
  ) async {
    AppLogger.debug(
      'alarm prompt requested: scheduleId=${event.scheduleId} '
      'startPreparation=${event.startPreparation} '
      'fingerprint=${event.scheduleFingerprint}',
    );
    final cachedSchedule = _matchingCachedAlarmSchedule(event);
    if (cachedSchedule != null) {
      await _activateAlarmPromptSchedule(
        cachedSchedule,
        event,
        emit,
        source: 'cached',
      );
      return;
    }

    final promptResult = await _schedulePreparationSessionUseCase
        .resolvePromptedSchedule(
          scheduleId: event.scheduleId,
          startPreparation: event.startPreparation,
          scheduleFingerprint: event.scheduleFingerprint,
        );
    switch (promptResult.status) {
      case SchedulePreparationPromptStatus.ready:
        await _activateAlarmPromptSchedule(
          promptResult.schedule!,
          event,
          emit,
          source: 'remote',
        );
      case SchedulePreparationPromptStatus.rejected:
        AppLogger.debug(
          'alarm prompt rejected: scheduleId=${event.scheduleId}',
        );
        _navigationService.go('/home');
      case SchedulePreparationPromptStatus.unavailable:
        AppLogger.debug(
          'alarm prompt validation unavailable: scheduleId=${event.scheduleId}',
        );
        return;
    }
  }

  ScheduleWithPreparationEntity? _matchingCachedAlarmSchedule(
    ScheduleAlarmPromptRequested event,
  ) {
    final cachedSchedule = state.schedule;
    if (cachedSchedule == null || cachedSchedule.id != event.scheduleId) {
      return null;
    }
    if (_isEnded(cachedSchedule.doneStatus)) return null;
    final fingerprint = event.scheduleFingerprint;
    if (fingerprint != null && fingerprint != cachedSchedule.cacheFingerprint) {
      if (!event.startPreparation) return null;
      AppLogger.debug(
        'alarm prompt using cached schedule despite fingerprint mismatch: '
        'scheduleId=${event.scheduleId} '
        'expected=$fingerprint actual=${cachedSchedule.cacheFingerprint}',
      );
    }
    AppLogger.debug(
      'alarm prompt using cached schedule: scheduleId=${event.scheduleId}',
    );
    return cachedSchedule;
  }

  Future<void> _activateAlarmPromptSchedule(
    ScheduleWithPreparationEntity schedule,
    ScheduleAlarmPromptRequested event,
    Emitter<ScheduleState> emit, {
    required String source,
  }) async {
    _currentScheduleId = schedule.id;
    _activeEarlyStartScheduleId = null;
    _scheduleStartTimer?.cancel();
    _scheduleStartTimer = null;
    _stopPreparationTimer();
    _initializeNotificationTracking(schedule);

    if (!event.startPreparation) {
      AppLogger.debug(
        'alarm prompt ready: scheduleId=${schedule.id} source=$source',
      );
      emit(ScheduleState.upcoming(schedule));
      _startScheduleTimer(schedule);
      return;
    }

    AppLogger.debug(
      'alarm prompt showing schedule start: scheduleId=${schedule.id} '
      'source=$source',
    );
    emit(ScheduleState.upcoming(schedule));
    _startScheduleTimer(schedule);
  }

  Future<void> _onPreparationStarted(
    SchedulePreparationStarted event,
    Emitter<ScheduleState> emit,
  ) async {
    final schedule = state.schedule;
    if (schedule == null) return;
    if (_activeEarlyStartScheduleId == schedule.id) return;

    _currentScheduleId = schedule.id;
    _activeEarlyStartScheduleId = schedule.id;
    _scheduleStartTimer?.cancel();
    _scheduleStartTimer = null;

    final startedAt = _nowProvider();
    await _schedulePreparationSessionUseCase.startEarlySession(
      schedule,
      startedAt: startedAt,
    );

    emit(ScheduleState.started(schedule, isEarlyStarted: true));
    _lastSnapshotSavedAt = startedAt;
    _startPreparationTimer();
  }

  Future<void> _onTick(ScheduleTick event, Emitter<ScheduleState> emit) async {
    if (state.schedule == null) return;
    final oldStepId = state.schedule!.preparation.currentStep?.id;
    final updatedPreparation = state.schedule!.preparation.timeElapsed(
      event.elapsed,
    );
    AppLogger.debug('elapsedTime: ${updatedPreparation.elapsedTime}');

    final newSchedule =
        ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
          state.schedule!,
          updatedPreparation,
        );

    final shouldSuppressStepNotification = _suppressNextCatchUpStepNotification;
    _suppressNextCatchUpStepNotification = false;
    if (!shouldSuppressStepNotification) {
      _checkAndNotifyStepChange(state.schedule!, newSchedule);
    }

    emit(state.copyWith(schedule: newSchedule));
    final stepChanged = oldStepId != newSchedule.preparation.currentStep?.id;
    await _saveTimedPreparationSnapshot(newSchedule, force: stepChanged);
  }

  Future<void> _onStepSkipped(
    ScheduleStepSkipped event,
    Emitter<ScheduleState> emit,
  ) async {
    if (state.schedule == null) return;
    final updated = state.schedule!.preparation.skipCurrentStep();
    final newSchedule =
        ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
          state.schedule!,
          updated,
        );
    emit(state.copyWith(schedule: newSchedule));
    await _saveTimedPreparationSnapshot(newSchedule, force: true);
  }

  Future<void> _onFinished(
    ScheduleFinished event,
    Emitter<ScheduleState> emit,
  ) async {
    if (state.schedule == null) return;
    final scheduleId = state.schedule!.id;
    try {
      await _schedulePreparationSessionUseCase.finishSchedulePreparation(
        scheduleId,
        latenessTime: event.latenessTime,
      );
      // After finishing, clear timers and set state to notExists
      _stopPreparationTimer();
      _scheduleStartTimer?.cancel();
      _currentScheduleId = null;
      _activeEarlyStartScheduleId = null;
      _lastSnapshotSavedAt = null;
      emit(const ScheduleState.notExists());
    } catch (error) {
      AppLogger.debug('error finishing schedule: $error');
    }
  }

  Future<void> _startScheduleOnServer(String scheduleId) async {
    await _schedulePreparationSessionUseCase.startSchedulePreparation(
      scheduleId,
    );
  }

  void _startScheduleTimer(ScheduleWithPreparationEntity schedule) {
    final now = _nowProvider();
    final target = schedule.preparationStartTime;
    if (!target.isAfter(now)) {
      if (!isClosed && _currentScheduleId == schedule.id) {
        add(const ScheduleStarted());
      }
      return;
    }
    final duration = target.difference(now);
    _scheduleStartTimer = Timer(duration, () {
      // Only add event if bloc is still active and schedule ID matches
      if (!isClosed && _currentScheduleId == schedule.id) {
        add(const ScheduleStarted());
      }
    });
  }

  void _startPreparationTimer() {
    if (isClosed || state.schedule == null) return;
    _preparationTimer?.cancel();
    final elapsedTimeAfterLastTick = state.isEarlyStarted
        ? Duration.zero
        : _nowProvider().difference(state.schedule!.preparationStartTime) -
              state.schedule!.preparation.elapsedTime;
    if (elapsedTimeAfterLastTick > Duration.zero) {
      AppLogger.debug('elapsedTimeAfterLastTick: $elapsedTimeAfterLastTick');
      if (!isClosed) {
        _suppressNextCatchUpStepNotification = true;
        add(ScheduleTick(elapsedTimeAfterLastTick));
      }
    }
    _preparationTimer = Timer.periodic(Duration(seconds: 1), (_) {
      if (!isClosed) add(ScheduleTick(Duration(seconds: 1)));
    });
  }

  void _stopPreparationTimer() {
    _preparationTimer?.cancel();
    _preparationTimer = null;
  }

  @override
  Future<void> close() {
    // ✅ Proper cleanup: Cancel subscription and timer before closing
    _upcomingScheduleSubscription?.cancel();
    _scheduleStartTimer?.cancel();
    _stopPreparationTimer();
    return super.close();
  }

  Future<ScheduleWithPreparationEntity> _restoreFromSnapshotIfValid(
    ScheduleWithPreparationEntity incoming,
  ) async {
    return _schedulePreparationSessionUseCase.restoreTimedPreparationIfValid(
      incoming,
      now: _nowProvider(),
    );
  }

  Future<bool> _hasEarlyStartSession(String scheduleId) async {
    return _schedulePreparationSessionUseCase.hasEarlyStartSession(scheduleId);
  }

  Future<void> _saveTimedPreparationSnapshot(
    ScheduleWithPreparationEntity schedule, {
    bool force = false,
  }) async {
    final now = _nowProvider();
    if (!force &&
        _lastSnapshotSavedAt != null &&
        now.difference(_lastSnapshotSavedAt!) < const Duration(seconds: 5)) {
      return;
    }
    await _schedulePreparationSessionUseCase.saveTimedPreparationSnapshot(
      schedule,
      savedAt: now,
    );
    _lastSnapshotSavedAt = now;
  }

  Future<void> _clearPersistedState(String scheduleId) async {
    await _schedulePreparationSessionUseCase.clearPersistedState(scheduleId);
  }

  bool _isAtPreparationStartBoundary(
    ScheduleWithPreparationEntity schedule,
    DateTime now,
  ) {
    return schedule.preparationStartTime.isAtSameMomentAs(now);
  }

  bool _isPreparationOnGoing(
    ScheduleWithPreparationEntity schedule,
    DateTime now,
  ) {
    final start = schedule.preparationStartTime;
    return start.isBefore(now) && schedule.scheduleTime.isAfter(now);
  }

  bool _isEnded(ScheduleDoneStatus doneStatus) {
    return doneStatus == ScheduleDoneStatus.normalEnd ||
        doneStatus == ScheduleDoneStatus.lateEnd ||
        doneStatus == ScheduleDoneStatus.abnormalEnd;
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

    AppLogger.debug(
      '[ScheduleBloc] preparation step notification shown '
      'scheduleId=$scheduleId stepId=${newCurrentStep.id}',
    );
  }
}
