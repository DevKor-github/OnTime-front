import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/presentation/app/bloc/auth/auth_bloc.dart';
import 'package:on_time_front/presentation/app/cubit/alarm_gate_cubit.dart';
import 'package:on_time_front/presentation/app/cubit/notification_gate_cubit.dart';
import 'package:on_time_front/presentation/shared/router/go_router.dart';

void main() {
  test(
    'authenticated user goes directly to notification prompt while alarm gate is unresolved',
    () {
      final redirect = appRedirectLocation(
        authStatus: AuthStatus.authenticated,
        notificationGateState: const NotificationGateState.required(),
        alarmGateState: const AlarmGateState.initial(),
        path: '/signIn',
      );

      expect(redirect, '/allowNotification');
    },
  );

  test(
    'authenticated user waits on startup while gates are still unresolved',
    () {
      final redirect = appRedirectLocation(
        authStatus: AuthStatus.authenticated,
        notificationGateState: const NotificationGateState.initial(),
        alarmGateState: const AlarmGateState.initial(),
        path: '/signIn',
      );

      expect(redirect, '/startup');
    },
  );
}
