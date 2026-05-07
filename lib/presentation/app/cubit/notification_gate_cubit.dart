import 'package:equatable/equatable.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/core/logging/app_logger.dart';
import 'package:on_time_front/core/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'notification_gate_state.dart';

class NotificationGateCubit extends Cubit<NotificationGateState> {
  NotificationGateCubit({
    NotificationService? notificationService,
  })  : _notificationService =
            notificationService ?? NotificationService.instance,
        super(const NotificationGateState.initial()) {
    refreshPermission();
  }

  static const String _dismissedKey = 'notification_prompt_dismissed';

  final NotificationService _notificationService;

  Future<void> refreshPermission() async {
    final prefs = await SharedPreferences.getInstance();
    final isDismissed = prefs.getBool(_dismissedKey) ?? false;
    if (isDismissed) {
      emit(const NotificationGateState.dismissed());
      return;
    }

    final permission = await _notificationService.checkNotificationPermission();
    if (permission == AuthorizationStatus.authorized) {
      await _initializeNotifications();
      emit(const NotificationGateState.allowed());
      return;
    }

    emit(const NotificationGateState.required());
  }

  Future<void> markPermissionAllowed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dismissedKey);
    await _initializeNotifications();
    emit(const NotificationGateState.allowed());
  }

  Future<void> dismissPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey, true);
    emit(const NotificationGateState.dismissed());
  }

  Future<void> _initializeNotifications() async {
    try {
      await _notificationService.initialize();
    } catch (error) {
      AppLogger.debug(
        '[NotificationGate] initialize failed errorType=${error.runtimeType}',
      );
    }
  }
}
