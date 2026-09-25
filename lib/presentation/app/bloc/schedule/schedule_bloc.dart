import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
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
import 'package:on_time_front/domain/use-cases/get_nearest_upcoming_schedule_use_case.dart';
import 'package:on_time_front/domain/use-cases/schedule_preparation_session_use_case.dart';

part 'schedule_event.dart';
part 'schedule_state.dart';

typedef NowProvider = DateTime Function();
typedef NotifyPreparationStep =
    FutureOr<void> Function({
      required String scheduleName,
      required String preparationName,
      required String scheduleId,
      required String stepId,
      required bool Function() isCurrent,
    });

Future<void> _defaultNotifyPreparationStep({
  required String scheduleName,
  required String preparationName,
  required String scheduleId,
  required String stepId,
  required bool Function() isCurrent,
}) {
  return NotificationService.instance.showPreparationStepNotification(
    scheduleName: scheduleName,
    preparationName: preparationName,
    scheduleId: scheduleId,
    stepId: stepId,
    isCurrent: isCurrent,
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
    Duration Function()? monotonicNow,
    AppLifecycleState? Function()? lifecycleState,
  }) : _nowProvider = nowProvider ?? DateTime.now,
       _notifyPreparationStep =
           notifyPreparationStep ?? _defaultNotifyPreparationStep,
       super(const ScheduleState.initial()) {
    _monotonicOverride = monotonicNow;
    _lifecycleOverride = lifecycleState;
    _registerHandlers();
  }

  void _registerHandlers() {
    on<_NotificationPromptPresented>((event, emit) {
      if (!identical(_notificationPromptOwner, event.owner) ||
          !event.isCurrent()) {
        return;
      }
      _scheduleStartTimer?.cancel();
      _scheduleStartTimer = null;
      _stopPreparationTimer();
      _activeEarlyStartScheduleId = null;
      _currentScheduleId = event.schedule.id;
      _clearActivePreparationRun();
      _snapshotInvalidated = true;
      emit(
        ScheduleState.upcoming(
          event.schedule,
          notificationPromptOwner: event.owner,
        ),
      );
    });
    on<ScheduleSubscriptionRequested>(_onSubscriptionRequested);
    on<ScheduleUpcomingReceived>(_onUpcomingReceived);
    on<ScheduleAlarmPromptRequested>(_onAlarmPromptRequested);
    on<ScheduleStarted>(_onScheduleStarted);
    on<SchedulePreparationStarted>(_onPreparationStarted);
    on<SchedulePreparationRecoveryRequested>(_onStartRecovery);
    on<ScheduleTick>(_onTick);
    on<SchedulePreparationTimeRefreshRequested>(
      _onPreparationTimeRefreshRequested,
    );
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
  Object? _explicitStartPending;
  bool _finishing = false;
  Timer? _preparationTimer;
  DateTime? _lastSnapshotSavedAt;
  DateTime? _activePreparationRunStartedAt;
  List<PreparationActionEventEntity> _activePreparationActionEvents = const [];
  // One delayed 1-second tick is tolerated; longer gaps are silent catch-up.
  static const stepNotificationFreshness = Duration(seconds: 2);
  // Normal wall/monotonic reads differ by tiny scheduling jitter. A 250 ms
  // discontinuity is conservatively treated as a clock adjustment, not delivery.
  static const stepClockTolerance = Duration(milliseconds: 250);
  final Stopwatch _monotonicClock = Stopwatch()..start();
  Duration Function()? _monotonicOverride;
  AppLifecycleState? Function()? _lifecycleOverride;
  Duration get _monotonicNow =>
      _monotonicOverride?.call() ?? _monotonicClock.elapsed;
  AppLifecycleState? get _lifecycle => _lifecycleOverride == null
      ? WidgetsBinding.instance.lifecycleState
      : _lifecycleOverride!();
  (Duration, DateTime, AppLifecycleState?)? _stepObservation;
  int _stepRevision = 0;
  (int, String, DateTime)? _stepRun;
  final Set<String> _attemptedSteps = {};

  /// Called synchronously for every phase so paused -> inactive -> paused
  /// between two timer callbacks cannot masquerade as continuous background.
  void observeLifecycleState(AppLifecycleState phase) {
    _stepObservation = null;
    _stepRevision++;
  }

  Object? _notificationPreparationOwner;
  Object? _notificationPreparationViewOwner;
  Object? get notificationPreparationOwner =>
      notificationPreparationId == null ? null : _notificationPreparationOwner;
  String? _notificationPreparationId;
  int? _notificationPreparationGeneration;
  String? get notificationPreparationId =>
      _notificationPreparationGeneration ==
          LocalDataOperationGate.shared.generation
      ? _notificationPreparationId
      : null;

  void confirmNotificationPrompt(Object owner) {
    if (!ownsNotificationPrompt(owner)) return;
    _notificationPreparationOwner = Object();
    _notificationPreparationViewOwner = null;
    _notificationPreparationId = state.schedule!.id;
    _notificationPreparationGeneration =
        LocalDataOperationGate.shared.generation;
    releaseNotificationPrompt(owner, resumeNearest: false);
  }

  void attachNotificationPreparation(Object owner, Object viewOwner) {
    if (identical(_notificationPreparationOwner, owner)) {
      _notificationPreparationViewOwner = viewOwner;
    }
  }

  void releaseNotificationPreparation(Object owner, Object viewOwner) {
    if (!identical(_notificationPreparationOwner, owner) ||
        !identical(_notificationPreparationViewOwner, viewOwner)) {
      return;
    }
    _notificationPreparationOwner = null;
    _notificationPreparationViewOwner = null;
    _notificationPreparationId = null;
    _notificationPreparationGeneration = null;
    _notificationRevision++;
    if (!isClosed && _notificationPromptOwner == null) {
      add(const ScheduleSubscriptionRequested());
    }
  }

  int _notificationRevision = 0;
  Object? _notificationPromptOwner;

  bool Function() _captureBackgroundValidity() {
    final revision = _notificationRevision;
    final generation = LocalDataOperationGate.shared.generation;
    return () =>
        !isClosed &&
        _notificationPromptOwner == null &&
        revision == _notificationRevision &&
        generation == LocalDataOperationGate.shared.generation;
  }

  bool ownsNotificationPrompt(Object owner) =>
      identical(_notificationPromptOwner, owner) &&
      identical(state.notificationPromptOwner, owner);

  /// The tap coordinator has already resolved this exact occurrence from the
  /// current database. Showing a confirmation never starts a timer/run or
  /// mutates the persisted confirmation marker.
  void presentNotificationPrompt(
    ScheduleWithPreparationEntity schedule,
    Object owner,
    bool Function() isCurrent,
  ) {
    if (isClosed || !isCurrent()) return;
    _notificationPreparationOwner = null;
    _notificationPreparationViewOwner = null;
    _notificationPreparationId = null;
    _notificationPreparationGeneration = null;
    _notificationRevision++;
    _notificationPromptOwner = owner;
    add(_NotificationPromptPresented(schedule, owner, isCurrent));
  }

  void releaseNotificationPrompt(Object owner, {bool resumeNearest = true}) {
    if (identical(_notificationPromptOwner, owner)) {
      _notificationRevision++;
      _notificationPromptOwner = null;
      if (resumeNearest && !isClosed) {
        add(const ScheduleSubscriptionRequested());
      }
    }
  }

  int _subscriptionRevision = 0;

  Future<void> _onSubscriptionRequested(
    ScheduleSubscriptionRequested event,
    Emitter<ScheduleState> emit,
  ) async {
    final revision = ++_subscriptionRevision;
    final previous = _upcomingScheduleSubscription;
    _upcomingScheduleSubscription = null;
    await previous?.cancel();
    if (isClosed || revision != _subscriptionRevision) return;

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
    if (notificationPreparationId != null || _explicitStartPending != null) {
      return;
    }
    // A repository emission is not a successful recovery receipt. Preserve
    // the live projection and pending warning for the same unchanged run.
    if (state.hasPendingStartRecovery &&
        event.upcomingSchedule?.id == state.schedule?.id &&
        event.upcomingSchedule?.cacheFingerprint ==
            state.schedule?.cacheFingerprint &&
        event.upcomingSchedule != null &&
        !_isEnded(event.upcomingSchedule!.doneStatus)) {
      return;
    }
    final current = _captureBackgroundValidity();
    if (!current()) return;
    _stepRevision++;
    _stepObservation = null;
    _scheduleStartTimer?.cancel();
    _scheduleStartTimer = null;
    final now = _nowProvider();

    if (event.upcomingSchedule == null ||
        event.upcomingSchedule!.scheduleTime.isBefore(now)) {
      final staleId = event.upcomingSchedule?.id ?? _currentScheduleId;
      if (staleId != null) {
        await _clearPersistedState(staleId);
        if (!current()) return;
      }
      _stopPreparationTimer();
      emit(const ScheduleState.notExists());
      _currentScheduleId = null;
      _activeEarlyStartScheduleId = null;
      _lastSnapshotSavedAt = null;
      _clearActivePreparationRun();
      _attemptedSteps.clear();
      return;
    }

    final incoming = event.upcomingSchedule!;
    if (_currentScheduleId != null && _currentScheduleId != incoming.id) {
      await _clearPersistedState(_currentScheduleId!);
      if (!current()) return;

      _clearActivePreparationRun();
    }
    _currentScheduleId = incoming.id;

    if (_notificationPromptOwner != null) return;
    final earlyStartSession = await _getEarlyStartSession(incoming.id);
    var hasEarlyStartSession = earlyStartSession != null;
    if (!current()) return;

    _snapshotInvalidated = false;
    var resolvedSchedule = await _restoreFromSnapshotIfValid(
      incoming,
      isCurrent: current,
    );
    if (!current()) return;
    hasEarlyStartSession =
        hasEarlyStartSession ||
        (_activePreparationRunStartedAt != null &&
            !_activePreparationRunStartedAt!.isAtSameMomentAs(
              incoming.preparationStartTime,
            ));
    if (!_snapshotInvalidated &&
        !hasEarlyStartSession &&
        incoming.preparationStartTime.isAfter(now)) {
      await _schedulePreparationSessionUseCase.clearPersistedState(incoming.id);
      resolvedSchedule = incoming;
      _clearActivePreparationRun();
    }
    if (!current()) return;
    if (_snapshotInvalidated) {
      _activeEarlyStartScheduleId = null;
      _clearActivePreparationRun();
      _stopPreparationTimer();
      emit(ScheduleState.upcoming(resolvedSchedule));
      return;
    }

    if (hasEarlyStartSession) {
      _activeEarlyStartScheduleId = resolvedSchedule.id;
      _activePreparationRunStartedAt ??= earlyStartSession!.startedAt;
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
      await _startScheduleLocally(resolvedSchedule.id);
      if (!current()) return;
      emit(ScheduleState.started(resolvedSchedule, isEarlyStarted: true));
      await _saveTimedPreparationSnapshot(resolvedSchedule, force: true);
      if (!current()) return;
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
      await _startScheduleLocally(resolvedSchedule.id);
      if (!current()) return;
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
    final current = _captureBackgroundValidity();
    if (!current()) return;
    if (_snapshotInvalidated) return;
    if (state.schedule != null && state.schedule!.id == _currentScheduleId) {
      if (_activeEarlyStartScheduleId == _currentScheduleId) return;
      AppLogger.debug('schedule started scheduleId=${state.schedule!.id}');
      await _startScheduleLocally(state.schedule!.id);
      if (!current()) return;
      emit(ScheduleState.started(state.schedule!));
      _navigationService.push('/scheduleStart');
      _activePreparationRunStartedAt ??= state.schedule!.preparationStartTime;
      _startPreparationTimer();
    }
  }

  Future<void> _onAlarmPromptRequested(
    ScheduleAlarmPromptRequested event,
    Emitter<ScheduleState> emit,
  ) async {
    final current = _captureBackgroundValidity();
    if (!current()) return;
    AppLogger.debug(
      'alarm prompt requested: scheduleId=${event.scheduleId} '
      'startPreparation=${event.startPreparation}',
    );
    final cachedSchedule = event.startPreparation
        ? _matchingCachedAlarmSchedule(event)
        : null;
    if (cachedSchedule != null) {
      await _activateAlarmPromptSchedule(
        cachedSchedule,
        event,
        emit,
        source: 'cached',
        isCurrent: current,
      );
      return;
    }

    final promptResult = await _schedulePreparationSessionUseCase
        .resolvePromptedSchedule(
          scheduleId: event.scheduleId,
          startPreparation: event.startPreparation,
          scheduleFingerprint: event.scheduleFingerprint,
          isCurrent: current,
        );
    if (!current()) return;
    switch (promptResult.status) {
      case SchedulePreparationPromptStatus.ready:
        await _activateAlarmPromptSchedule(
          promptResult.schedule!,
          event,
          emit,
          source: 'remote',
          isCurrent: current,
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
        'scheduleId=${event.scheduleId}',
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
    required bool Function() isCurrent,
  }) async {
    if (!isCurrent()) return;
    _currentScheduleId = schedule.id;
    _activeEarlyStartScheduleId = null;
    _scheduleStartTimer?.cancel();
    _scheduleStartTimer = null;
    _stopPreparationTimer();
    await _restoreFromSnapshotIfValid(schedule, isCurrent: isCurrent);
    if (!isCurrent()) return;
    if (_snapshotInvalidated) {
      _clearActivePreparationRun();
      emit(ScheduleState.upcoming(schedule));
      return;
    }

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

  Future<PreparationStartReceipt?> requestPreparationStart({
    required bool Function() isCurrent,
  }) {
    if (isClosed) return Future.value(null);
    final receipt = Completer<PreparationStartReceipt?>();
    add(SchedulePreparationStarted(receipt: receipt, isCurrent: isCurrent));
    return receipt.future;
  }

  Future<void> _onPreparationStarted(
    SchedulePreparationStarted event,
    Emitter<ScheduleState> emit,
  ) async {
    final generation = LocalDataOperationGate.shared.generation;
    final revision = _notificationRevision;
    final schedule = state.schedule;
    bool current() =>
        !isClosed &&
        !emit.isDone &&
        LocalDataOperationGate.shared.generation == generation &&
        _notificationRevision == revision &&
        state.schedule?.id == schedule?.id &&
        (event.isCurrent?.call() ?? _notificationPromptOwner == null);
    if (schedule == null || !current()) {
      event.receipt?.complete(null);
      return;
    }
    if (_activeEarlyStartScheduleId == schedule.id &&
        _activePreparationRunStartedAt != null &&
        event.receipt == null) {
      return;
    }
    final pending = Object();
    _explicitStartPending = pending;
    _currentScheduleId = schedule.id;
    _scheduleStartTimer?.cancel();
    _scheduleStartTimer = null;
    try {
      final result = await _schedulePreparationSessionUseCase.startEarlySession(
        schedule,
        startedAt: _activePreparationRunStartedAt ?? _nowProvider(),
        isCurrent: current,
      );
      if (!current()) {
        event.receipt?.complete(null);
        return;
      }
      // The prompt remains owned through the DB failure boundary. The widget
      // consumes that owner only after receiving this committed receipt.
      _snapshotInvalidated = false;
      _activeEarlyStartScheduleId = schedule.id;
      _activePreparationRunStartedAt = result.startedAt;
      _activePreparationActionEvents = result.actionEvents;
      emit(
        state.copyWith(
          status: ScheduleStatus.started,
          isEarlyStarted: true,
          hasPendingStartRecovery: result.hasPendingRecovery,
        ),
      );
      _lastSnapshotSavedAt = result.startedAt;
      _startPreparationTimer();
      event.receipt?.complete(result);
    } catch (error, stack) {
      if (event.receipt != null) {
        if (current()) {
          event.receipt!.completeError(error, stack);
        } else {
          event.receipt!.complete(null);
        }
      } else {
        AppLogger.debug(
          'Preparation start failed errorType=${error.runtimeType}',
        );
      }
    } finally {
      if (identical(_explicitStartPending, pending)) {
        _explicitStartPending = null;
      }
    }
  }

  Future<void> _onStartRecovery(
    SchedulePreparationRecoveryRequested event,
    Emitter<ScheduleState> emit,
  ) async {
    if (_finishing ||
        !state.hasPendingStartRecovery ||
        state.isRecoveringStart ||
        state.schedule == null ||
        _activePreparationRunStartedAt == null) {
      return;
    }
    final valid = _captureBackgroundValidity();
    final id = state.schedule!.id;
    final startedAt = _activePreparationRunStartedAt!;
    bool current() =>
        valid() &&
        !emit.isDone &&
        !_finishing &&
        state.schedule?.id == id &&
        _activePreparationRunStartedAt == startedAt;
    if (!current()) return;
    emit(state.copyWith(isRecoveringStart: true));
    try {
      final result = await _schedulePreparationSessionUseCase.startEarlySession(
        state.schedule!,
        startedAt: startedAt,
        isCurrent: current,
      );
      if (current()) {
        emit(
          state.copyWith(
            hasPendingStartRecovery: result.hasPendingRecovery,
            isRecoveringStart: false,
          ),
        );
      }
    } catch (_) {
      if (current()) emit(state.copyWith(isRecoveringStart: false));
    }
  }

  Future<void> _onTick(ScheduleTick event, Emitter<ScheduleState> emit) =>
      _onPreparationTimeRefreshRequested(
        const SchedulePreparationTimeRefreshRequested(),
        emit,
      );

  Future<void> _onPreparationTimeRefreshRequested(
    SchedulePreparationTimeRefreshRequested event,
    Emitter<ScheduleState> emit,
  ) async {
    if (_finishing ||
        _notificationPromptOwner != null ||
        state.schedule == null) {
      return;
    }
    if (event.origin != PreparationRefreshOrigin.periodic) _stepRevision++;
    if (state.schedule!.preparation.isAllStepsDone) return;
    final startedAt = _activePreparationRunStartedAt;
    if (startedAt == null) return;

    final previous = state.schedule!;
    final observedAt = _nowProvider();
    final refreshedPreparation = _derivePreparationRun(
      state.schedule!.preparation,
      startedAt: startedAt,
      actionEvents: _activePreparationActionEvents,
      now: observedAt,
    );
    final refreshedSchedule =
        ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
          state.schedule!,
          refreshedPreparation,
        );
    emit(state.copyWith(schedule: refreshedSchedule));
    _observeStepTransition(
      previous,
      refreshedSchedule,
      event.origin,
      observedAt,
    );
    final saved = await _saveTimedPreparationSnapshot(refreshedSchedule);
    if (!saved && !emit.isDone && state.schedule?.id == refreshedSchedule.id) {
      emit(state.copyWith(hasPendingStartRecovery: true));
    }
  }

  Future<void> _onStepSkipped(
    ScheduleStepSkipped event,
    Emitter<ScheduleState> emit,
  ) async {
    if (_finishing ||
        _notificationPromptOwner != null ||
        state.schedule == null) {
      return;
    }
    if (state.schedule!.preparation.isAllStepsDone) return;
    _stepObservation = null;
    _stepRevision++;
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
    _stepObservation = (_monotonicNow, now, _lifecycle);
    final saved = await _saveTimedPreparationSnapshot(newSchedule, force: true);
    if (!saved && !emit.isDone && state.schedule?.id == newSchedule.id) {
      emit(state.copyWith(hasPendingStartRecovery: true));
    }
  }

  Future<void> _onFinished(
    ScheduleFinished event,
    Emitter<ScheduleState> emit,
  ) async {
    final current = _captureBackgroundValidity();
    if (!current() || state.schedule == null) return;
    final scheduleId = state.schedule!.id;
    _finishing = true;
    _stopPreparationTimer();
    _stepObservation = null;
    _stepRevision++;
    try {
      await _schedulePreparationSessionUseCase.finishSchedulePreparation(
        scheduleId,
        latenessTime: event.latenessTime,
      );
      if (!current()) return;
      final restoreNearest = notificationPreparationId != null;
      _notificationPreparationOwner = null;
      _notificationPreparationViewOwner = null;
      _notificationPreparationId = null;
      _notificationPreparationGeneration = null;
      // After finishing, clear timers and set state to notExists
      _stopPreparationTimer();
      _scheduleStartTimer?.cancel();
      _currentScheduleId = null;
      _activeEarlyStartScheduleId = null;
      _lastSnapshotSavedAt = null;
      _clearActivePreparationRun();
      _attemptedSteps.clear();
      _stepRun = null;
      emit(const ScheduleState.notExists());
      if (restoreNearest) add(const ScheduleSubscriptionRequested());
    } catch (error) {
      AppLogger.debug('error finishing schedule: $error');
      if (current()) {
        emit(state.copyWith(isRecoveringStart: false));
        _startPreparationTimer();
      }
    } finally {
      _finishing = false;
    }
  }

  Future<void> _startScheduleLocally(String scheduleId) async {
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
    _activePreparationRunStartedAt ??= state.isEarlyStarted
        ? _nowProvider().subtract(state.schedule!.preparation.elapsedTime)
        : state.schedule!.preparationStartTime;
    _stepObservation = null;
    _stepRevision++;
    add(
      const SchedulePreparationTimeRefreshRequested(
        origin: PreparationRefreshOrigin.restore,
      ),
    );
    _preparationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isClosed) {
        add(
          const SchedulePreparationTimeRefreshRequested(
            origin: PreparationRefreshOrigin.periodic,
          ),
        );
      }
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
    _stepRevision++;
    _attemptedSteps.clear();
    _stepRun = null;
    return super.close();
  }

  bool _snapshotInvalidated = false;

  Future<ScheduleWithPreparationEntity> _restoreFromSnapshotIfValid(
    ScheduleWithPreparationEntity incoming, {
    bool Function()? isCurrent,
  }) async {
    _clearActivePreparationRun();
    _snapshotInvalidated = false;
    return _schedulePreparationSessionUseCase.restoreTimedPreparationIfValid(
      incoming,
      now: _nowProvider(),
      onInvalidated: () {
        if (isCurrent?.call() ?? true) _snapshotInvalidated = true;
      },
      onRestoredSession: ({required startedAt, required actionEvents}) {
        if (!(isCurrent?.call() ?? true)) return;
        _activePreparationRunStartedAt = startedAt;
        _activePreparationActionEvents = actionEvents;
      },
    );
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
    if (current == null) {
      return preparation;
    }
    final eventStepId = event.stepId;
    final eventStepStillExists =
        eventStepId != null &&
        preparation.preparationStepList.any((step) => step.id == eventStepId);
    if (eventStepStillExists && current.id != eventStepId) {
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
    return _schedulePreparationSessionUseCase.getEarlyStartSession(scheduleId);
  }

  Future<bool> _saveTimedPreparationSnapshot(
    ScheduleWithPreparationEntity schedule, {
    bool force = false,
  }) async {
    final now = _nowProvider();
    if (!force &&
        !state.hasPendingStartRecovery &&
        _lastSnapshotSavedAt != null &&
        now.difference(_lastSnapshotSavedAt!) < const Duration(seconds: 5)) {
      return true;
    }
    try {
      await _schedulePreparationSessionUseCase.saveTimedPreparationSnapshot(
        schedule,
        savedAt: now,
        startedAt: _activePreparationRunStartedAt,
        actionEvents: _activePreparationActionEvents,
        persist: !state.hasPendingStartRecovery,
      );
      _lastSnapshotSavedAt = now;
      return !state.hasPendingStartRecovery;
    } catch (_) {
      return false;
    }
  }

  Future<void> _clearPersistedState(String scheduleId) async {
    await _schedulePreparationSessionUseCase.clearPersistedState(scheduleId);
  }

  void _clearActivePreparationRun() {
    _stepObservation = null;
    _stepRevision++;
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

  void _observeStepTransition(
    ScheduleWithPreparationEntity before,
    ScheduleWithPreparationEntity after,
    PreparationRefreshOrigin origin,
    DateTime wall,
  ) {
    final mono = _monotonicNow;
    final phase = _lifecycle;
    final previous = _stepObservation;
    final run = (
      LocalDataOperationGate.shared.generation,
      after.id,
      _activePreparationRunStartedAt!,
    );
    if (_stepRun != run) {
      _stepRun = run;
      _attemptedSteps.clear();
    }
    _stepObservation = (mono, wall, phase);
    if (origin != PreparationRefreshOrigin.periodic ||
        previous == null ||
        phase != AppLifecycleState.paused ||
        previous.$3 != phase) {
      return;
    }
    final delta = mono - previous.$1;
    if (delta < Duration.zero ||
        delta > stepNotificationFreshness ||
        (wall.difference(previous.$2) - delta).abs() > stepClockTolerance) {
      return;
    }
    final steps = after.preparation.preparationStepList;
    final oldIndex = steps.indexWhere(
      (s) => s.id == before.preparation.currentStep?.id,
    );
    final step = after.preparation.currentStep;
    if (step == null ||
        oldIndex < 0 ||
        steps.indexWhere((s) => s.id == step.id) != oldIndex + 1) {
      return;
    }
    // Consume before the first await; failure is not an invitation to replay.
    if (!_attemptedSteps.add(step.id)) return;
    final revision = _stepRevision;
    final backgroundCurrent = _captureBackgroundValidity();
    bool current() =>
        backgroundCurrent() &&
        !LocalDataOperationGate.shared.isInvalidated &&
        !LocalDataOperationGate.shared.isReplacingData &&
        revision == _stepRevision &&
        _stepRun == run &&
        state.schedule?.id == after.id &&
        _activePreparationRunStartedAt == run.$3 &&
        state.schedule?.preparation.currentStep?.id == step.id &&
        _lifecycle == AppLifecycleState.paused &&
        _monotonicNow - mono <= stepNotificationFreshness &&
        _monotonicNow >= mono &&
        (_nowProvider().difference(wall) - (_monotonicNow - mono)).abs() <=
            stepClockTolerance;
    unawaited(_submitStep(after, step.id, current));
  }

  Future<void> _submitStep(
    ScheduleWithPreparationEntity schedule,
    String stepId,
    bool Function() current,
  ) async {
    if (!current()) return;
    try {
      await _notifyPreparationStep(
        scheduleName: schedule.scheduleName,
        preparationName: '',
        scheduleId: schedule.id,
        stepId: stepId,
        isCurrent: current,
      );
    } catch (error) {
      AppLogger.debug(
        '[ScheduleBloc] step delivery failed: ${error.runtimeType}',
      );
    }
  }
}
