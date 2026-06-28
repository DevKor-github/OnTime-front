import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/services/notification_service.dart';
import 'package:on_time_front/core/services/notification_tap_router.dart';
import 'package:on_time_front/core/services/notification_token_registrar.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'hasNotificationPermission accepts authorized and provisional states',
    () async {
      final messaging = _FakeFirebaseMessaging(AuthorizationStatus.authorized);
      final localNotifications = _RecordingLocalNotifications();

      final service = NotificationService.test(
        messaging: messaging,
        localNotifications: localNotifications,
        isFlutterLocalNotificationsInitialized: true,
      );

      expect(await service.hasNotificationPermission(), isTrue);

      messaging.authorizationStatus = AuthorizationStatus.provisional;
      expect(await service.hasNotificationPermission(), isTrue);

      messaging.authorizationStatus = AuthorizationStatus.denied;
      expect(await service.hasNotificationPermission(), isFalse);
    },
  );

  test('requestPermission delegates to messaging on mobile targets', () async {
    final messaging = _FakeFirebaseMessaging(AuthorizationStatus.notDetermined)
      ..requestedAuthorizationStatus = AuthorizationStatus.authorized;
    final service = NotificationService.test(
      messaging: messaging,
      localNotifications: _RecordingLocalNotifications(),
      isFlutterLocalNotificationsInitialized: true,
    );

    expect(await service.requestPermission(), AuthorizationStatus.authorized);
    expect(messaging.requestPermissionCount, 1);
  });

  test('iOS permission checks use local notification permission', () async {
    final messaging = _FakeFirebaseMessaging(AuthorizationStatus.authorized);
    final iosPlugin = _FakeIOSLocalNotificationsPlugin(
      permissionsEnabled: false,
    );
    final service = NotificationService.test(
      messaging: messaging,
      localNotifications: _RecordingLocalNotifications(iosPlugin: iosPlugin),
      isFlutterLocalNotificationsInitialized: true,
      isIOSOverride: true,
    );

    expect(
      await service.checkNotificationPermission(),
      AuthorizationStatus.denied,
    );
    expect(iosPlugin.checkPermissionsCount, 1);
  });

  test('iOS permission requests ask local notification plugin too', () async {
    final messaging = _FakeFirebaseMessaging(AuthorizationStatus.notDetermined)
      ..requestedAuthorizationStatus = AuthorizationStatus.authorized;
    final iosPlugin = _FakeIOSLocalNotificationsPlugin(
      requestPermissionsResult: true,
    );
    final service = NotificationService.test(
      messaging: messaging,
      localNotifications: _RecordingLocalNotifications(iosPlugin: iosPlugin),
      isFlutterLocalNotificationsInitialized: true,
      isIOSOverride: true,
    );

    expect(await service.requestPermission(), AuthorizationStatus.authorized);
    expect(messaging.requestPermissionCount, 1);
    expect(iosPlugin.requestPermissionsCount, 1);
    expect(iosPlugin.lastRequestedAlert, isTrue);
    expect(iosPlugin.lastRequestedBadge, isTrue);
    expect(iosPlugin.lastRequestedSound, isTrue);
  });

  test(
    'initialize requests permission, sets up local notifications, and routes initial messages',
    () async {
      final messaging =
          _FakeFirebaseMessaging(AuthorizationStatus.notDetermined)
            ..requestedAuthorizationStatus = AuthorizationStatus.authorized
            ..initialMessage = const RemoteMessage(
              data: {'type': 'preparation_step', 'scheduleId': 'schedule-1'},
            );
      final localNotifications = _RecordingLocalNotifications();
      final tapRouter = _FakeNotificationTapRouter();
      const firebaseMessagingChannel = MethodChannel(
        'plugins.flutter.io/firebase_messaging',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            firebaseMessagingChannel,
            (_) async => null,
          );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(firebaseMessagingChannel, null);
      });
      final service = NotificationService.test(
        messaging: messaging,
        localNotifications: localNotifications,
        notificationTapRouter: tapRouter,
      );

      await service.initialize();

      expect(messaging.requestPermissionCount, 1);
      expect(messaging.getTokenCount, 1);
      expect(messaging.getInitialMessageCount, 1);
      expect(localNotifications.initializeCount, 1);
      expect(tapRouter.remoteMessageData.single['scheduleId'], 'schedule-1');
    },
  );

  test(
    'repeated initialize handles each notification entry point once',
    () async {
      final messaging =
          _FakeFirebaseMessaging(AuthorizationStatus.notDetermined)
            ..requestedAuthorizationStatus = AuthorizationStatus.authorized
            ..initialMessage = const RemoteMessage(
              data: {'type': 'preparation_step', 'scheduleId': 'initial'},
            );
      final localNotifications = _RecordingLocalNotifications();
      final tapRouter = _FakeNotificationTapRouter();
      final foregroundMessages = StreamController<RemoteMessage>.broadcast();
      final openedAppMessages = StreamController<RemoteMessage>.broadcast();
      const firebaseMessagingChannel = MethodChannel(
        'plugins.flutter.io/firebase_messaging',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            firebaseMessagingChannel,
            (_) async => null,
          );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(firebaseMessagingChannel, null);
        foregroundMessages.close();
        openedAppMessages.close();
      });
      final service = NotificationService.test(
        messaging: messaging,
        localNotifications: localNotifications,
        notificationTapRouter: tapRouter,
        onMessage: foregroundMessages.stream,
        onMessageOpenedApp: openedAppMessages.stream,
      );

      await service.initialize();
      await service.initialize();

      foregroundMessages.add(
        const RemoteMessage(data: {'title': 'Title', 'body': 'Body'}),
      );
      openedAppMessages.add(
        const RemoteMessage(
          data: {'type': 'preparation_step', 'scheduleId': 'opened'},
        ),
      );
      await pumpEventQueue();

      expect(messaging.getInitialMessageCount, 1);
      expect(localNotifications.shown, hasLength(1));
      expect(tapRouter.remoteMessageData.map((data) => data['scheduleId']), [
        'initial',
        'opened',
      ]);
    },
  );

  test('concurrent initialize shares one in-flight setup', () async {
    final permissionBlocker = Completer<void>();
    final messaging = _FakeFirebaseMessaging(AuthorizationStatus.notDetermined)
      ..requestedAuthorizationStatus = AuthorizationStatus.authorized
      ..requestPermissionBlocker = permissionBlocker
      ..token = 'fcm-token';
    final localNotifications = _RecordingLocalNotifications();
    final tokenRegistrar = _FakeFcmTokenRegistrar();
    const firebaseMessagingChannel = MethodChannel(
      'plugins.flutter.io/firebase_messaging',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(firebaseMessagingChannel, (_) async => null);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(firebaseMessagingChannel, null);
    });
    final service = NotificationService.test(
      messaging: messaging,
      localNotifications: localNotifications,
      fcmTokenRegistrar: tokenRegistrar,
    );

    final firstInitialize = service.initialize();
    await pumpEventQueue();
    final secondInitialize = service.initialize();

    permissionBlocker.complete();
    await Future.wait([firstInitialize, secondInitialize]);

    expect(messaging.requestPermissionCount, 1);
    expect(messaging.getInitialMessageCount, 1);
    expect(localNotifications.initializeCount, 1);
    expect(tokenRegistrar.registeredTokens, ['fcm-token']);
  });

  test(
    'openNotificationSettings returns false when platform launch fails',
    () async {
      final service = NotificationService.test(
        messaging: _FakeFirebaseMessaging(AuthorizationStatus.denied),
        localNotifications: _RecordingLocalNotifications(),
        isFlutterLocalNotificationsInitialized: true,
      );

      expect(await service.openNotificationSettings(), isFalse);
    },
  );

  test('requestNotificationToken tolerates missing FCM token', () async {
    final messaging = _FakeFirebaseMessaging(AuthorizationStatus.authorized);
    final service = NotificationService.test(
      messaging: messaging,
      localNotifications: _RecordingLocalNotifications(),
      isFlutterLocalNotificationsInitialized: true,
    );

    await service.requestNotificationToken();

    expect(messaging.getTokenCount, 1);
    expect(messaging.tokenRefreshListened, isTrue);
  });

  test('requestNotificationToken delegates FCM token registration', () async {
    final messaging = _FakeFirebaseMessaging(AuthorizationStatus.authorized)
      ..token = 'fcm-token';
    final tokenRegistrar = _FakeFcmTokenRegistrar();
    final service = NotificationService.test(
      messaging: messaging,
      localNotifications: _RecordingLocalNotifications(),
      isFlutterLocalNotificationsInitialized: true,
      fcmTokenRegistrar: tokenRegistrar,
    );

    await service.requestNotificationToken();

    expect(tokenRegistrar.registeredTokens, ['fcm-token']);
  });

  test(
    'token refreshes register the refreshed token for this device',
    () async {
      final messaging = _FakeFirebaseMessaging(AuthorizationStatus.authorized)
        ..token = 'initial-token';
      final tokenRegistrar = _FakeFcmTokenRegistrar();
      final service = NotificationService.test(
        messaging: messaging,
        localNotifications: _RecordingLocalNotifications(),
        isFlutterLocalNotificationsInitialized: true,
        fcmTokenRegistrar: tokenRegistrar,
      );

      await service.requestNotificationToken();
      messaging.emitTokenRefresh('refreshed-token');
      await pumpEventQueue();

      expect(tokenRegistrar.registeredTokens, [
        'initial-token',
        'refreshed-token',
      ]);
    },
  );

  test(
    'repeated token requests keep one refresh registration callback',
    () async {
      final messaging = _FakeFirebaseMessaging(AuthorizationStatus.authorized)
        ..token = 'initial-token';
      final tokenRegistrar = _FakeFcmTokenRegistrar();
      final service = NotificationService.test(
        messaging: messaging,
        localNotifications: _RecordingLocalNotifications(),
        isFlutterLocalNotificationsInitialized: true,
        fcmTokenRegistrar: tokenRegistrar,
      );

      await service.requestNotificationToken();
      await service.requestNotificationToken();
      messaging.emitTokenRefresh('refreshed-token');
      await pumpEventQueue();

      expect(tokenRegistrar.registeredTokens, [
        'initial-token',
        'initial-token',
        'refreshed-token',
      ]);
    },
  );

  test(
    'setupFlutterNotifications initializes local notifications once',
    () async {
      final localNotifications = _RecordingLocalNotifications();
      final service = NotificationService.test(
        messaging: _FakeFirebaseMessaging(AuthorizationStatus.authorized),
        localNotifications: localNotifications,
      );

      await service.setupFlutterNotifications();
      await service.setupFlutterNotifications();

      expect(localNotifications.initializeCount, 1);
    },
  );

  test(
    'local notification taps are delegated to the notification tap router',
    () async {
      final localNotifications = _RecordingLocalNotifications();
      final tapRouter = _FakeNotificationTapRouter();
      final service = NotificationService.test(
        messaging: _FakeFirebaseMessaging(AuthorizationStatus.authorized),
        localNotifications: localNotifications,
        notificationTapRouter: tapRouter,
      );

      await service.setupFlutterNotifications();
      localNotifications.tapPayload(
        '{"type":"preparation_step","scheduleId":"schedule-1"}',
      );
      localNotifications.tapPayload('not-json');

      expect(tapRouter.localPayloads, [
        '{"type":"preparation_step","scheduleId":"schedule-1"}',
        'not-json',
      ]);
    },
  );

  test('showLocalNotification displays encoded non-alarm payloads', () async {
    final localNotifications = _RecordingLocalNotifications();
    final service = NotificationService.test(
      messaging: _FakeFirebaseMessaging(AuthorizationStatus.authorized),
      localNotifications: localNotifications,
      isFlutterLocalNotificationsInitialized: true,
    );

    await service.showLocalNotification(
      title: 'Reminder',
      body: 'Leave soon',
      payload: const {'type': 'info', 'scheduleId': 'schedule-1'},
    );

    expect(localNotifications.shown, hasLength(1));
    expect(localNotifications.shown.single.title, 'Reminder');
    expect(localNotifications.shown.single.body, 'Leave soon');
    expect(localNotifications.shown.single.payload, contains('schedule-1'));
  });

  test('showLocalNotification suppresses schedule alarm payloads', () async {
    final localNotifications = _RecordingLocalNotifications();
    final service = NotificationService.test(
      messaging: _FakeFirebaseMessaging(AuthorizationStatus.authorized),
      localNotifications: localNotifications,
      isFlutterLocalNotificationsInitialized: true,
    );

    await service.showLocalNotification(
      title: 'Alarm',
      body: 'Start preparing',
      payload: const {'type': 'schedule_alarm'},
    );

    expect(localNotifications.shown, isEmpty);
  });

  test('showLocalNotification ignores setup and display failures', () async {
    final setupFailureNotifications = _RecordingLocalNotifications()
      ..throwOnInitialize = true;
    final setupFailureService = NotificationService.test(
      messaging: _FakeFirebaseMessaging(AuthorizationStatus.authorized),
      localNotifications: setupFailureNotifications,
    );

    await setupFailureService.showLocalNotification(
      title: 'Reminder',
      body: 'Leave soon',
    );

    expect(setupFailureNotifications.shown, isEmpty);

    final displayFailureNotifications = _RecordingLocalNotifications()
      ..throwOnShow = true;
    final displayFailureService = NotificationService.test(
      messaging: _FakeFirebaseMessaging(AuthorizationStatus.authorized),
      localNotifications: displayFailureNotifications,
      isFlutterLocalNotificationsInitialized: true,
    );

    await displayFailureService.showLocalNotification(
      title: 'Reminder',
      body: 'Leave soon',
    );

    expect(displayFailureNotifications.showAttempts, 1);
    expect(displayFailureNotifications.shown, isEmpty);
  });

  test(
    'preparation step notifications include schedule and step payload',
    () async {
      final localNotifications = _RecordingLocalNotifications();
      final service = NotificationService.test(
        messaging: _FakeFirebaseMessaging(AuthorizationStatus.authorized),
        localNotifications: localNotifications,
        isFlutterLocalNotificationsInitialized: true,
      );

      await service.showPreparationStepNotification(
        scheduleName: 'Morning meeting',
        preparationName: 'Pack',
        scheduleId: 'schedule-1',
        stepId: 'step-1',
      );

      expect(localNotifications.shown, hasLength(1));
      expect(localNotifications.shown.single.title, contains('Pack'));
      expect(localNotifications.shown.single.payload, contains('schedule-1'));
      expect(localNotifications.shown.single.payload, contains('step-1'));
    },
  );

  test('preparation step notifications are skipped in foreground', () async {
    final localNotifications = _RecordingLocalNotifications();
    final service = NotificationService.test(
      messaging: _FakeFirebaseMessaging(AuthorizationStatus.authorized),
      localNotifications: localNotifications,
      isFlutterLocalNotificationsInitialized: true,
    );

    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
    await service.showPreparationStepNotification(
      scheduleName: 'Morning meeting',
      preparationName: 'Pack',
      scheduleId: 'schedule-1',
      stepId: 'step-1',
    );

    expect(localNotifications.shown, isEmpty);
  });

  test(
    'remote notifications prefer displayable content and skip alarm pushes',
    () async {
      final localNotifications = _RecordingLocalNotifications();
      final service = NotificationService.test(
        messaging: _FakeFirebaseMessaging(AuthorizationStatus.authorized),
        localNotifications: localNotifications,
        isFlutterLocalNotificationsInitialized: true,
      );

      await service.showNotification(
        const RemoteMessage(
          data: {
            'title': 'Backend title',
            'body': 'Backend body',
            'route': '/calendar',
          },
        ),
      );
      await service.showNotification(
        const RemoteMessage(data: {'type': 'schedule_alarm'}),
      );
      await service.showNotification(const RemoteMessage(data: {}));

      expect(localNotifications.shown, hasLength(1));
      expect(localNotifications.shown.single.title, 'Backend title');
      expect(localNotifications.shown.single.body, 'Backend body');
    },
  );

  test('remote notifications ignore setup and display failures', () async {
    final setupFailureNotifications = _RecordingLocalNotifications()
      ..throwOnInitialize = true;
    final setupFailureService = NotificationService.test(
      messaging: _FakeFirebaseMessaging(AuthorizationStatus.authorized),
      localNotifications: setupFailureNotifications,
    );

    await setupFailureService.showNotification(
      const RemoteMessage(data: {'title': 'Title', 'body': 'Body'}),
    );

    expect(setupFailureNotifications.shown, isEmpty);

    final displayFailureNotifications = _RecordingLocalNotifications()
      ..throwOnShow = true;
    final displayFailureService = NotificationService.test(
      messaging: _FakeFirebaseMessaging(AuthorizationStatus.authorized),
      localNotifications: displayFailureNotifications,
      isFlutterLocalNotificationsInitialized: true,
    );

    await displayFailureService.showNotification(
      const RemoteMessage(data: {'title': 'Title', 'body': 'Body'}),
    );

    expect(displayFailureNotifications.showAttempts, 1);
    expect(displayFailureNotifications.shown, isEmpty);
  });

  test('fallback alarm scheduling requires notification permission', () async {
    final messaging = _FakeFirebaseMessaging(AuthorizationStatus.denied);
    final service = NotificationService.test(
      messaging: messaging,
      localNotifications: _RecordingLocalNotifications(),
      isFlutterLocalNotificationsInitialized: true,
    );

    await expectLater(
      service.scheduleFallbackAlarm(_record()),
      throwsA(
        isA<AlarmSchedulingException>().having(
          (error) => error.permissionIssue,
          'permissionIssue',
          AlarmPermissionIssue.notificationPermissionDenied,
        ),
      ),
    );
  });

  test(
    'fallback alarms schedule and cancel by stable notification id',
    () async {
      final messaging = _FakeFirebaseMessaging(AuthorizationStatus.authorized);
      final localNotifications = _RecordingLocalNotifications();
      final service = NotificationService.test(
        messaging: messaging,
        localNotifications: localNotifications,
        localeProvider: () => 'en',
        isFlutterLocalNotificationsInitialized: true,
      );
      final record = _record(fallbackNotificationId: null);

      await service.scheduleFallbackAlarm(record);
      await service.cancelFallbackNotification(
        stableAlarmId(record.scheduleId),
      );

      expect(localNotifications.scheduled, hasLength(1));
      expect(
        localNotifications.scheduled.single.id,
        stableAlarmId('schedule-1'),
      );
      expect(localNotifications.scheduled.single.title, 'Morning meeting');
      expect(
        localNotifications.scheduled.single.body,
        contains('time to get ready'),
      );
      expect(
        localNotifications
            .scheduled
            .single
            .notificationDetails
            .iOS
            ?.interruptionLevel,
        InterruptionLevel.timeSensitive,
      );
      expect(localNotifications.cancelledIds, [stableAlarmId('schedule-1')]);
    },
  );
}

