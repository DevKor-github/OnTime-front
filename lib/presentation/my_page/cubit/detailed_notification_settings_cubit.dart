import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/core/services/detailed_notification_preference_service.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';
import 'detailed_notification_settings_state.dart';
export 'detailed_notification_settings_state.dart';

/// DI owns this controller. A settings route only subscribes; leaving the route
/// does not discard a pending privacy choice or cancel a platform Future.
@lazySingleton
class DetailedNotificationSettingsCubit
    extends Cubit<DetailedNotificationSettingsState> {
  DetailedNotificationSettingsCubit(
    DetailedNotificationPreferenceService preferences,
    ReconcileAlarmsUseCase reconcile, {
    @ignoreParam AlarmOperationCoordinator? operations,
  }) : this.test(preferences, reconcile, operations: operations);

  DetailedNotificationSettingsCubit.test(
    this._preferences,
    this._reconcile, {
    AlarmOperationCoordinator? operations,
    Duration delayNotice = const Duration(seconds: 10),
  }) : _operations = operations ?? AlarmOperationCoordinator.shared,
       _delayNotice = delayNotice,
       super(
         DetailedNotificationSettingsState(
           generation:
               (operations ?? AlarmOperationCoordinator.shared).generation,
         ),
       ) {
    _operations.gate.addListener(_gateChanged);
  }

  final DetailedNotificationPreferencePort _preferences;
  final ReconcileAlarmsUseCase _reconcile;
  final AlarmOperationCoordinator _operations;
  final Duration _delayNotice;
  int _revision = 0;
  int _deliveryRevision = 0;
  int _deliveryInFlight = 0;
  bool _writing = false;
  _Intent? _pending;
  _Intent? _retryIntent;
  Future<void>? _refreshing;
  Timer? _notice;
  AlarmReconciliationResult? lastReconciliationResult;

  bool _current(int generation, int revision) =>
      !isClosed &&
      generation == _operations.generation &&
      revision == _revision &&
      _operations.canSchedule;

  void _gateChanged() {
    if (isClosed) return;
    if (state.generation != _operations.generation ||
        !_operations.canSchedule) {
      _revision++;
      _deliveryRevision++;
      _notice?.cancel();
      _pending = null;
      _retryIntent = null;
      lastReconciliationResult = null;
      emit(
        DetailedNotificationSettingsState(
          generation: _operations.generation,
          load: DetailedPreferenceLoad.unavailable,
        ),
      );
    }
  }

  void _update({
    bool? confirmed,
    bool? requested,
    bool clearConfirmed = false,
    bool clearRequested = false,
    bool? schedulesEnabled,
    DetailedPreferenceLoad? load,
    DetailedPreferenceSave? save,
    DetailedPreferenceDelivery? delivery,
  }) {
    if (isClosed) return;
    emit(
      DetailedNotificationSettingsState(
        generation: _operations.generation,
        confirmedEnabled: clearConfirmed
            ? null
            : confirmed ?? state.confirmedEnabled,
        requestedEnabled: clearRequested
            ? null
            : requested ?? state.requestedEnabled,
        scheduleNotificationsEnabled:
            schedulesEnabled ?? state.scheduleNotificationsEnabled,
        load: load ?? state.load,
        save: save ?? state.save,
        delivery: delivery ?? state.delivery,
      ),
    );
  }

  Future<void> refresh() {
    if (_writing || _pending != null) return Future.value();
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  Future<void> _refresh() async {
    final generation = _operations.generation;
    final revision = _revision;
    if (!_operations.canSchedule) {
      _gateChanged();
      return;
    }
    if (state.confirmedEnabled == null) {
      _update(load: DetailedPreferenceLoad.loading);
    }
    try {
      final snapshot = await _preferences.read(expectedGeneration: generation);
      if (!_current(generation, revision)) return;
      _update(
        confirmed: snapshot.detailedEnabled,
        schedulesEnabled: snapshot.scheduleNotificationsEnabled,
        load: DetailedPreferenceLoad.ready,
      );
      if (_deliveryInFlight == 0) {
        await _apply(snapshot, revision);
      }
    } catch (_) {
      if (!_current(generation, revision)) return;
      _update(
        clearConfirmed: true,
        load: DetailedPreferenceLoad.failed,
        delivery: DetailedPreferenceDelivery.unknown,
      );
    }
  }

  /// Accept synchronously; persistence and delivery report through state.
  void request(bool enabled) {
    if (!state.canRequest || !_operations.canSchedule || isClosed) return;
    if (state.requestedEnabled == enabled ||
        (state.requestedEnabled == null &&
            state.confirmedEnabled == enabled &&
            state.save == DetailedPreferenceSave.idle)) {
      return;
    }
    final generation = _operations.generation;
    final permit = _operations.acceptContentIntent(
      enabled,
      expectedGeneration: generation,
    );
    final intent = _Intent(enabled, ++_revision, permit);
    _pending = intent;
    _retryIntent = null;
    _notice?.cancel();
    _deliveryRevision++;
    _update(
      requested: enabled,
      save: DetailedPreferenceSave.saving,
      delivery: DetailedPreferenceDelivery.unknown,
    );
    unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_writing) return;
    _writing = true;
    try {
      while (_pending != null && !isClosed) {
        final intent = _pending!;
        _pending = null;
        if (!_current(intent.permit.generation, intent.revision)) continue;
        try {
          final snapshot = await _preferences.write(
            intent.enabled,
            expectedGeneration: intent.permit.generation,
          );
          if (!_current(intent.permit.generation, intent.revision)) continue;
          _acceptedSnapshot(intent, snapshot);
        } catch (_) {
          if (!_current(intent.permit.generation, intent.revision)) continue;
          try {
            final snapshot = await _preferences.read(
              expectedGeneration: intent.permit.generation,
            );
            if (!_current(intent.permit.generation, intent.revision)) continue;
            _operations.confirmContentIntent(
              intent.permit,
              committedEnabled: snapshot.detailedEnabled,
            );
            if (snapshot.detailedEnabled == intent.enabled) {
              _acceptedSnapshot(intent, snapshot);
            } else {
              _retryIntent = intent;
              _update(
                confirmed: snapshot.detailedEnabled,
                schedulesEnabled: snapshot.scheduleNotificationsEnabled,
                load: DetailedPreferenceLoad.ready,
                save: DetailedPreferenceSave.failed,
                delivery: intent.enabled
                    ? DetailedPreferenceDelivery.needsCheck
                    : DetailedPreferenceDelivery.contentDeferred,
              );
            }
          } catch (_) {
            if (!_current(intent.permit.generation, intent.revision)) continue;
            _retryIntent = intent;
            _update(
              clearConfirmed: true,
              load: DetailedPreferenceLoad.failed,
              save: DetailedPreferenceSave.failed,
              delivery: DetailedPreferenceDelivery.unknown,
            );
          }
        }
      }
    } finally {
      _writing = false;
    }
  }

  void _acceptedSnapshot(
    _Intent intent,
    DetailedNotificationPreferenceSnapshot snapshot,
  ) {
    _operations.confirmContentIntent(
      intent.permit,
      committedEnabled: snapshot.detailedEnabled,
    );
    _retryIntent = null;
    _update(
      confirmed: snapshot.detailedEnabled,
      clearRequested: true,
      schedulesEnabled: snapshot.scheduleNotificationsEnabled,
      load: DetailedPreferenceLoad.ready,
      save: DetailedPreferenceSave.idle,
    );
    // Never block the DB drain on a platform Future. A later OFF may commit
    // while the existing OS owner is still waiting for a native response.
    unawaited(_apply(snapshot, intent.revision));
  }

  Future<void> retry() async {
    if (isClosed || _writing || !_operations.canSchedule) return;
    final intent = _retryIntent;
    if (intent != null && _current(intent.permit.generation, intent.revision)) {
      _pending = intent;
      _retryIntent = null;
      _update(save: DetailedPreferenceSave.saving);
      await _drain();
    } else if (_deliveryInFlight == 0) {
      await refresh();
    }
  }

  Future<void> _apply(
    DetailedNotificationPreferenceSnapshot snapshot,
    int revision,
  ) async {
    if (!_current(snapshot.generation, revision)) return;
    final delivery = ++_deliveryRevision;
    _deliveryInFlight++;
    _notice?.cancel();
    _update(delivery: DetailedPreferenceDelivery.applying);
    _notice = Timer(_delayNotice, () {
      if (_current(snapshot.generation, revision) &&
          delivery == _deliveryRevision) {
        _update(delivery: DetailedPreferenceDelivery.delayed);
      }
    });
    try {
      final result = await _reconcile();
      if (!_current(snapshot.generation, revision) ||
          delivery != _deliveryRevision) {
        return;
      }
      lastReconciliationResult = result;
      _update(delivery: _deliveryState(snapshot, result));
    } catch (_) {
      if (_current(snapshot.generation, revision) &&
          delivery == _deliveryRevision) {
        _update(delivery: DetailedPreferenceDelivery.needsCheck);
      }
    } finally {
      _deliveryInFlight--;
      if (delivery == _deliveryRevision) _notice?.cancel();
    }
  }

  DetailedPreferenceDelivery _deliveryState(
    DetailedNotificationPreferenceSnapshot snapshot,
    AlarmReconciliationResult result,
  ) {
    final reasons = result.failures.map((failure) => failure.reason).toSet();
    if (reasons.contains(AlarmFailureReason.cancellationFailed)) {
      return DetailedPreferenceDelivery.cancellationUnconfirmed;
    }
    if (reasons.contains(AlarmFailureReason.observationFailed) ||
        result.status == AlarmReconciliationStatus.settingsUnavailable) {
      return DetailedPreferenceDelivery.needsCheck;
    }
    if (reasons.contains(AlarmFailureReason.contentDeferred)) {
      return DetailedPreferenceDelivery.contentDeferred;
    }
    if (result.status == AlarmReconciliationStatus.partial) {
      return reasons.contains(AlarmFailureReason.platformError)
          ? DetailedPreferenceDelivery.schedulingFailed
          : DetailedPreferenceDelivery.needsCheck;
    }
    if (result.status == AlarmReconciliationStatus.disabled &&
        !snapshot.scheduleNotificationsEnabled) {
      return DetailedPreferenceDelivery.off;
    }
    if (result.status == AlarmReconciliationStatus.permissionNeeded) {
      return DetailedPreferenceDelivery.permissionNeeded;
    }
    if (result.status != AlarmReconciliationStatus.armed) {
      return DetailedPreferenceDelivery.needsCheck;
    }
    return result.armedScheduleIds.isEmpty
        ? DetailedPreferenceDelivery.noUpcoming
        : DetailedPreferenceDelivery.applied;
  }

  @override
  @disposeMethod
  Future<void> close() {
    _operations.gate.removeListener(_gateChanged);
    _notice?.cancel();
    _pending = null;
    return super.close();
  }
}

final class _Intent {
  const _Intent(this.enabled, this.revision, this.permit);
  final bool enabled;
  final int revision;
  final AlarmContentPermit permit;
}
