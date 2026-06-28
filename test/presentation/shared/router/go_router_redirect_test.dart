import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/presentation/app/bloc/auth/auth_bloc.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';
import 'package:on_time_front/presentation/app/cubit/alarm_gate_cubit.dart';
import 'package:on_time_front/presentation/app/cubit/notification_gate_cubit.dart';
import 'package:on_time_front/presentation/shared/router/go_router.dart';

void main() {
  test(
    'router refresh listenable ignores schedule progress but refreshes for route gates',
    () async {
      final scheduleController = StreamController<ScheduleState>.broadcast();
      final authController = StreamController<AuthState>.broadcast();
      final notificationGateController =
          StreamController<NotificationGateState>.broadcast();
      final alarmGateController = StreamController<AlarmGateState>.broadcast();
      final listenable = appRouterRefreshListenable(
        authStream: authController.stream,
        notificationGateStream: notificationGateController.stream,
        alarmGateStream: alarmGateController.stream,
      );
      addTearDown(() async {
        listenable.dispose();
        await scheduleController.close();
        await authController.close();
        await notificationGateController.close();
        await alarmGateController.close();
      });

      var refreshCount = 0;
      listenable.addListener(() => refreshCount++);

      scheduleController.add(const ScheduleState.initial());
      await pumpEventQueue();

      expect(refreshCount, 0);

      authController.add(const AuthState.loading());
      notificationGateController.add(const NotificationGateState.required());
      alarmGateController.add(const AlarmGateState.required());
      await pumpEventQueue();

      expect(refreshCount, 3);
    },
  );

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
