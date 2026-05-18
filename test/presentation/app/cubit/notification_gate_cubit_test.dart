import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/services/notification_service.dart';
import 'package:on_time_front/presentation/app/cubit/notification_gate_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'authorized permission initializes notifications and allows app entry',
    () async {
      final service = _FakeNotificationService(
        permission: AuthorizationStatus.authorized,
      );
      final cubit = NotificationGateCubit(notificationService: service);
      addTearDown(cubit.close);

      await expectLater(
        cubit.stream,
        emits(const NotificationGateState.allowed()),
      );

      expect(cubit.state.isResolved, isTrue);
      expect(cubit.state.shouldPrompt, isFalse);
      expect(service.initializeCount, 1);
    },
  );

  test(
    'missing permission requires prompt when the prompt was not dismissed',
    () async {
      final service = _FakeNotificationService(
        permission: AuthorizationStatus.denied,
      );
      final cubit = NotificationGateCubit(notificationService: service);
      addTearDown(cubit.close);

      await expectLater(
        cubit.stream,
        emits(const NotificationGateState.required()),
      );

      expect(cubit.state.shouldPrompt, isTrue);
      expect(service.initializeCount, 0);
    },
  );

  test(
    'dismissed prompt remains dismissed without checking permission',
    () async {
      SharedPreferences.setMockInitialValues({
        'notification_prompt_dismissed': true,
      });
      final service = _FakeNotificationService(
        permission: AuthorizationStatus.authorized,
      );
      final cubit = NotificationGateCubit(notificationService: service);
      addTearDown(cubit.close);

      await expectLater(
        cubit.stream,
        emits(const NotificationGateState.dismissed()),
      );

      expect(service.checkCount, 0);
      expect(service.initializeCount, 0);
    },
  );

  test(
    'markPermissionAllowed clears dismissal and initializes notifications',
    () async {
      SharedPreferences.setMockInitialValues({
        'notification_prompt_dismissed': true,
      });
      final service = _FakeNotificationService();
      final cubit = NotificationGateCubit(notificationService: service);
      addTearDown(cubit.close);
      await expectLater(
        cubit.stream,
        emits(const NotificationGateState.dismissed()),
      );

      await cubit.markPermissionAllowed();

      final prefs = await SharedPreferences.getInstance();
      expect(cubit.state, const NotificationGateState.allowed());
      expect(prefs.getBool('notification_prompt_dismissed'), isNull);
      expect(service.initializeCount, 1);
    },
  );

  test(
    'dismissPrompt stores dismissal and resolves without prompting',
    () async {
      final service = _FakeNotificationService(
        permission: AuthorizationStatus.denied,
      );
      final cubit = NotificationGateCubit(notificationService: service);
      addTearDown(cubit.close);
      await expectLater(
        cubit.stream,
        emits(const NotificationGateState.required()),
      );

      await cubit.dismissPrompt();

      final prefs = await SharedPreferences.getInstance();
      expect(cubit.state, const NotificationGateState.dismissed());
      expect(prefs.getBool('notification_prompt_dismissed'), isTrue);
    },
  );

  test('initialization failure does not block an allowed gate state', () async {
    final service = _FakeNotificationService(
      permission: AuthorizationStatus.authorized,
      throwOnInitialize: true,
    );
    final cubit = NotificationGateCubit(notificationService: service);
    addTearDown(cubit.close);

    await expectLater(
      cubit.stream,
      emits(const NotificationGateState.allowed()),
    );

    expect(service.initializeCount, 1);
  });
}

class _FakeNotificationService implements NotificationService {
  _FakeNotificationService({
    this.permission = AuthorizationStatus.denied,
    this.throwOnInitialize = false,
  });

  final AuthorizationStatus permission;
  final bool throwOnInitialize;
  int checkCount = 0;
  int initializeCount = 0;

  @override
  Future<AuthorizationStatus> checkNotificationPermission() async {
    checkCount += 1;
    return permission;
  }

  @override
  Future<void> initialize() async {
    initializeCount += 1;
    if (throwOnInitialize) {
      throw Exception('notification setup failed');
    }
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
