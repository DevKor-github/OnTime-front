import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/core/services/notification_service.dart';
import 'package:drift/native.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/constants/local_profile.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const notifications = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const permissions = MethodChannel('flutter.baseflow.com/permissions/methods');
  final calls = <MethodCall>[];
  final permissionCalls = <String>[];
  late AppDatabase database;
  late LocalDataOperationGate gate;
  late AlarmOperationCoordinator owner;
  late NotificationService service;
  var displayAllowed = true, permissionFailure = false, showFailure = false;
  var current = true;
  var locale = 'en';
  Completer<void>? permissionBarrier, setupBarrier, showBarrier;
  setUp(() async {
    calls.clear();
    permissionCalls.clear();
    displayAllowed = true;
    permissionFailure = false;
    showFailure = false;
    current = true;
    locale = 'en';
    permissionBarrier = null;
    setupBarrier = null;
    showBarrier = null;
    gate = LocalDataOperationGate();
    owner = AlarmOperationCoordinator(gate);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.userDao.createUser(
      const UserEntity(
        id: localProfileId,
        spareTime: Duration.zero,
        note: '',
        eligibleOutcomeCount: 0,
        onTimeOutcomeCount: 0,
      ),
    );
    await database.userDao.updateAlarmSettings(
      userId: localProfileId,
      enabled: false,
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(permissions, (call) async {
      permissionCalls.add(call.method);
      await permissionBarrier?.future;
      if (permissionFailure) throw PlatformException(code: 'query_unavailable');
      return displayAllowed ? 1 : 0;
    });
    messenger.setMockMethodCallHandler(notifications, (call) async {
      calls.add(call);
      if (call.method == 'initialize') {
        await setupBarrier?.future;
        return true;
      }
      if (call.method == 'show') {
        await showBarrier?.future;
        if (showFailure) throw PlatformException(code: 'synthetic_failure');
      }
      return null;
    });
    service = NotificationService.test(
      localNotifications: FlutterLocalNotificationsPlugin(),
      isAndroidOverride: true,
      isIOSOverride: false,
      isFlutterLocalNotificationsInitialized: true,
      alarmOwner: owner,
      localeProvider: () => locale,
    );
  });
  tearDown(() async {
    await database.close();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    debugDefaultTargetPlatformOverride = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(permissions, null);
    messenger.setMockMethodCallHandler(notifications, null);
    owner.dispose();
  });
  Future<void> show() => service.showPreparationStepNotification(
    scheduleName: 'SECRET schedule',
    preparationName: 'SECRET step',
    scheduleId: 'occurrence',
    stepId: 'step',
    isCurrent: () => current,
  );
  List<MethodCall> submissions() =>
      calls.where((c) => c.method == 'show').toList();

  for (final language in ['ko', 'en']) {
    for (final detailed in [false, true]) {
      test(
        '$language detailed=$detailed retains private text/minimum payload while upcoming OFF',
        () async {
          locale = language;
          // These preferences may control future start alarms, never this active run.
          await database.userDao.updateDetailedNotificationContent(
            userId: localProfileId,
            enabled: detailed,
          );
          final settings = await database.userDao.getAlarmSettings(
            localProfileId,
          );
          expect(settings.enabled, isFalse);
          expect(settings.detailedNotificationContent, detailed);
          await show();
          final args = submissions().single.arguments as Map;
          expect(
            args['title'],
            language == 'ko' ? '준비 단계가 바뀌었어요' : 'Preparation updated',
          );
          expect(
            args['body'],
            language == 'ko'
                ? 'OnTime을 열어 다음 단계를 확인하세요.'
                : 'Open OnTime to see the next step.',
          );
          expect(jsonDecode(args['payload'] as String), {
            'type': 'preparation_step',
            'scheduleId': 'occurrence',
            'stepId': 'step',
          });
          expect(args.toString(), isNot(contains('SECRET')));
          expect(permissionCalls, ['checkPermissionStatus']);
        },
      );
    }
  }
  test('display denied skips show without permission prompt', () async {
    displayAllowed = false;
    await show();
    expect(submissions(), isEmpty);
    expect(permissionCalls, ['checkPermissionStatus']);
  });
  test(
    'permission query error propagates to the observed caller, no show',
    () async {
      permissionFailure = true;
      await expectLater(show(), throwsA(isA<PlatformException>()));
      expect(submissions(), isEmpty);
      expect(permissionCalls, ['checkPermissionStatus']);
    },
  );
  for (final phase in [
    AppLifecycleState.resumed,
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.detached,
  ]) {
    test('$phase never queries or submits', () async {
      binding.handleAppLifecycleStateChanged(phase);
      await show();
      expect(submissions(), isEmpty);
      expect(permissionCalls, isEmpty);
    });
  }
  for (final interruption in ['session', 'resume', 'replacement']) {
    test('permission await rechecks $interruption before show', () async {
      permissionBarrier = Completer<void>();
      final pending = show();
      await pumpEventQueue();
      expect(permissionCalls, ['checkPermissionStatus']);
      switch (interruption) {
        case 'session':
          current = false;
        case 'resume':
          binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        case 'replacement':
          await gate.run(() async {}, replacesData: true);
      }
      permissionBarrier!.complete();
      await pending;
      expect(submissions(), isEmpty);
    });
  }
  test(
    'setup await rechecks validity immediately before plugin submission',
    () async {
      setupBarrier = Completer<void>();
      service = NotificationService.test(
        localNotifications: FlutterLocalNotificationsPlugin(),
        isAndroidOverride: true,
        isIOSOverride: false,
        alarmOwner: owner,
      );
      final pending = show();
      await pumpEventQueue();
      expect(calls.any((c) => c.method == 'initialize'), isTrue);
      current = false;
      setupBarrier!.complete();
      await pending;
      expect(submissions(), isEmpty);
      final args =
          calls.singleWhere((c) => c.method == 'initialize').arguments as Map;
      // iOS initialization never implicitly asks for authorization either.
      expect(args.toString(), isNot(contains('requestAlertPermission: true')));
    },
  );
  test(
    'show failure propagates without releasing owner early or unhandled error',
    () async {
      showFailure = true;
      await expectLater(show(), throwsA(isA<PlatformException>()));
      expect(submissions(), hasLength(1));
      var cleaned = false;
      await owner.cleanup(() async {
        cleaned = true;
      });
      expect(cleaned, isTrue);
    },
  );
  test(
    'reset cleanup waits for actual in-flight plugin effect, then cancels',
    () async {
      showBarrier = Completer<void>();
      final pending = show();
      await pumpEventQueue();
      expect(submissions(), hasLength(1));
      gate.invalidate();
      var cleaned = false;
      final cleanup = owner.cleanup(() async {
        await service.cancelAll();
        cleaned = true;
      });
      await pumpEventQueue();
      expect(cleaned, isFalse);
      expect(calls.where((c) => c.method == 'cancelAll'), isEmpty);
      showBarrier!.complete();
      await pending;
      await cleanup;
      expect(cleaned, isTrue);
      expect(
        calls
            .map((c) => c.method)
            .where((m) => m == 'show' || m == 'cancelAll'),
        ['show', 'cancelAll'],
      );
    },
  );
  test(
    'queued old-generation step is rejected before any platform call',
    () async {
      final hold = Completer<void>();
      final preceding = owner.cleanup(() => hold.future);
      final pending = show();
      final expectation = expectLater(
        pending,
        throwsA(isA<AlarmOperationInvalidated>()),
      );
      await pumpEventQueue();
      gate.invalidate();
      hold.complete();
      await preceding;
      await expectation;
      expect(submissions(), isEmpty);
      expect(permissionCalls, isEmpty);
    },
  );
}
