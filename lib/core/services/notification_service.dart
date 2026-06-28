import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/core/logging/app_logger.dart';
import 'package:on_time_front/core/services/js_interop_service.dart';
import 'package:on_time_front/core/services/navigation_service.dart';
import 'package:on_time_front/core/services/notification_content.dart';
import 'package:on_time_front/core/services/notification_routing.dart';
import 'package:on_time_front/data/data_sources/notification_remote_data_source.dart';
import 'package:on_time_front/data/models/fcm_token_register_request_model.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/repositories/alarm_repository.dart';
import 'package:permission_handler/permission_handler.dart'
    as permission_handler;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  AppLogger.configureFlutterDebugPrint();
  AppLogger.debug('[FCM Background Handler] message received');

  try {
    await Firebase.initializeApp();
  } catch (e) {
    AppLogger.debug('[FCM Background Handler] Firebase init failed: $e');
  }
  await NotificationService.instance.setupFlutterNotifications();
  await NotificationService.instance.showNotification(message);
}

class NotificationService {
  NotificationService._({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
    String Function()? localeProvider,
    bool? isIOSOverride,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin(),
       _localeProvider = localeProvider,
       _isIOSOverride = isIOSOverride;

  @visibleForTesting
  NotificationService.test({
    required FirebaseMessaging messaging,
    required FlutterLocalNotificationsPlugin localNotifications,
    String Function()? localeProvider,
    bool isFlutterLocalNotificationsInitialized = false,
    bool isTimezoneInitialized = false,
    bool? isIOSOverride,
  }) : _messaging = messaging,
       _localNotifications = localNotifications,
       _localeProvider = localeProvider,
       _isIOSOverride = isIOSOverride,
       _isFlutterLocalNotificationsInitialized =
           isFlutterLocalNotificationsInitialized,
       _isTimezoneInitialized = isTimezoneInitialized;

  static final NotificationService instance = NotificationService._();
  static const _nativeAlarmChannel = MethodChannel(
    'on_time_front/native_alarm',
  );

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final String Function()? _localeProvider;
  final bool? _isIOSOverride;
  bool _isFlutterLocalNotificationsInitialized = false;
  bool _isTimezoneInitialized = false;

  bool get _isIOS => !kIsWeb && (_isIOSOverride ?? Platform.isIOS);

  String get _locale {
    final localeProvider = _localeProvider;
    if (localeProvider != null) {
      return localeProvider();
    }
    try {
      final locale = ui.PlatformDispatcher.instance.locale;
      return locale.languageCode;
    } catch (e) {
      return 'ko';
    }
  }

  Future<void> initialize() async {
    try {
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
      AppLogger.debug('[FCM] Background message handler 등록 완료');
    } catch (e) {
      AppLogger.debug('[FCM] Background message handler 등록 실패: $e');
    }

    await _requestPermission();
    await setupFlutterNotifications();
    await _setupMessageHandlers();

    await requestNotificationToken();

    if (_isIOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      AppLogger.debug('[FCM] iOS 포그라운드 알림 표시 옵션 설정 완료');
    }
  }

  Future<AuthorizationStatus> checkNotificationPermission() async {
    if (_isIOS) {
      final localPermission = await _checkDarwinLocalNotificationPermission();
      if (localPermission != null) {
        return localPermission
            ? AuthorizationStatus.authorized
            : AuthorizationStatus.denied;
      }
    }
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus;
  }

  Future<AuthorizationStatus> requestPermission() async {
    if (kIsWeb) {
      await JsInteropService.requestNotificationPermission();
      final settings = await _messaging.getNotificationSettings();
      return settings.authorizationStatus;
    } else if (_isIOS) {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );

      AppLogger.debug(
        '[FCM] Permission status: ${settings.authorizationStatus}',
      );
      final localPermission = await _requestDarwinLocalNotificationPermission();
      AppLogger.debug(
        '[FallbackAlarm] iOS local notification permission=$localPermission',
      );
      if (localPermission == false) {
        return AuthorizationStatus.denied;
      }
      return settings.authorizationStatus;
    } else {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );

      AppLogger.debug(
        '[FCM] Permission status: ${settings.authorizationStatus}',
      );
      return settings.authorizationStatus;
    }
  }

  Future<bool> openNotificationSettings() async {
    try {
      final opened = await permission_handler.openAppSettings();
      AppLogger.debug('[FCM] 앱 설정 열기: $opened');
      return opened;
    } catch (e) {
      AppLogger.debug('[FCM] 앱 설정 열기 실패: $e');
      return false;
    }
  }

