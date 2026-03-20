import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/services/navigation_service.dart';
import 'package:on_time_front/core/services/notification_service.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/use-cases/clear_early_start_session_use_case.dart';
import 'package:on_time_front/domain/use-cases/clear_timed_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_nearest_upcoming_schedule_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_early_start_session_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_timed_preparation_snapshot_use_case.dart';
import 'package:on_time_front/domain/use-cases/mark_early_start_session_use_case.dart';
import 'package:on_time_front/domain/use-cases/save_timed_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/finish_schedule_use_case.dart';

part 'schedule_event.dart';
part 'schedule_state.dart';

typedef NowProvider = DateTime Function();
typedef NotifyPreparationStep = void Function({
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
    this._saveTimedPreparationUseCase,
    this._getTimedPreparationSnapshotUseCase,
    this._clearTimedPreparationUseCase,
    this._finishScheduleUseCase, {
    required MarkEarlyStartSessionUseCase markEarlyStartSessionUseCase,
    required GetEarlyStartSessionUseCase getEarlyStartSessionUseCase,
    required ClearEarlyStartSessionUseCase clearEarlyStartSessionUseCase,
  })  : _nowProvider = DateTime.now,
        _markEarlyStartSessionUseCase = markEarlyStartSessionUseCase,
        _getEarlyStartSessionUseCase = getEarlyStartSessionUseCase,
        _clearEarlyStartSessionUseCase = clearEarlyStartSessionUseCase,
        _notifyPreparationStep = _defaultNotifyPreparationStep,
        super(const ScheduleState.initial()) {
    _registerHandlers();
  }

  @visibleForTesting
  ScheduleBloc.test(
    this._getNearestUpcomingScheduleUseCase,
    this._navigationService,
    this._saveTimedPreparationUseCase,
    this._getTimedPreparationSnapshotUseCase,
    this._clearTimedPreparationUseCase,
    this._finishScheduleUseCase, {
    required MarkEarlyStartSessionUseCase markEarlyStartSessionUseCase,
    required GetEarlyStartSessionUseCase getEarlyStartSessionUseCase,
    required ClearEarlyStartSessionUseCase clearEarlyStartSessionUseCase,
    NowProvider? nowProvider,
    NotifyPreparationStep? notifyPreparationStep,
  })  : _nowProvider = nowProvider ?? DateTime.now,
        _markEarlyStartSessionUseCase = markEarlyStartSessionUseCase,
        _getEarlyStartSessionUseCase = getEarlyStartSessionUseCase,
        _clearEarlyStartSessionUseCase = clearEarlyStartSessionUseCase,
        _notifyPreparationStep =
            notifyPreparationStep ?? _defaultNotifyPreparationStep,
        super(const ScheduleState.initial()) {
    _registerHandlers();
  }

  void _registerHandlers() {
    on<ScheduleSubscriptionRequested>(_onSubscriptionRequested);
    on<ScheduleUpcomingReceived>(_onUpcomingReceived);
    on<ScheduleStarted>(_onScheduleStarted);
    on<SchedulePreparationStarted>(_onPreparationStarted);
    on<ScheduleTick>(_onTick);
    on<ScheduleStepSkipped>(_onStepSkipped);
    on<ScheduleFinished>(_onFinished);
  }

  final GetNearestUpcomingScheduleUseCase _getNearestUpcomingScheduleUseCase;
  final NavigationService _navigationService;
  final SaveTimedPreparationUseCase _saveTimedPreparationUseCase;
  final GetTimedPreparationSnapshotUseCase _getTimedPreparationSnapshotUseCase;
  final ClearTimedPreparationUseCase _clearTimedPreparationUseCase;
  final FinishScheduleUseCase _finishScheduleUseCase;
  final MarkEarlyStartSessionUseCase _markEarlyStartSessionUseCase;
  final GetEarlyStartSessionUseCase _getEarlyStartSessionUseCase;
  final ClearEarlyStartSessionUseCase _clearEarlyStartSessionUseCase;
  final NowProvider _nowProvider;
  final NotifyPreparationStep _notifyPreparationStep;
  StreamSubscription<ScheduleWithPreparationEntity?>?
      _upcomingScheduleSubscription;
  Timer? _scheduleStartTimer;
  String? _currentScheduleId;
  String? _activeEarlyStartScheduleId;
  Timer? _preparationTimer;
  DateTime? _lastSnapshotSavedAt;
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
      await _clearTimedPreparationUseCase(incoming.id);
      resolvedSchedule = incoming;
    } else {
      resolvedSchedule = await _restoreFromSnapshotIfValid(incoming);
    }
    if (isClosed) return;
    _initializeNotificationTracking(resolvedSchedule);

    if (hasEarlyStartSession) {
      _activeEarlyStartScheduleId = resolvedSchedule.id;
      emit(ScheduleState.started(resolvedSchedule, isEarlyStarted: true));
      await _saveTimedPreparationSnapshot(resolvedSchedule, force: true);
      _startPreparationTimer();
      return;
    }

    _activeEarlyStartScheduleId = null;
    if (_isPreparationOnGoing(resolvedSchedule)) {
      emit(ScheduleState.ongoing(resolvedSchedule));
      debugPrint(
          'ongoingSchedule: $resolvedSchedule, currentStep: ${resolvedSchedule.preparation.currentStep}');
      _startPreparationTimer();
    } else {
      emit(ScheduleState.upcoming(resolvedSchedule));
      debugPrint('upcomingSchedule: $resolvedSchedule');
      _startScheduleTimer(resolvedSchedule);
    }
  }

  Future<void> _onScheduleStarted(
      ScheduleStarted event, Emitter<ScheduleState> emit) async {
    if (state.schedule != null && state.schedule!.id == _currentScheduleId) {
      if (_activeEarlyStartScheduleId == _currentScheduleId) return;
      debugPrint('scheddle started: ${state.schedule}');
      emit(ScheduleState.started(state.schedule!));
      _initializeNotificationTracking(state.schedule!);
      _navigationService.push('/scheduleStart');
      _startPreparationTimer();
    }
  }

  Future<void> _onPreparationStarted(
      SchedulePreparationStarted event, Emitter<ScheduleState> emit) async {
    final schedule = state.schedule;
    if (schedule == null) return;
    if (_activeEarlyStartScheduleId == schedule.id) return;

    _currentScheduleId = schedule.id;
    _activeEarlyStartScheduleId = schedule.id;
    _scheduleStartTimer?.cancel();
    _scheduleStartTimer = null;

    await _markEarlyStartSessionUseCase(
      scheduleId: schedule.id,
      startedAt: _nowProvider(),
    );

    emit(ScheduleState.started(schedule, isEarlyStarted: true));
    await _saveTimedPreparationSnapshot(schedule, force: true);
    _startPreparationTimer();
  }

  Future<void> _onTick(ScheduleTick event, Emitter<ScheduleState> emit) async {
    if (state.schedule == null) return;
    final oldStepId = state.schedule!.preparation.currentStep?.id;
    final updatedPreparation =
        state.schedule!.preparation.timeElapsed(event.elapsed);
    debugPrint('elapsedTime: ${updatedPreparation.elapsedTime}');

    final newSchedule =
        ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
            state.schedule!, updatedPreparation);

    _checkAndNotifyStepChange(state.schedule!, newSchedule);

    emit(state.copyWith(schedule: newSchedule));
    final stepChanged = oldStepId != newSchedule.preparation.currentStep?.id;
    await _saveTimedPreparationSnapshot(newSchedule, force: stepChanged);
  }

  Future<void> _onStepSkipped(
      ScheduleStepSkipped event, Emitter<ScheduleState> emit) async {
    if (state.schedule == null) return;
    final updated = state.schedule!.preparation.skipCurrentStep();
    final newSchedule =
        ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
            state.schedule!, updated);
    emit(state.copyWith(schedule: newSchedule));
    await _saveTimedPreparationSnapshot(newSchedule, force: true);
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
      await _clearPersistedState(scheduleId);
      _currentScheduleId = null;
      _activeEarlyStartScheduleId = null;
      _lastSnapshotSavedAt = null;
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
    if (isClosed || state.schedule == null) return;
    _preparationTimer?.cancel();
    final elapsedTimeAfterLastTick = state.isEarlyStarted
        ? Duration.zero
        : _nowProvider().difference(state.schedule!.preparationStartTime) -
            state.schedule!.preparation.elapsedTime;
    if (elapsedTimeAfterLastTick > Duration.zero) {
      debugPrint('elapsedTimeAfterLastTick: $elapsedTimeAfterLastTick');
      if (!isClosed) {
        add(ScheduleTick(elapsedTimeAfterLastTick));
      }
    }
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

  Future<ScheduleWithPreparationEntity> _restoreFromSnapshotIfValid(
    ScheduleWithPreparationEntity incoming,
  ) async {
    final snapshot = await _getTimedPreparationSnapshotUseCase(incoming.id);
    if (snapshot == null) {
      return incoming;
    }
    if (snapshot.scheduleFingerprint != incoming.cacheFingerprint) {
      await _clearPersistedState(incoming.id);
      return incoming;
    }

    final elapsedSinceSave = _nowProvider().difference(snapshot.savedAt);
    final restoredPreparation = elapsedSinceSave.isNegative
        ? snapshot.preparation
        : snapshot.preparation.timeElapsed(elapsedSinceSave);

    return ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
      incoming,
      restoredPreparation,
    );
  }

  Future<bool> _hasEarlyStartSession(String scheduleId) async {
    final session = await _getEarlyStartSessionUseCase(scheduleId);
    return session != null;
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
    await _saveTimedPreparationUseCase(
      schedule,
      schedule.preparation,
      savedAt: now,
    );
    _lastSnapshotSavedAt = now;
  }

  Future<void> _clearPersistedState(String scheduleId) async {
    await _clearTimedPreparationUseCase(scheduleId);
    await _clearEarlyStartSessionUseCase(scheduleId);
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
