import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/core/services/js_interop_service.dart';
import 'package:on_time_front/core/services/navigation_service.dart';
import 'package:on_time_front/data/data_sources/notification_remote_data_source.dart';
import 'package:on_time_front/data/models/fcm_token_register_request_model.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM Background Handler] 메시지 수신');

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('[FCM Background Handler] Firebase 초기화 오류: $e');
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

  Future<void> initialize() async {
    try {
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);
      debugPrint('[FCM] Background message handler 등록 완료');
    } catch (e) {
      debugPrint('[FCM] Background message handler 등록 실패: $e');
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
      debugPrint('[FCM] iOS 포그라운드 알림 표시 옵션 설정 완료');
    }
  }

  Future<AuthorizationStatus> checkNotificationPermission() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus;
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

      debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');
    }
  }

  Future<void> requestNotificationToken() async {
    try {
      final token = await _messaging.getToken();
      debugPrint('[FCM] FCM Token 획득: $token');

      if (token != null) {
        try {
          await getIt.get<NotificationRemoteDataSource>().fcmTokenRegister(
                FcmTokenRegisterRequestModel(firebaseToken: token),
              );
          debugPrint('[FCM] FCM Token 서버 등록 완료');
        } catch (e) {
          debugPrint('[FCM] FCM Token 서버 등록 실패: $e');
        }
      }

      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('[FCM] Token 갱신됨: $newToken');
        getIt.get<NotificationRemoteDataSource>().fcmTokenRegister(
              FcmTokenRegisterRequestModel(firebaseToken: newToken),
            );
      });
    } catch (e) {
      debugPrint('[FCM] Token 요청 오류: $e');
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
    try {
      await setupFlutterNotifications();
    } catch (e) {
      debugPrint('[FCM] setupFlutterNotifications 오류: $e');
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
    } catch (e, stackTrace) {
      debugPrint('[FCM] 로컬 알림 표시 실패: $e');
      debugPrint('[FCM] 스택 트레이스: $stackTrace');
    }
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    try {
      await setupFlutterNotifications();
    } catch (e) {
      debugPrint('[FCM] setupFlutterNotifications 오류: $e');
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
    } catch (e, stackTrace) {
      debugPrint('[FCM] 로컬 알림 표시 실패: $e');
      debugPrint('[FCM] 스택 트레이스: $stackTrace');
    }
  }

  Future<void> _setupMessageHandlers() async {
    //foreground message
    FirebaseMessaging.onMessage.listen(
      (message) {
        try {
          showNotification(message);
        } catch (e, stackTrace) {
          debugPrint('[FCM Foreground] 알림 표시 오류: $e');
          debugPrint('[FCM Foreground] 스택 트레이스: $stackTrace');
        }
      },
      onError: (error) {
        debugPrint('[FCM Foreground] 리스너 오류: $error');
      },
      cancelOnError: false,
    );
    debugPrint('[FCM] Foreground message handler 등록 완료');

    // background message
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleBackgroundMessage(message);
    });
    debugPrint('[FCM] Background message handler 등록 완료');

    // opened app
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleBackgroundMessage(initialMessage);
    }
  }

  void _handleLocalNotificationTap(String? payload) {
    debugPrint('[FCM] 알림 탭');
    if (payload == null) {
      return;
    }
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final type = data['type'] as String?;
      final scheduleId = data['scheduleId'] as String?;
      // final title = data['title'] as String?;

      if (type != null &&
              (type.startsWith('schedule_') ||
                  type.startsWith('preparation_')) ||
          scheduleId != null) {
        getIt.get<NavigationService>().push('/alarmScreen');
      } 
      // else if (title != null && title.contains('약속')) {
      //   getIt.get<NavigationService>().push('/alarmScreen');
      // }
    } catch (e) {
      debugPrint('[FCM] 페이로드 파싱 오류: $e');
    }
  }

  Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    debugPrint('[FCM] 백그라운드 메시지 처리');

    final type = message.data['type'] as String?;
    final scheduleId = message.data['scheduleId'] as String?;
    // final title = message.data['title'] as String?;

    if (type != null &&
            (type.startsWith('schedule_') || type.startsWith('preparation_')) ||
        scheduleId != null) {
      getIt.get<NavigationService>().push('/alarmScreen');
    } 
    // else if (title != null && title.contains('약속')) {
    //   getIt.get<NavigationService>().push('/alarmScreen');
    // }
  }
}
