import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/logging/app_logger.dart';
import 'package:on_time_front/core/services/navigation_service.dart';
import 'package:on_time_front/core/services/notification_service.dart';
import 'package:on_time_front/domain/entities/early_start_session_entity.dart';
import 'package:on_time_front/domain/entities/preparation_action_event_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_with_time_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/entities/timed_preparation_snapshot_entity.dart';
import 'package:on_time_front/domain/use-cases/cancel_schedule_alarm_use_case.dart';
import 'package:on_time_front/domain/use-cases/clear_early_start_session_use_case.dart';
import 'package:on_time_front/domain/use-cases/clear_timed_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_nearest_upcoming_schedule_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_early_start_session_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_schedule_by_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_timed_preparation_snapshot_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/mark_early_start_session_use_case.dart';
import 'package:on_time_front/domain/use-cases/save_timed_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/finish_schedule_use_case.dart';
import 'package:on_time_front/domain/use-cases/start_schedule_use_case.dart';

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
    this._saveTimedPreparationUseCase,
    this._getTimedPreparationSnapshotUseCase,
    this._clearTimedPreparationUseCase,
    this._startScheduleUseCase,
    this._finishScheduleUseCase, {
    required MarkEarlyStartSessionUseCase markEarlyStartSessionUseCase,
    required GetEarlyStartSessionUseCase getEarlyStartSessionUseCase,
    required ClearEarlyStartSessionUseCase clearEarlyStartSessionUseCase,
    required CancelScheduleAlarmUseCase cancelScheduleAlarmUseCase,
    required GetScheduleByIdUseCase getScheduleByIdUseCase,
    required LoadPreparationByScheduleIdUseCase
    loadPreparationByScheduleIdUseCase,
    required GetPreparationByScheduleIdUseCase
    getPreparationByScheduleIdUseCase,
  }) : _nowProvider = DateTime.now,
       _markEarlyStartSessionUseCase = markEarlyStartSessionUseCase,
       _getEarlyStartSessionUseCase = getEarlyStartSessionUseCase,
       _clearEarlyStartSessionUseCase = clearEarlyStartSessionUseCase,
       _cancelScheduleAlarmUseCase = cancelScheduleAlarmUseCase,
       _getScheduleByIdUseCase = getScheduleByIdUseCase,
       _loadPreparationByScheduleIdUseCase = loadPreparationByScheduleIdUseCase,
       _getPreparationByScheduleIdUseCase = getPreparationByScheduleIdUseCase,
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
    this._startScheduleUseCase,
    this._finishScheduleUseCase, {
    required MarkEarlyStartSessionUseCase markEarlyStartSessionUseCase,
    required GetEarlyStartSessionUseCase getEarlyStartSessionUseCase,
    required ClearEarlyStartSessionUseCase clearEarlyStartSessionUseCase,
    CancelScheduleAlarmUseCase? cancelScheduleAlarmUseCase,
    GetScheduleByIdUseCase? getScheduleByIdUseCase,
    LoadPreparationByScheduleIdUseCase? loadPreparationByScheduleIdUseCase,
    GetPreparationByScheduleIdUseCase? getPreparationByScheduleIdUseCase,
    NowProvider? nowProvider,
    NotifyPreparationStep? notifyPreparationStep,
  }) : _nowProvider = nowProvider ?? DateTime.now,
       _markEarlyStartSessionUseCase = markEarlyStartSessionUseCase,
       _getEarlyStartSessionUseCase = getEarlyStartSessionUseCase,
       _clearEarlyStartSessionUseCase = clearEarlyStartSessionUseCase,
       _cancelScheduleAlarmUseCase = cancelScheduleAlarmUseCase,
       _getScheduleByIdUseCase = getScheduleByIdUseCase,
       _loadPreparationByScheduleIdUseCase = loadPreparationByScheduleIdUseCase,
       _getPreparationByScheduleIdUseCase = getPreparationByScheduleIdUseCase,
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
    on<SchedulePreparationTimeRefreshRequested>(
      _onPreparationTimeRefreshRequested,
    );
    on<ScheduleStepSkipped>(_onStepSkipped);
    on<ScheduleFinished>(_onFinished);
  }

  final GetNearestUpcomingScheduleUseCase _getNearestUpcomingScheduleUseCase;
  final NavigationService _navigationService;
  final SaveTimedPreparationUseCase _saveTimedPreparationUseCase;
  final GetTimedPreparationSnapshotUseCase _getTimedPreparationSnapshotUseCase;
  final ClearTimedPreparationUseCase _clearTimedPreparationUseCase;
  final StartScheduleUseCase _startScheduleUseCase;
  final FinishScheduleUseCase _finishScheduleUseCase;
  final MarkEarlyStartSessionUseCase _markEarlyStartSessionUseCase;
  final GetEarlyStartSessionUseCase _getEarlyStartSessionUseCase;
  final ClearEarlyStartSessionUseCase _clearEarlyStartSessionUseCase;
  final CancelScheduleAlarmUseCase? _cancelScheduleAlarmUseCase;
  final GetScheduleByIdUseCase? _getScheduleByIdUseCase;
  final LoadPreparationByScheduleIdUseCase? _loadPreparationByScheduleIdUseCase;
  final GetPreparationByScheduleIdUseCase? _getPreparationByScheduleIdUseCase;
  final NowProvider _nowProvider;
  final NotifyPreparationStep _notifyPreparationStep;
  StreamSubscription<ScheduleWithPreparationEntity?>?
  _upcomingScheduleSubscription;
  Timer? _scheduleStartTimer;
  String? _currentScheduleId;
  String? _activeEarlyStartScheduleId;
  Timer? _preparationTimer;
  DateTime? _lastSnapshotSavedAt;
  DateTime? _activePreparationRunStartedAt;
  List<PreparationActionEventEntity> _activePreparationActionEvents = const [];
  bool _suppressNextCatchUpStepNotification = false;
  final Set<String> _serverStartedScheduleIds = {};
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
      _clearActivePreparationRun();
      _notifiedStepIdsByScheduleId.clear();
      return;
    }

    final incoming = event.upcomingSchedule!;
    if (_currentScheduleId != null && _currentScheduleId != incoming.id) {
      await _clearPersistedState(_currentScheduleId!);
      _notifiedStepIdsByScheduleId.remove(_currentScheduleId);
      _clearActivePreparationRun();
    }
    _currentScheduleId = incoming.id;

    final earlyStartSession = await _getEarlyStartSession(incoming.id);
    final hasEarlyStartSession = earlyStartSession != null;
    if (isClosed) return;

    ScheduleWithPreparationEntity resolvedSchedule;
    if (!hasEarlyStartSession && incoming.preparationStartTime.isAfter(now)) {
      // Prevent stale pre-start cache from reviving outdated progress.
      await _clearTimedPreparationUseCase(incoming.id);
      resolvedSchedule = incoming;
      _clearActivePreparationRun();
    } else {
      resolvedSchedule = await _restoreFromSnapshotIfValid(incoming);
    }
    if (isClosed) return;
    _initializeNotificationTracking(resolvedSchedule);

    if (hasEarlyStartSession) {
      _activeEarlyStartScheduleId = resolvedSchedule.id;
      _activePreparationRunStartedAt ??= earlyStartSession.startedAt;
      if (resolvedSchedule.preparation.elapsedTime == Duration.zero &&
          _activePreparationActionEvents.isEmpty) {
        resolvedSchedule =
            ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
              resolvedSchedule,
              _derivePreparationRun(
                resolvedSchedule.preparation,
                startedAt: _activePreparationRunStartedAt!,
                actionEvents: const [],
                now: now,
              ),
            );
      }
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
      _activePreparationRunStartedAt ??= state.schedule!.preparationStartTime;
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

    if (_getScheduleByIdUseCase == null ||
        _loadPreparationByScheduleIdUseCase == null ||
        _getPreparationByScheduleIdUseCase == null) {
      AppLogger.debug(
        'alarm prompt validation unavailable: missing schedule use cases '
        'scheduleId=${event.scheduleId}',
      );
      return;
    }
    final getScheduleByIdUseCase = _getScheduleByIdUseCase;
    final loadPreparationByScheduleIdUseCase =
        _loadPreparationByScheduleIdUseCase;
    final getPreparationByScheduleIdUseCase =
        _getPreparationByScheduleIdUseCase;

    try {
      final schedule = await getScheduleByIdUseCase(event.scheduleId);
      if (_isEnded(schedule.doneStatus)) {
        AppLogger.debug(
          'alarm prompt rejected ended schedule: scheduleId=${event.scheduleId}',
        );
        await _cancelScheduleAlarmUseCase?.call(event.scheduleId);
        _navigationService.go('/home');
        return;
      }

      await loadPreparationByScheduleIdUseCase(event.scheduleId);
      final preparation = await getPreparationByScheduleIdUseCase(
        event.scheduleId,
      );
      final scheduleWithPreparation =
          ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
            schedule,
            PreparationWithTimeEntity.fromPreparation(preparation),
          );

      if (event.scheduleFingerprint != null &&
          event.scheduleFingerprint !=
              scheduleWithPreparation.cacheFingerprint) {
        if (event.startPreparation) {
          AppLogger.debug(
            'alarm prompt continuing start despite fingerprint mismatch: '
            'scheduleId=${event.scheduleId} '
            'expected=${event.scheduleFingerprint} '
            'actual=${scheduleWithPreparation.cacheFingerprint}',
          );
        } else {
          AppLogger.debug(
            'alarm prompt rejected fingerprint mismatch: '
            'scheduleId=${event.scheduleId} '
            'expected=${event.scheduleFingerprint} '
            'actual=${scheduleWithPreparation.cacheFingerprint}',
          );
          await _cancelScheduleAlarmUseCase?.call(event.scheduleId);
          _navigationService.go('/home');
          return;
        }
      }

      await _activateAlarmPromptSchedule(
        scheduleWithPreparation,
        event,
        emit,
        source: 'remote',
      );
    } catch (error) {
      AppLogger.debug(
        'alarm prompt validation failed '
        'scheduleId=${event.scheduleId} errorType=${error.runtimeType}',
      );
      if (event.startPreparation) {
        AppLogger.debug(
          'alarm prompt start kept on current route after validation failure: '
          'scheduleId=${event.scheduleId}',
        );
        return;
      }
      await _cancelScheduleAlarmUseCase?.call(event.scheduleId);
      _navigationService.go('/home');
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
    await _markEarlyStartSessionUseCase(
      scheduleId: schedule.id,
      startedAt: startedAt,
    );
    await _startScheduleOnServer(schedule.id);
    await _cancelScheduleAlarmUseCase?.call(schedule.id);

    _activePreparationRunStartedAt = startedAt;
    _activePreparationActionEvents = const [];
    emit(ScheduleState.started(schedule, isEarlyStarted: true));
    await _saveTimedPreparationSnapshot(schedule, force: true);
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

  Future<void> _onPreparationTimeRefreshRequested(
    SchedulePreparationTimeRefreshRequested event,
    Emitter<ScheduleState> emit,
  ) async {
    if (state.schedule == null) return;
    if (state.schedule!.preparation.isAllStepsDone) return;
    final startedAt = _activePreparationRunStartedAt;
    if (startedAt == null) return;

    final refreshedPreparation = _derivePreparationRun(
      state.schedule!.preparation,
      startedAt: startedAt,
      actionEvents: _activePreparationActionEvents,
      now: _nowProvider(),
    );
    final refreshedSchedule =
        ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
          state.schedule!,
          refreshedPreparation,
        );
    emit(state.copyWith(schedule: refreshedSchedule));
    await _saveTimedPreparationSnapshot(refreshedSchedule);
  }

  Future<void> _onStepSkipped(
    ScheduleStepSkipped event,
    Emitter<ScheduleState> emit,
  ) async {
    if (state.schedule == null) return;
    if (state.schedule!.preparation.isAllStepsDone) return;
    final now = _nowProvider();
    _activePreparationRunStartedAt ??= state.isEarlyStarted
        ? now.subtract(state.schedule!.preparation.elapsedTime)
        : state.schedule!.preparationStartTime;
    final currentPreparation = _derivePreparationRun(
      state.schedule!.preparation,
      startedAt: _activePreparationRunStartedAt!,
      actionEvents: _activePreparationActionEvents,
      now: now,
    );
    final currentStep = currentPreparation.currentStep;
    if (currentStep == null) return;
    final skipEvent = PreparationActionEventEntity.skipStep(
      stepId: currentStep.id,
      occurredAt: now,
    );
    _activePreparationActionEvents = [
      ..._activePreparationActionEvents,
      skipEvent,
    ];
    final updated = _skipCurrentStepForEvent(currentPreparation, skipEvent);
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
      await _finishScheduleUseCase(scheduleId, event.latenessTime);
      // After finishing, clear timers and set state to notExists
      _stopPreparationTimer();
      _scheduleStartTimer?.cancel();
      await _clearPersistedState(scheduleId);
      _currentScheduleId = null;
      _activeEarlyStartScheduleId = null;
      _lastSnapshotSavedAt = null;
      _clearActivePreparationRun();
      _serverStartedScheduleIds.remove(scheduleId);
      emit(const ScheduleState.notExists());
    } catch (error) {
      AppLogger.debug('error finishing schedule: $error');
    }
  }

  Future<void> _startScheduleOnServer(String scheduleId) async {
    if (_serverStartedScheduleIds.contains(scheduleId)) return;
    await _startScheduleUseCase(scheduleId);
    _serverStartedScheduleIds.add(scheduleId);
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
    _activePreparationRunStartedAt ??= state.isEarlyStarted
        ? _nowProvider().subtract(state.schedule!.preparation.elapsedTime)
        : state.schedule!.preparationStartTime;
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
      if (!isClosed) add(const SchedulePreparationTimeRefreshRequested());
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
    final snapshot = await _getTimedPreparationSnapshotUseCase(incoming.id);
    if (snapshot == null) {
      return incoming;
    }
    if (snapshot.scheduleFingerprint != incoming.cacheFingerprint) {
      await _clearPersistedState(incoming.id);
      return incoming;
    }

    final startedAt = snapshot.startedAt;
    _activePreparationRunStartedAt = startedAt;
    _activePreparationActionEvents = snapshot.actionEvents;
    final restoredPreparation = startedAt == null
        ? _restoreElapsedSnapshot(snapshot)
        : _derivePreparationRun(
            incoming.preparation,
            startedAt: startedAt,
            actionEvents: snapshot.actionEvents,
            now: _nowProvider(),
          );

    return ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
      incoming,
      restoredPreparation,
    );
  }

  PreparationWithTimeEntity _restoreElapsedSnapshot(
    TimedPreparationSnapshotEntity snapshot,
  ) {
    final elapsedSinceSave = _nowProvider().difference(snapshot.savedAt);
    return elapsedSinceSave.isNegative
        ? snapshot.preparation
        : snapshot.preparation.timeElapsed(elapsedSinceSave);
  }

  PreparationWithTimeEntity _derivePreparationRun(
    PreparationWithTimeEntity source, {
    required DateTime startedAt,
    required List<PreparationActionEventEntity> actionEvents,
    required DateTime now,
  }) {
    var preparation = _resetPreparationProgress(source);
    var cursor = startedAt;
    final orderedEvents =
        actionEvents.where((event) => !event.occurredAt.isAfter(now)).toList()
          ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

    for (final event in orderedEvents) {
      if (event.occurredAt.isAfter(cursor)) {
        preparation = preparation.timeElapsed(
          event.occurredAt.difference(cursor),
        );
        cursor = event.occurredAt;
      }

      switch (event.type) {
        case PreparationActionEventType.start:
          cursor = event.occurredAt;
        case PreparationActionEventType.skipStep:
          preparation = _skipCurrentStepForEvent(preparation, event);
          cursor = event.occurredAt;
        case PreparationActionEventType.finish:
          return preparation.timeElapsed(now.difference(cursor));
      }
    }

    if (now.isAfter(cursor)) {
      preparation = preparation.timeElapsed(now.difference(cursor));
    }
    return preparation;
  }

  PreparationWithTimeEntity _resetPreparationProgress(
    PreparationWithTimeEntity source,
  ) {
    return PreparationWithTimeEntity(
      preparationStepList: [
        for (final step in source.preparationStepList)
          PreparationStepWithTimeEntity(
            id: step.id,
            preparationName: step.preparationName,
            preparationTime: step.preparationTime,
            nextPreparationId: step.nextPreparationId,
          ),
      ],
    );
  }

  PreparationWithTimeEntity _skipCurrentStepForEvent(
    PreparationWithTimeEntity preparation,
    PreparationActionEventEntity event,
  ) {
    final current = preparation.currentStep;
    if (current == null || current.id != event.stepId) {
      return preparation;
    }
    return preparation.copyWith(
      preparationStepList: [
        for (final step in preparation.preparationStepList)
          step.id == current.id ? step.copyWith(isDone: true) : step,
      ],
    );
  }

  Future<EarlyStartSessionEntity?> _getEarlyStartSession(String scheduleId) {
    return _getEarlyStartSessionUseCase(scheduleId);
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
      startedAt: _activePreparationRunStartedAt,
      actionEvents: _activePreparationActionEvents,
    );
    _lastSnapshotSavedAt = now;
  }

  Future<void> _clearPersistedState(String scheduleId) async {
    await _clearTimedPreparationUseCase(scheduleId);
    await _clearEarlyStartSessionUseCase(scheduleId);
  }

  void _clearActivePreparationRun() {
    _activePreparationRunStartedAt = null;
    _activePreparationActionEvents = const [];
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