  Future<void> _requestPermission() async {
    if (kIsWeb) {
      await JsInteropService.requestNotificationPermission();
    } else {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );

      AppLogger.debug(
        '[FCM] Permission status: ${settings.authorizationStatus}',
      );
    }
  }

  Future<void> requestNotificationToken() async {
    try {
      final token = await _messaging.getToken();
      AppLogger.debug(
        '[FCM] FCM token acquired token=${AppLogger.redactToken(token)}',
      );

      if (token != null) {
        try {
          final deviceId = await getIt.get<AlarmRepository>().getDeviceId();
          await getIt.get<NotificationRemoteDataSource>().fcmTokenRegister(
            FcmTokenRegisterRequestModel(
              firebaseToken: token,
              deviceId: deviceId,
            ),
          );
          AppLogger.debug('[FCM] FCM Token 서버 등록 완료');
        } catch (e) {
          AppLogger.debug('[FCM] FCM Token 서버 등록 실패: $e');
        }
      }

      _messaging.onTokenRefresh.listen((newToken) {
        AppLogger.debug(
          '[FCM] token refreshed token=${AppLogger.redactToken(newToken)}',
        );
        getIt.get<AlarmRepository>().getDeviceId().then((deviceId) {
          getIt.get<NotificationRemoteDataSource>().fcmTokenRegister(
            FcmTokenRegisterRequestModel(
              firebaseToken: newToken,
              deviceId: deviceId,
            ),
          );
        });
      });
    } catch (e) {
      AppLogger.debug('[FCM] Token 요청 오류: $e');
    }
  }

  Future<void> setupFlutterNotifications() async {
    if (_isFlutterLocalNotificationsInitialized) {
      return;
    }

    // android setup
    const channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    const alarmChannel = AndroidNotificationChannel(
      'scheduled_notification_channel',
      'Schedule notifications',
      description: 'Schedule preparation notifications.',
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(alarmChannel);

    const initializationSettingsAndroid = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // ios setup
    const initializationSettingsDarwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    final initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    // flutter notification setup
    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        _handleLocalNotificationTap(details.payload);
      },
    );

    _isFlutterLocalNotificationsInitialized = true;
  }

  Future<void> showNotification(RemoteMessage message) async {
    if (_isScheduleAlarmMessage(message)) {
      AppLogger.debug(
        '[FCM] schedule_alarm push suppressed; native/system alarm handles alarm UI',
      );
      return;
    }

    try {
      await setupFlutterNotifications();
    } catch (e) {
      AppLogger.debug('[FCM] setupFlutterNotifications 오류: $e');
      return;
    }

    final content = remoteNotificationDisplayContent(
      data: message.data,
      notificationTitle: message.notification?.title,
      notificationBody: message.notification?.body,
    );

    if (content == null) {
      return;
    }

    try {
      final notificationId =
          (content.title +
                  content.body +
                  DateTime.now().millisecondsSinceEpoch.toString())
              .hashCode;

      await _localNotifications.show(
        id: notificationId,
        title: content.title,
        body: content.body,
        notificationDetails: NotificationDetails(
          android: const AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription:
                'This channel is used for important notifications.',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: content.payload,
      );
    } catch (error) {
      AppLogger.debug(
        '[FCM] local notification display failed '
        'errorType=${error.runtimeType}',
      );
    }
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    if (isScheduleAlarmPayload(payload)) {
      AppLogger.debug(
        '[FCM] schedule_alarm local notification suppressed; native/system alarm handles alarm UI',
      );
      return;
    }

    try {
      await setupFlutterNotifications();
    } catch (e) {
      AppLogger.debug('[FCM] setupFlutterNotifications 오류: $e');
      return;
    }

    try {
      final notificationId =
          (title + body + DateTime.now().millisecondsSinceEpoch.toString())
              .hashCode;
      await _localNotifications.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: const AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription:
                'This channel is used for important notifications.',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: encodeLocalNotificationPayload(payload),
      );
    } catch (error) {
      AppLogger.debug(
        '[FCM] local notification display failed '
        'errorType=${error.runtimeType}',
      );
    }
  }

  Future<void> showPreparationStepNotification({
    required String scheduleName,
    required String preparationName,
    required String scheduleId,
    required String stepId,
  }) async {
    // Disable case-3 alerts while app is in foreground.
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      AppLogger.debug(
        '[FCM] preparation step notification skipped in foreground',
      );
      return;
    }

    await showLocalNotification(
      title: preparationStepNotificationTitle(
        scheduleName: scheduleName,
        preparationName: preparationName,
      ),
      body: preparationStepNotificationBody(languageCode: _locale),
      payload: preparationStepNotificationPayload(
        scheduleId: scheduleId,
        stepId: stepId,
      ),
    );
  }

  Future<bool> hasNotificationPermission() async {
    final permission = await checkNotificationPermission();
    return permission == AuthorizationStatus.authorized ||
        permission == AuthorizationStatus.provisional;
  }

  bool _isScheduleAlarmMessage(RemoteMessage message) {
    final data = message.data;
    final title = message.notification?.title ?? data['title'] ?? data['Title'];
    return isScheduleAlarmMessagePayload(data: data, title: title?.toString());
  }

  Future<void> scheduleFallbackAlarm(ScheduledAlarmRecord record) async {
    if (!await hasNotificationPermission()) {
      throw const AlarmSchedulingException(
        reason: AlarmFailureReason.platformError,
        permissionIssue: AlarmPermissionIssue.notificationPermissionDenied,
        message: 'Notification permission denied',
      );
    }

    await setupFlutterNotifications();
    await _ensureTimezoneInitialized();

    final notificationId = fallbackNotificationIdForRecord(record);
    final scheduledAt = tz.TZDateTime.from(record.alarmTime, tz.local);
    AppLogger.debug(
      '[FallbackAlarm] schedule notificationId=$notificationId '
      'scheduleId=${record.scheduleId} '
      'scheduledAt=${scheduledAt.toIso8601String()} '
      'mode=${AndroidScheduleMode.inexactAllowWhileIdle}',
    );
    await _localNotifications.zonedSchedule(
      id: notificationId,
      title: record.scheduleTitle,
      body: fallbackAlarmNotificationBody(languageCode: _locale),
      scheduledDate: scheduledAt,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'scheduled_notification_channel',
          'Schedule notifications',
          channelDescription: 'Schedule preparation notifications.',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.reminder,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: encodeLocalNotificationPayload(record.payload),
    );
    await _logPendingNotificationCount();
  }

  Future<void> cancelFallbackNotification(int notificationId) async {
    await setupFlutterNotifications();
    await _localNotifications.cancel(id: notificationId);
  }

  Future<bool?> _checkDarwinLocalNotificationPermission() async {
    try {
      final plugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (plugin == null) return null;
      final enabled = await plugin.checkPermissions();
      AppLogger.debug('[FallbackAlarm] iOS local notification check=$enabled');
      return enabled?.isEnabled;
    } catch (error) {
      AppLogger.debug(
        '[FallbackAlarm] iOS local notification check failed '
        'errorType=${error.runtimeType}',
      );
      return null;
    }
  }

  Future<bool?> _requestDarwinLocalNotificationPermission() async {
    try {
      return await _localNotifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (error) {
      AppLogger.debug(
        '[FallbackAlarm] iOS local notification permission request failed '
        'errorType=${error.runtimeType}',
      );
      return null;
    }
  }

  Future<void> _logPendingNotificationCount() async {
    if (!_isIOS) return;
    try {
      final pending = await _localNotifications.pendingNotificationRequests();
      AppLogger.debug('[FallbackAlarm] pendingCount=${pending.length}');
    } catch (error) {
      AppLogger.debug(
        '[FallbackAlarm] pending count failed errorType=${error.runtimeType}',
      );
    }
  }

  Future<void> _ensureTimezoneInitialized() async {
    if (_isTimezoneInitialized) return;
    tz_data.initializeTimeZones();
    if (_isIOS) {
      try {
        final identifier = await _nativeAlarmChannel.invokeMethod<String>(
          'getLocalTimeZone',
        );
        if (identifier != null && identifier.isNotEmpty) {
          tz.setLocalLocation(tz.getLocation(identifier));
          AppLogger.debug('[FallbackAlarm] timezone=$identifier');
        }
      } on MissingPluginException {
        AppLogger.debug('[FallbackAlarm] timezone plugin unavailable');
      } on PlatformException catch (error) {
        AppLogger.debug(
          '[FallbackAlarm] timezone lookup failed '
          'code=${error.code} message=${error.message}',
        );
      } catch (error) {
        AppLogger.debug(
          '[FallbackAlarm] timezone lookup failed '
          'errorType=${error.runtimeType}',
        );
      }
    }
    _isTimezoneInitialized = true;
  }

  Future<void> _setupMessageHandlers() async {
    //foreground message
    FirebaseMessaging.onMessage.listen(
      (message) {
        try {
          showNotification(message);
        } catch (error) {
          AppLogger.debug(
            '[FCM Foreground] notification display failed '
            'errorType=${error.runtimeType}',
          );
        }
      },
      onError: (error) {
        AppLogger.debug('[FCM Foreground] 리스너 오류: $error');
      },
      cancelOnError: false,
    );
    AppLogger.debug('[FCM] Foreground message handler 등록 완료');

    // background message
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleBackgroundMessage(message);
    });
    AppLogger.debug('[FCM] Background message handler 등록 완료');

    // opened app
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleBackgroundMessage(initialMessage);
    }
  }

  void _handleLocalNotificationTap(String? payload) {
    AppLogger.debug('[FCM] 알림 탭');
    final target = notificationRouteForPayloadString(payload);
    if (target != null) {
      getIt.get<NavigationService>().push(target.path, extra: target.extra);
    }
  }

  Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    AppLogger.debug('[FCM] 백그라운드 메시지 처리');

    final target = notificationRouteForData(message.data);
    if (target != null) {
      getIt.get<NavigationService>().push(target.path, extra: target.extra);
    }
  }
}
