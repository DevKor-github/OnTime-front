import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/core/logging/app_logger.dart';
import 'package:on_time_front/core/services/js_interop_service.dart';
import 'package:on_time_front/core/services/navigation_service.dart';
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
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  bool _isFlutterLocalNotificationsInitialized = false;
  bool _isTimezoneInitialized = false;

  String get _locale {
    try {
      final locale = ui.PlatformDispatcher.instance.locale;
      return locale.languageCode;
    } catch (e) {
      return 'ko';
    }
  }

  String _getLocalizedText(String ko, String en) {
    return _locale == 'ko' ? ko : en;
  }

  Future<void> initialize() async {
    try {
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);
      AppLogger.debug('[FCM] Background message handler 등록 완료');
    } catch (e) {
      AppLogger.debug('[FCM] Background message handler 등록 실패: $e');
    }

    await _requestPermission();
    await setupFlutterNotifications();
    await _setupMessageHandlers();

    await requestNotificationToken();

    if (!kIsWeb && Platform.isIOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      AppLogger.debug('[FCM] iOS 포그라운드 알림 표시 옵션 설정 완료');
    }
  }

  Future<AuthorizationStatus> checkNotificationPermission() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus;
  }

  Future<AuthorizationStatus> requestPermission() async {
    if (kIsWeb) {
      await JsInteropService.requestNotificationPermission();
      final settings = await _messaging.getNotificationSettings();
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
          '[FCM] Permission status: ${settings.authorizationStatus}');
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
          '[FCM] Permission status: ${settings.authorizationStatus}');
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
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    const alarmChannel = AndroidNotificationChannel(
      'scheduled_alarm_channel',
      'Scheduled alarms',
      description: 'Schedule preparation alarm fallback notifications.',
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(alarmChannel);

    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // ios setup
    final initializationSettingsDarwin = DarwinInitializationSettings();

    final initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    // flutter notification setup
    await _localNotifications.initialize(
      initializationSettings,
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

    final notification = message.notification;
    final String? title =
        notification?.title ?? message.data['title'] ?? message.data['Title'];
    final String? body = notification?.body ??
        message.data['content'] ??
        message.data['body'] ??
        message.data['Content'] ??
        message.data['Body'];

    if (title == null && body == null) {
      return;
    }

    try {
      final notificationId = ((title ?? '') +
              (body ?? '') +
              DateTime.now().millisecondsSinceEpoch.toString())
          .hashCode;

      await _localNotifications.show(
        notificationId,
        title ?? '알림',
        body ?? '',
        NotificationDetails(
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
        payload: jsonEncode(message.data),
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
    if (_isScheduleAlarmPayload(payload)) {
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
        notificationId,
        title,
        body,
        NotificationDetails(
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
        payload: payload != null ? jsonEncode(payload) : null,
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

    final title = '[$scheduleName] $preparationName';
    final body = _getLocalizedText('이어서 준비하세요.', 'Continue preparing');

    await showLocalNotification(
      title: title,
      body: body,
      payload: {
        'type': 'preparation_step',
        'scheduleId': scheduleId,
        'stepId': stepId,
      },
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
    return _isScheduleAlarmPayload(data) ||
        title == '약속 알림' ||
        title == 'Schedule alarm';
  }

  bool _isScheduleAlarmPayload(Map<dynamic, dynamic>? payload) {
    if (payload == null) return false;
    final type = payload['type']?.toString();
    final promptVariant = payload['promptVariant']?.toString();
    return type == 'schedule_alarm' ||
        payload['alarmLaunchPayloadVersion'] != null ||
        (promptVariant == 'alarm' && payload['scheduleId'] != null);
  }

  Future<void> scheduleFallbackAlarm(
    ScheduledAlarmRecord record,
  ) async {
    if (!await hasNotificationPermission()) {
      throw const AlarmSchedulingException(
        reason: AlarmFailureReason.platformError,
        permissionIssue: AlarmPermissionIssue.notificationPermissionDenied,
        message: 'Notification permission denied',
      );
    }

    await setupFlutterNotifications();
    _ensureTimezoneInitialized();

    final notificationId =
        record.fallbackNotificationId ?? stableAlarmId(record.scheduleId);
    final scheduledAt = tz.TZDateTime.from(record.alarmTime, tz.local);
    AppLogger.debug(
      '[FallbackAlarm] schedule notificationId=$notificationId '
      'scheduleId=${record.scheduleId} '
      'scheduledAt=${scheduledAt.toIso8601String()} '
      'mode=${AndroidScheduleMode.inexactAllowWhileIdle}',
    );
    await _localNotifications.zonedSchedule(
      notificationId,
      record.scheduleTitle,
      _getLocalizedText('준비를 시작할 시간입니다.', 'It is time to get ready.'),
      scheduledAt,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'scheduled_alarm_channel',
          'Scheduled alarms',
          channelDescription:
              'Schedule preparation alarm fallback notifications.',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode(record.payload),
    );
  }

  Future<void> cancelFallbackNotification(int notificationId) async {
    await setupFlutterNotifications();
    await _localNotifications.cancel(notificationId);
  }

  void _ensureTimezoneInitialized() {
    if (_isTimezoneInitialized) return;
    tz_data.initializeTimeZones();
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
    if (payload == null) {
      return;
    }
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final type = data['type'] as String?;
      final scheduleId = data['scheduleId'] as String?;
      // final title = data['title'] as String?;

      if (type == 'schedule_alarm' && scheduleId != null) {
        getIt.get<NavigationService>().push(
              '/scheduleStart',
              extra: data,
            );
      } else if (type != null && type.contains('5min')) {
        getIt.get<NavigationService>().push(
          '/scheduleStart',
          extra: {'promptVariant': 'earlyStart'},
        );
      } else if (type != null &&
              (type.startsWith('schedule_') ||
                  type.startsWith('preparation_')) ||
          scheduleId != null) {
        getIt.get<NavigationService>().push('/alarmScreen');
      }
      // else if (title != null && title.contains('약속')) {
      //   getIt.get<NavigationService>().push('/alarmScreen');
      // }
    } catch (e) {
      AppLogger.debug('[FCM] 페이로드 파싱 오류: $e');
    }
  }

  Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    AppLogger.debug('[FCM] 백그라운드 메시지 처리');

    final type = message.data['type'] as String?;
    final scheduleId = message.data['scheduleId'] as String?;
    // final title = message.data['title'] as String?;

    if (type == 'schedule_alarm' && scheduleId != null) {
      getIt.get<NavigationService>().push(
            '/scheduleStart',
            extra: message.data,
          );
    } else if (type != null && type.contains('5min')) {
      getIt.get<NavigationService>().push(
        '/scheduleStart',
        extra: {'promptVariant': 'earlyStart'},
      );
    } else if (type != null &&
            (type.startsWith('schedule_') || type.startsWith('preparation_')) ||
        scheduleId != null) {
      getIt.get<NavigationService>().push('/alarmScreen');
    }
    // else if (title != null && title.contains('약속')) {
    //   getIt.get<NavigationService>().push('/alarmScreen');
    // }
  }
}
