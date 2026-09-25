import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/services/notification_tap_router.dart';
import 'package:on_time_front/presentation/alarm/screens/schedule_start_screen.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';

/// This route receives an internal validated object, never a second async
/// lookup of an untrusted OS map. It owns only the confirmation presentation.
class NotificationScheduleStartRoute extends StatefulWidget {
  const NotificationScheduleStartRoute({
    super.key,
    required this.data,
    required this.observer,
  });
  final NotificationPromptRouteData data;
  final RouteObserver<PageRoute<dynamic>> observer;
  @override
  State<NotificationScheduleStartRoute> createState() =>
      _NotificationScheduleStartRouteState();
}

class _NotificationScheduleStartRouteState
    extends State<NotificationScheduleStartRoute>
    with RouteAware {
  bool _presented = false;
  ScheduleBloc? _bloc;
  ModalRoute<void>? _route;

  @override
  void initState() {
    super.initState();
    LocalDataOperationGate.shared.addListener(_checkGeneration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bloc = context.read<ScheduleBloc>();
    final route = ModalRoute.of(context);
    if (route != _route && route is PageRoute<dynamic>) {
      widget.observer.unsubscribe(this);
      _route = route;
      widget.observer.subscribe(this, route);
    }
    if (_presented) return;
    _presented = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!widget.data.isCurrent()) {
        context.go('/home');
        return;
      }
      _bloc!.presentNotificationPrompt(
        widget.data.schedule,
        widget.data,
        widget.data.isCurrent,
      );
    });
  }

  void _checkGeneration() {
    if (widget.data.isCurrent()) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _route?.isCurrent == true && !widget.data.isCurrent()) {
        context.go('/home');
      }
    });
  }

  void _release() {
    widget.data.onClosed();
    _bloc?.releaseNotificationPrompt(widget.data);
  }

  @override
  void didPushNext() => _release();
  @override
  void didPop() => _release();
  @override
  void didPopNext() => _checkGeneration();
  @override
  void dispose() {
    LocalDataOperationGate.shared.removeListener(_checkGeneration);
    widget.observer.unsubscribe(this);
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ScheduleBloc>().state;
    if (!widget.data.isCurrent() ||
        !context.read<ScheduleBloc>().ownsNotificationPrompt(widget.data) ||
        state.schedule?.id != widget.data.schedule.id) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ScheduleStartScreen(
      requiresExplicitStart: true,
      isCurrent: widget.data.isCurrent,
      onExplicitStart: () => _bloc?.confirmNotificationPrompt(widget.data),
      promptVariant: scheduleStartPromptVariantFromRouteExtra(
        widget.data.payload,
      ),
    );
  }
}
