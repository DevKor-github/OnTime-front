import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:on_time_front/core/services/local_time_zone_service.dart';
import 'package:on_time_front/core/time/time_zone_rules.dart';
import 'device_time_zone_state.dart';

/// Read-only setting observation. It never updates a schedule or its draft.
final class DeviceTimeZoneController
    extends ValueNotifier<DeviceTimeZoneState> {
  DeviceTimeZoneController({Future<String> Function()? readZone})
    : _readZone = readZone ?? LocalTimeZoneService.current,
      super(const DeviceTimeZoneState.loading());

  final Future<String> Function() _readZone;
  int _revision = 0;
  bool _disposed = false;
  bool _refreshing = false;
  bool get isRefreshing => _refreshing;

  Future<void> refresh() async {
    if (_disposed) return;
    final revision = ++_revision;
    _refreshing = true;
    try {
      final identifier = await _readZone();
      if (_disposed || revision != _revision) return;
      value = TimeZoneRules.contains(identifier)
          ? DeviceTimeZoneState.known(identifier)
          : const DeviceTimeZoneState.unavailable();
    } catch (_) {
      if (!_disposed && revision == _revision) {
        value = const DeviceTimeZoneState.unavailable();
      }
    } finally {
      if (!_disposed && revision == _revision) _refreshing = false;
    }
  }

  void invalidatePendingRead() {
    _revision++;
    _refreshing = false;
  }

  @override
  void dispose() {
    _disposed = true;
    invalidatePendingRead();
    super.dispose();
  }
}

/// One observation owner above the router, shared by pages and modal routes.
class DeviceTimeZoneScope extends StatefulWidget {
  const DeviceTimeZoneScope({super.key, required this.child, this.controller});
  final Widget child;
  final DeviceTimeZoneController? controller;

  static DeviceTimeZoneState stateOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_DeviceTimeZoneInherited>()
          ?.notifier
          ?.value ??
      const DeviceTimeZoneState.unavailable();

  @override
  State<DeviceTimeZoneScope> createState() => _DeviceTimeZoneScopeState();
}

class _DeviceTimeZoneScopeState extends State<DeviceTimeZoneScope>
    with WidgetsBindingObserver {
  late DeviceTimeZoneController _controller;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? DeviceTimeZoneController();
    WidgetsBinding.instance.addObserver(this);
    _startIfActive();
  }

  @override
  void didUpdateWidget(DeviceTimeZoneScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.controller, widget.controller)) return;
    _timer?.cancel();
    if (oldWidget.controller == null) {
      _controller.dispose();
    } else {
      _controller.invalidatePendingRead();
    }
    _controller = widget.controller ?? DeviceTimeZoneController();
    _startIfActive();
  }

  void _startIfActive() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle == null || lifecycle == AppLifecycleState.resumed) _resume();
  }

  void _resume() {
    unawaited(_controller.refresh());
    _timer?.cancel();
    // A named zone can change without a different offset/abbreviation. Observe
    // the platform setting itself, only while this app's UI is active.
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!_controller.isRefreshing) unawaited(_controller.refresh());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resume();
    } else {
      _timer?.cancel();
      _controller.invalidatePendingRead();
    }
  }

  @override
  Widget build(BuildContext context) =>
      _DeviceTimeZoneInherited(notifier: _controller, child: widget.child);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.invalidatePendingRead();
    }
    super.dispose();
  }
}

class _DeviceTimeZoneInherited
    extends InheritedNotifier<DeviceTimeZoneController> {
  const _DeviceTimeZoneInherited({
    required super.notifier,
    required super.child,
  });
}