NotificationSettings _settings(AuthorizationStatus status) {
  return NotificationSettings(
    alert: AppleNotificationSetting.enabled,
    announcement: AppleNotificationSetting.disabled,
    authorizationStatus: status,
    badge: AppleNotificationSetting.enabled,
    carPlay: AppleNotificationSetting.disabled,
    lockScreen: AppleNotificationSetting.enabled,
    notificationCenter: AppleNotificationSetting.enabled,
    showPreviews: AppleShowPreviewSetting.always,
    timeSensitive: AppleNotificationSetting.disabled,
    criticalAlert: AppleNotificationSetting.disabled,
    sound: AppleNotificationSetting.enabled,
    providesAppNotificationSettings: AppleNotificationSetting.disabled,
  );
}

ScheduledAlarmRecord _record({int? fallbackNotificationId = 42}) {
  return ScheduledAlarmRecord(
    scheduleId: 'schedule-1',
    alarmTime: DateTime.utc(2026, 5, 15, 8),
    preparationStartTime: DateTime.utc(2026, 5, 15, 8, 5),
    scheduleFingerprint: 'fingerprint',
    provider: AlarmProvider.localNotification,
    scheduleTitle: 'Morning meeting',
    payload: const {'type': 'schedule_alarm', 'scheduleId': 'schedule-1'},
    fallbackNotificationId: fallbackNotificationId,
  );
}

