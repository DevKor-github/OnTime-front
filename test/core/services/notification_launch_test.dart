import 'package:on_time_front/core/services/navigation_service.dart';
import 'package:on_time_front/domain/use-cases/schedule_preparation_session_use_case.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/services/notification_service.dart';
import 'package:on_time_front/core/services/notification_tap_router.dart';
import 'notification_tap_router_test.dart' show tapPayload, tapSchedule;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Plugin plugin;
  late _Router router;
  late NotificationService service;
  setUp(() {
    plugin = _Plugin();
    router = _Router();
    service = NotificationService.test(
      localNotifications: plugin,
      notificationTapRouter: router,
      isTimezoneInitialized: true,
    );
  });

  test(
    'cold launch collects once and concurrent initialization is single flight',
    () async {
      final initial = Completer<NotificationAppLaunchDetails?>();
      plugin.result = () => initial.future;
      final calls = [
        service.initialize(),
        service.initialize(),
        service.collectInitialLaunch(),
      ];
      await pumpEventQueue();
      expect(plugin.initializes, 1);
      expect(plugin.reads, 1);
      initial.complete(_details('A'));
      await Future.wait(calls);
      await service.initialize();
      await service.collectInitialLaunch();
      expect(plugin.reads, 1);
      expect(router.payloads, hasLength(1));
      expect(jsonDecode(router.payloads.single!)['scheduleId'], 'A');
    },
  );

  for (final details in [
    null,
    const NotificationAppLaunchDetails(false),
    const NotificationAppLaunchDetails(
      true,
      notificationResponse: NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: 'bad',
      ),
    ),
  ]) {
    test(
      'successful empty or invalid launch is consumed without navigation: $details',
      () async {
        plugin.result = () async => details;
        await service.collectInitialLaunch();
        await service.collectInitialLaunch();
        expect(plugin.reads, 1);
        expect(router.payloads, isEmpty);
      },
    );
  }

  test(
    'getter failure releases single flight and callback still works before retry',
    () async {
      plugin.result = () async =>
          throw PlatformException(code: 'temporarily-unavailable');
      await Future.wait([
        service.collectInitialLaunch(),
        service.collectInitialLaunch(),
      ]);
      expect(plugin.reads, 1);
      plugin.tap('B');
      expect(router.payloads, hasLength(1));
      plugin.result = () async => null;
      await service.collectInitialLaunch();
      await service.collectInitialLaunch();
      expect(plugin.reads, 2);
      expect(router.payloads, hasLength(1));
    },
  );

  test(
    'callback B arriving while cold A getter waits wins, raw legacy fields removed',
    () async {
      final initial = Completer<NotificationAppLaunchDetails?>();
      plugin.result = () => initial.future;
      final collecting = service.collectInitialLaunch();
      await pumpEventQueue();
      plugin.callback!(
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload:
              '{"type":"schedule_notification","scheduleId":"B","scheduleFingerprint":"SECRET","alarmLaunchAction":"startPreparation"}',
        ),
      );
      initial.complete(_details('A'));
      await collecting;
      expect(router.payloads, hasLength(1));
      expect(router.payloads.single, isNot(contains('SECRET')));
      expect(router.payloads.single, isNot(contains('startPreparation')));
      expect(jsonDecode(router.payloads.single!)['scheduleId'], 'B');
    },
  );

  test(
    'callback before delegate installation preserves only safe latest payload',
    () async {
      service = NotificationService.test(
        localNotifications: plugin,
        isTimezoneInitialized: true,
      );
      await service.setupFlutterNotifications();
      plugin.tap('A');
      plugin.tap('B');
      plugin.callback!(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: 'bad',
        ),
      );
      service.configureDelegate(notificationTapRouter: router);
      expect(router.payloads, hasLength(1));
      expect(jsonDecode(router.payloads.single!)['scheduleId'], 'B');
    },
  );

  test(
    'Noop to installed delegate cannot let slow cold A overwrite native B',
    () async {
      final initial = Completer<NotificationAppLaunchDetails?>();
      plugin.result = () => initial.future;
      service = NotificationService.test(
        localNotifications: plugin,
        isTimezoneInitialized: true,
      );
      final collecting = service.collectInitialLaunch();
      await pumpEventQueue();
      final navigation = _Navigation();
      final installed = NavigationNotificationTapRouter(navigation);
      installed.configure(
        isReady: () => true,
        resolve: (id, current) async =>
            SchedulePreparationPromptResult.ready(tapSchedule(id)),
      );
      service.configureDelegate(notificationTapRouter: installed);
      installed.routeNativeNotificationTap({
        'type': 'schedule_alarm',
        'scheduleId': 'B',
      });
      initial.complete(_details('A'));
      await collecting;
      await pumpEventQueue();
      expect(navigation.ids, ['B']);
      installed.detach();
    },
  );

  test('data replacement invalidates delayed initial launch', () async {
    final initial = Completer<NotificationAppLaunchDetails?>();
    plugin.result = () => initial.future;
    final collecting = service.collectInitialLaunch();
    await pumpEventQueue();
    await LocalDataOperationGate.shared.run(() async {}, replacesData: true);
    initial.complete(_details('A'));
    await collecting;
    expect(router.payloads, isEmpty);
  });
}

NotificationAppLaunchDetails _details(String id) =>
    NotificationAppLaunchDetails(
      true,
      notificationResponse: NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        id: 42,
        payload: tapPayload(id),
      ),
    );

class _Router implements NotificationTapRouter {
  final payloads = <String?>[];
  @override
  void routeLocalNotificationTap(String? payload) => payloads.add(payload);
}

class _Plugin implements FlutterLocalNotificationsPlugin {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  int initializes = 0, reads = 0;
  DidReceiveNotificationResponseCallback? callback;
  Future<NotificationAppLaunchDetails?> Function() result = () async => null;
  @override
  T? resolvePlatformSpecificImplementation<
    T extends FlutterLocalNotificationsPlatform
  >() => null;
  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    initializes++;
    callback = onDidReceiveNotificationResponse;
    return true;
  }

  @override
  Future<NotificationAppLaunchDetails?> getNotificationAppLaunchDetails() {
    reads++;
    return result();
  }

  void tap(String id) => callback!(
    NotificationResponse(
      notificationResponseType: NotificationResponseType.selectedNotification,
      payload: tapPayload(id),
    ),
  );
}

class _Navigation extends NavigationService {
  final ids = <String>[];
  @override
  void push(String routeName, {Object? extra}) {
    ids.add((extra as NotificationPromptRouteData).schedule.id);
  }
}
