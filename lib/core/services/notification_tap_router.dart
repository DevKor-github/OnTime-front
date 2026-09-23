import 'package:on_time_front/domain/entities/notification_route_payload.dart';
import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/services/navigation_service.dart';
import 'package:on_time_front/core/services/notification_routing.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/use-cases/schedule_preparation_session_use_case.dart';

abstract interface class NotificationTapRouter {
  void routeLocalNotificationTap(String? payload);
}

class NoopNotificationTapRouter implements NotificationTapRouter {
  const NoopNotificationTapRouter();
  @override
  void routeLocalNotificationTap(String? payload) {}
}

/// Internal, verified route arguments. Never decoded from OS payloads.
class NotificationPromptRouteData {
  NotificationPromptRouteData({
    required this.schedule,
    required this.payload,
    required this.isCurrent,
    required this.onClosed,
  });
  final ScheduleWithPreparationEntity schedule;
  final Map<String, dynamic> payload;
  final bool Function() isCurrent;
  final void Function() onClosed;
}

typedef ResolveNotificationPrompt =
    Future<SchedulePreparationPromptResult> Function(
      String id,
      bool Function() isCurrent,
    );

@Singleton(as: NotificationTapRouter)
class NavigationNotificationTapRouter implements NotificationTapRouter {
  NavigationNotificationTapRouter(this._navigationService);

  final NavigationService _navigationService;
  LocalDataOperationGate _dataGate = LocalDataOperationGate.shared;
  bool Function()? _isReady;
  ResolveNotificationPrompt? _resolve;
  int _receipt = 0;
  int _receptionSequence = 0;
  _PendingTap? _pending;
  _PendingTap? _inflight;
  _PendingTap? _open;

  (int, int) get receipt => (_receptionSequence, _dataGate.generation);

  void configure({
    required bool Function() isReady,
    required ResolveNotificationPrompt resolve,
    LocalDataOperationGate? dataGate,
  }) {
    _dataGate.removeListener(retry);
    _isReady = isReady;
    _resolve = resolve;
    _dataGate = dataGate ?? LocalDataOperationGate.shared;
    _dataGate.addListener(retry);
    retry();
  }

  void detach() {
    _dataGate.removeListener(retry);
    _isReady = null;
    _resolve = null;
  }

  void receiveInitial(String? payload, (int, int) captured) {
    if (captured != receipt) return;
    routeLocalNotificationTap(payload);
  }

  @override
  void routeLocalNotificationTap(String? payload) {
    final data = safeNotificationTapData(payload);
    if (data == null) return;
    final target = notificationRouteForData(data);
    if (target == null) return;
    _receive(target);
  }

  void routeNativeNotificationTap(Map<String, String> payload) {
    final safe = minimalScheduleRoutePayload(payload);
    if (safe.isEmpty) return;
    final target = notificationRouteForData(safe);
    if (target != null) _receive(target);
  }

  void _receive(NotificationRouteTarget target) {
    _discardReplacedData();
    _receptionSequence++;
    // Only schedule confirmation targets participate in DB validation. Existing
    // preparation step notifications retain their alarm-screen destination.
    final extra = target.extra;
    final id = extra is Map ? extra['scheduleId'] as String? : null;
    final key = '${target.path}:${id ?? ''}';
    if ([
      _pending,
      _inflight,
      _open,
    ].any((tap) => tap != null && _current(tap) && tap.key == key)) {
      return;
    }
    _pending = _PendingTap(target, key, ++_receipt, _dataGate.generation);
    unawaited(_drain());
  }

  void retry() {
    _discardReplacedData();
    unawaited(_drain());
  }

  void _discardReplacedData() {
    if (_pending?.generation != _dataGate.generation) _pending = null;
    if (_open?.generation != _dataGate.generation) _open = null;
  }

  bool _current(_PendingTap tap) =>
      tap.receipt == _receipt && tap.generation == _dataGate.generation;

  Future<void> _drain() async {
    final tap = _pending;
    final resolve = _resolve;
    if (tap == null ||
        _inflight != null ||
        resolve == null ||
        !_dataGate.isAvailable ||
        !(_isReady?.call() ?? false)) {
      return;
    }
    _inflight = tap;
    try {
      final target = tap.target;
      if (target.path != '/scheduleStart') {
        if (_current(tap) && (_isReady?.call() ?? false)) {
          _pending = null;
          _navigationService.push(target.path, extra: target.extra);
        }
        return;
      }
      final payload = Map<String, dynamic>.from(target.extra! as Map);
      final id = payload['scheduleId'] as String?;
      if (id == null) {
        _pending = null;
        return;
      }
      final result = await resolve(id, () => _current(tap));
      if (!_current(tap)) return;
      if (!_dataGate.isAvailable || !(_isReady?.call() ?? false)) return;
      if (result.status == SchedulePreparationPromptStatus.unavailable) return;
      if (result.status == SchedulePreparationPromptStatus.rejected) {
        _pending = null;
        return;
      }
      _open = tap;
      final data = NotificationPromptRouteData(
        schedule: result.schedule!,
        payload: payload,
        isCurrent: () => _current(tap) && identical(_open, tap),
        onClosed: () {
          if (identical(_open, tap)) _open = null;
        },
      );
      _navigationService.push(target.path, extra: data);
      _pending = null;
    } catch (_) {
      // Retain the same-generation intent for an explicit retry. Never turn a
      // platform/database exception into a missing Schedule or user content.
      if (identical(_open, tap)) _open = null;
    } finally {
      _inflight = null;
      _discardReplacedData();
      if (_pending != null && !identical(_pending, tap)) unawaited(_drain());
    }
  }
}

class _PendingTap {
  _PendingTap(this.target, this.key, this.receipt, this.generation);
  final NotificationRouteTarget target;
  final String key;
  final int receipt;
  final int generation;
}