class _FakeFirebaseMessaging implements FirebaseMessaging {
  _FakeFirebaseMessaging(this.authorizationStatus);

  final _tokenRefreshController = StreamController<String>.broadcast();
  AuthorizationStatus authorizationStatus;
  AuthorizationStatus requestedAuthorizationStatus =
      AuthorizationStatus.authorized;
  Completer<void>? requestPermissionBlocker;
  int requestPermissionCount = 0;
  int getTokenCount = 0;
  int getInitialMessageCount = 0;
  bool tokenRefreshListened = false;
  String? token;
  RemoteMessage? initialMessage;

  @override
  Future<NotificationSettings> getNotificationSettings() async {
    return _settings(authorizationStatus);
  }

  @override
  Future<NotificationSettings> requestPermission({
    bool alert = true,
    bool announcement = false,
    bool badge = true,
    bool carPlay = false,
    bool criticalAlert = false,
    bool provisional = false,
    bool sound = true,
    bool providesAppNotificationSettings = false,
  }) async {
    requestPermissionCount += 1;
    authorizationStatus = requestedAuthorizationStatus;
    await requestPermissionBlocker?.future;
    return _settings(authorizationStatus);
  }

  @override
  Future<String?> getToken({
    String? serviceWorkerScriptPath,
    String? vapidKey,
  }) async {
    getTokenCount += 1;
    return token;
  }

