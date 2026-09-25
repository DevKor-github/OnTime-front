import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:on_time_front/core/time/device_civil_day.dart';

/// Refreshes device-day displays independently of durable schedule changes.
class DeviceDayRefresh extends StatefulWidget {
  const DeviceDayRefresh({super.key, required this.builder, this.now});
  final Widget Function(BuildContext context, DateTime now) builder;
  final DateTime Function()? now;

  @override
  State<DeviceDayRefresh> createState() => _DeviceDayRefreshState();
}

class _DeviceDayRefreshState extends State<DeviceDayRefresh>
    with WidgetsBindingObserver {
  late DateTime _displayNow;
  Timer? _midnight;
  Timer? _zoneCheck;
  DateTime _now() => (widget.now?.call() ?? DateTime.now()).toLocal();
  (int, int, int, Duration, String) _signature(DateTime value) => (
    value.year,
    value.month,
    value.day,
    value.timeZoneOffset,
    value.timeZoneName,
  );

  @override
  void initState() {
    super.initState();
    _displayNow = _now();
    WidgetsBinding.instance.addObserver(this);
    _armMidnight();
    _zoneCheck = Timer.periodic(const Duration(minutes: 1), (_) => _refresh());
  }

  void _armMidnight() {
    _midnight?.cancel();
    final now = _now();
    _midnight = Timer(
      DeviceCivilDay.at(now).endUtc.difference(now.toUtc()),
      () {
        _refresh(force: true);
      },
    );
  }

  void _refresh({bool force = false}) {
    if (!mounted) return;
    final now = _now();
    if (!force && _signature(now) == _signature(_displayNow)) return;
    setState(() => _displayNow = now);
    _armMidnight();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh(force: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnight?.cancel();
    _zoneCheck?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _displayNow);
}
