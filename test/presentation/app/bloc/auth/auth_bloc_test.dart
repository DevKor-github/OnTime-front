import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/use-cases/load_user_use_case.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';
import 'package:on_time_front/domain/use-cases/sign_out_use_case.dart';
import 'package:on_time_front/domain/use-cases/stream_user_use_case.dart';
import 'package:on_time_front/presentation/app/bloc/auth/auth_bloc.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';

void main() {
  late StreamController<UserEntity> userController;
  late _FakeStreamUserUseCase streamUserUseCase;
  late _FakeLoadUserUseCase loadUserUseCase;
  late _FakeSignOutUseCase signOutUseCase;
  late _FakeScheduleBloc scheduleBloc;
  late _FakeReconcileAlarmsUseCase reconcileAlarmsUseCase;

  AuthBloc buildBloc() {
    return AuthBloc(
      streamUserUseCase,
      signOutUseCase,
      loadUserUseCase,
      scheduleBloc,
      reconcileAlarmsUseCase,
    );
  }

  setUp(() {
    userController = StreamController<UserEntity>.broadcast();
    streamUserUseCase = _FakeStreamUserUseCase(userController.stream);
    loadUserUseCase = _FakeLoadUserUseCase();
    signOutUseCase = _FakeSignOutUseCase();
    scheduleBloc = _FakeScheduleBloc();
    reconcileAlarmsUseCase = _FakeReconcileAlarmsUseCase();
  });

  tearDown(() async {
    await userController.close();
  });

  test(
    'authenticated users subscribe schedules and reconcile alarms',
    () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(const AuthUserSubscriptionRequested());
      await pumpEventQueue();
      userController.add(_user(isOnboardingCompleted: true));

      final authenticated = await bloc.stream.firstWhere(
        (state) => state.status == AuthStatus.authenticated,
      );
      await pumpEventQueue();

      expect(loadUserUseCase.callCount, 1);
      expect(authenticated.user, _user(isOnboardingCompleted: true));
      expect(scheduleBloc.addedEvents, [const ScheduleSubscriptionRequested()]);
      expect(reconcileAlarmsUseCase.callCount, 1);
    },
  );

  test('non-onboarded and empty users map to their auth statuses', () async {
    final bloc = buildBloc();
    addTearDown(bloc.close);

    bloc.add(const AuthUserSubscriptionRequested());
    await pumpEventQueue();
    userController.add(_user(isOnboardingCompleted: false));

    final onboardingState = await bloc.stream.firstWhere(
      (state) => state.status == AuthStatus.onboardingNotCompleted,
    );
    userController.add(const UserEntity.empty());
    final unauthenticatedState = await bloc.stream.firstWhere(
      (state) => state.status == AuthStatus.unauthenticated,
    );

    expect(onboardingState.user, _user(isOnboardingCompleted: false));
    expect(unauthenticatedState.user, const UserEntity.empty());
    expect(scheduleBloc.addedEvents, isEmpty);
    expect(reconcileAlarmsUseCase.callCount, 0);
  });

  test(
    'load failure emits empty unauthenticated user before listening',
    () async {
      loadUserUseCase.error = Exception('session expired');
      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(const AuthUserSubscriptionRequested());

      final state = await bloc.stream.firstWhere(
        (state) => state.status == AuthStatus.unauthenticated,
      );

      expect(state.user, const UserEntity.empty());
    },
  );

  test('sign out event delegates to sign out use case', () async {
    final bloc = buildBloc();
    addTearDown(bloc.close);

    bloc.add(const AuthSignOutPressed());
    await pumpEventQueue();

    expect(signOutUseCase.callCount, 1);
  });

  test('AuthState value helpers derive status from the user', () {
    final authenticated = AuthState(user: _user(isOnboardingCompleted: true));
    final onboarding = AuthState(user: _user(isOnboardingCompleted: false));
    final copied = authenticated.copyWith(status: AuthStatus.loading);

    expect(authenticated.status, AuthStatus.authenticated);
    expect(onboarding.status, AuthStatus.onboardingNotCompleted);
    expect(const AuthState.loading().status, AuthStatus.loading);
    expect(copied.status, AuthStatus.loading);
    expect(copied.user, authenticated.user);
  });
}

UserEntity _user({required bool isOnboardingCompleted}) {
  return UserEntity(
    id: 'user-1',
    email: 'user@example.com',
    name: 'User',
    spareTime: const Duration(minutes: 10),
    note: 'note',
    score: 4.5,
    isOnboardingCompleted: isOnboardingCompleted,
  );
}

class _FakeStreamUserUseCase implements StreamUserUseCase {
  _FakeStreamUserUseCase(this.stream);

  final Stream<UserEntity> stream;

  @override
  Stream<UserEntity> call() => stream;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeLoadUserUseCase implements LoadUserUseCase {
  int callCount = 0;
  Object? error;

  @override
  Future<void> call() async {
    callCount += 1;
    final nextError = error;
    if (nextError != null) {
      throw nextError;
    }
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSignOutUseCase implements SignOutUseCase {
  int callCount = 0;

  @override
  Future<void> call() async {
    callCount += 1;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeScheduleBloc implements ScheduleBloc {
  final addedEvents = <ScheduleEvent>[];

  @override
  void add(ScheduleEvent event) {
    addedEvents.add(event);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeReconcileAlarmsUseCase implements ReconcileAlarmsUseCase {
  int callCount = 0;

  @override
  Future<AlarmReconciliationResult> call() async {
    callCount += 1;
    final now = DateTime(2026, 5, 15);
    return AlarmReconciliationResult(
      status: AlarmReconciliationStatus.armed,
      nativeAlarmProvider: AlarmProvider.androidAlarmManager,
      fallbackProvider: AlarmProvider.localNotification,
      armedScheduleIds: const [],
      skippedScheduleCount: 0,
      failures: const [],
      scheduleWindowStart: now,
      scheduleWindowEnd: now.add(const Duration(days: 1)),
      alarmCoverageStart: now,
      alarmCoverageEnd: now.add(const Duration(hours: 1)),
    );
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