  @override
  Future<RemoteMessage?> getInitialMessage() async {
    getInitialMessageCount += 1;
    return initialMessage;
  }

  @override
  Stream<String> get onTokenRefresh {
    tokenRefreshListened = true;
    return _tokenRefreshController.stream;
  }

  void emitTokenRefresh(String token) {
    _tokenRefreshController.add(token);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ShownNotification {
  const _ShownNotification(this.title, this.body, this.payload);

  final String? title;
  final String? body;
  final String? payload;
}

class _ScheduledNotification {
  const _ScheduledNotification(
    this.id,
    this.title,
    this.body,
    this.scheduledDate,
    this.notificationDetails,
  );

  final int id;
  final String? title;
  final String? body;
  final tz.TZDateTime scheduledDate;
  final NotificationDetails notificationDetails;
}

class _RecordingLocalNotifications implements FlutterLocalNotificationsPlugin {
  _RecordingLocalNotifications({this.iosPlugin});

  final _FakeIOSLocalNotificationsPlugin? iosPlugin;
  final shown = <_ShownNotification>[];
  final scheduled = <_ScheduledNotification>[];
  final cancelledIds = <int>[];
  int initializeCount = 0;
  int showAttempts = 0;
  bool throwOnInitialize = false;
  bool throwOnShow = false;
  DidReceiveNotificationResponseCallback? notificationResponseCallback;

  @override
  T? resolvePlatformSpecificImplementation<
    T extends FlutterLocalNotificationsPlatform
  >() {
    if (T == IOSFlutterLocalNotificationsPlugin) {
      return iosPlugin as T?;
    }
    return null;
  }

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    if (throwOnInitialize) {
      throw Exception('initialize failed');
    }
    notificationResponseCallback = onDidReceiveNotificationResponse;
    initializeCount += 1;
    return true;
  }

  void tapPayload(String? payload) {
    notificationResponseCallback?.call(
      NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: payload,
      ),
    );
  }

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails,
    String? payload,
  }) async {
    showAttempts += 1;
    if (throwOnShow) {
      throw Exception('show failed');
    }
    shown.add(_ShownNotification(title, body, payload));
  }

  @override
  Future<void> zonedSchedule({
    required int id,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? title,
    String? body,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    scheduled.add(
      _ScheduledNotification(
        id,
        title,
        body,
        scheduledDate,
        notificationDetails,
      ),
    );
  }

  @override
  Future<void> cancel({required int id, String? tag}) async {
    cancelledIds.add(id);
  }

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async {
    return [
      for (final notification in scheduled)
        PendingNotificationRequest(
          notification.id,
          notification.title,
          notification.body,
          null,
        ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeIOSLocalNotificationsPlugin
    extends IOSFlutterLocalNotificationsPlugin {
  _FakeIOSLocalNotificationsPlugin({
    this.permissionsEnabled = true,
    this.requestPermissionsResult,
  });

  bool permissionsEnabled;
  bool? requestPermissionsResult;
  int checkPermissionsCount = 0;
  int requestPermissionsCount = 0;
  bool? lastRequestedAlert;
  bool? lastRequestedBadge;
  bool? lastRequestedSound;

  @override
  Future<NotificationsEnabledOptions?> checkPermissions() async {
    checkPermissionsCount += 1;
    return NotificationsEnabledOptions(
      isEnabled: permissionsEnabled,
      isSoundEnabled: permissionsEnabled,
      isAlertEnabled: permissionsEnabled,
      isBadgeEnabled: permissionsEnabled,
      isProvisionalEnabled: false,
      isCriticalEnabled: false,
      isProvidesAppNotificationSettingsEnabled: false,
    );
  }

  @override
  Future<bool?> requestPermissions({
    bool sound = false,
    bool alert = false,
    bool badge = false,
    bool provisional = false,
    bool critical = false,
    bool carPlay = false,
    bool providesAppNotificationSettings = false,
  }) async {
    requestPermissionsCount += 1;
    lastRequestedAlert = alert;
    lastRequestedBadge = badge;
    lastRequestedSound = sound;
    final result = requestPermissionsResult ?? permissionsEnabled;
    permissionsEnabled = result;
    return result;
  }
}

class _FakeFcmTokenRegistrar implements FcmTokenRegistrar {
  final registeredTokens = <String>[];

  @override
  Future<void> registerToken(String firebaseToken) async {
    registeredTokens.add(firebaseToken);
  }
}

class _FakeNotificationTapRouter implements NotificationTapRouter {
  final localPayloads = <String?>[];
  final remoteMessageData = <Map<dynamic, dynamic>>[];

  @override
  void routeLocalNotificationTap(String? payload) {
    localPayloads.add(payload);
  }

  @override
  void routeRemoteNotificationData(Map<dynamic, dynamic> data) {
    remoteMessageData.add(data);
  }
}
