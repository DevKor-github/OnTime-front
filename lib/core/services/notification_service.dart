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
  debugPrint('═══════════════════════════════════════════════════════');
  debugPrint('[FCM Background Handler] 메시지 수신: ${message.messageId}');
  debugPrint('[FCM Background Handler] 데이터: ${message.data}');
  debugPrint(
      '[FCM Background Handler] 알림: ${message.notification?.title} - ${message.notification?.body}');
  debugPrint('═══════════════════════════════════════════════════════');

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
    debugPrint('[FCM] NotificationService 초기화 시작');

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

    // iOS에서 포그라운드 알림 표시를 위한 설정
    if (Platform.isIOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('[FCM] iOS 포그라운드 알림 표시 옵션 설정 완료');
    }

    debugPrint('[FCM] NotificationService 초기화 완료');
  }

  Future<AuthorizationStatus> checkNotificationPermission() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus;
  }

  Future<void> _requestPermission() async {
    if (kIsWeb) {
      final permission = await JsInteropService.requestNotificationPermission();
      debugPrint('[FCM] Web Permission status: $permission');
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
      debugPrint(
          '[FCM] Alert: ${settings.alert}, Badge: ${settings.badge}, Sound: ${settings.sound}');
    }
  }

  Future<void> requestNotificationToken() async {
    try {
      if (!kIsWeb) {
        if (Platform.isIOS) {
          final APNSToken = await _messaging.getAPNSToken();
          debugPrint('[FCM] APNs Token: $APNSToken');
        }
      }

      final token = await _messaging.getToken();
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('[FCM] FCM Token 획득: $token');
      debugPrint('═══════════════════════════════════════════════════════');

      if (token != null) {
        debugPrint('[FCM] FCM Token 서버 등록 시작');
        try {
          await getIt.get<NotificationRemoteDataSource>().fcmTokenRegister(
                FcmTokenRegisterRequestModel(firebaseToken: token),
              );
          debugPrint('[FCM] FCM Token 서버 등록 완료');
        } catch (e) {
          debugPrint('[FCM] FCM Token 서버 등록 실패: $e');
        }
      } else {
        debugPrint('[FCM] FCM Token이 null입니다');
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
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('[FCM Show Notification] 메시지 수신 시작');
    debugPrint('[FCM Show Notification] 메시지 ID: ${message.messageId}');
    debugPrint('[FCM Show Notification] 데이터: ${message.data}');
    debugPrint(
        '[FCM Show Notification] 데이터 키 목록: ${message.data.keys.toList()}');
    debugPrint(
        '[FCM Show Notification] 알림 객체: ${message.notification?.toString()}');
    debugPrint('[FCM Show Notification] 알림 제목: ${message.notification?.title}');
    debugPrint('[FCM Show Notification] 알림 본문: ${message.notification?.body}');
    debugPrint('[FCM Show Notification] 메시지 전체: ${message.toString()}');
    debugPrint('═══════════════════════════════════════════════════════');

    try {
      await setupFlutterNotifications();
    } catch (e) {
      debugPrint('[FCM Show Notification] setupFlutterNotifications 오류: $e');
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

    debugPrint('[FCM Show Notification] 파싱된 제목: $title');
    debugPrint('[FCM Show Notification] 파싱된 본문: $body');
    debugPrint('[FCM Show Notification] 최종 제목: $title, 본문: $body');

    if (title == null && body == null) {
      debugPrint('[FCM Show Notification] 제목과 본문이 모두 null이어서 알림을 표시하지 않습니다');
      debugPrint('[FCM Show Notification] 사용 가능한 데이터 키: ${message.data.keys}');
      return;
    }

    try {
      final notificationId = ((title ?? '') +
              (body ?? '') +
              DateTime.now().millisecondsSinceEpoch.toString())
          .hashCode;
      debugPrint('[FCM Show Notification] 알림 ID: $notificationId');
      debugPrint('[FCM Show Notification] 로컬 알림 표시 시작');

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

      debugPrint('[FCM Show Notification] 로컬 알림 표시 완료');
    } catch (e, stackTrace) {
      debugPrint('[FCM Show Notification] 로컬 알림 표시 실패: $e');
      debugPrint('[FCM Show Notification] 스택 트레이스: $stackTrace');
    }
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('[FCM Local Notification] 수동 표시 시작');
    debugPrint('[FCM Local Notification] 제목: $title');
    debugPrint('[FCM Local Notification] 본문: $body');
    debugPrint('[FCM Local Notification] 페이로드: $payload');
    debugPrint('═══════════════════════════════════════════════════════');

    try {
      await setupFlutterNotifications();
    } catch (e) {
      debugPrint('[FCM Local Notification] setupFlutterNotifications 오류: $e');
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
      debugPrint('[FCM Local Notification] 표시 완료: $notificationId');
    } catch (e, stackTrace) {
      debugPrint('[FCM Local Notification] 표시 실패: $e');
      debugPrint('[FCM Local Notification] 스택 트레이스: $stackTrace');
    }
  }

  Future<void> _setupMessageHandlers() async {
    debugPrint('[FCM] Message handlers 설정 시작');

    //foreground message
    FirebaseMessaging.onMessage.listen(
      (message) {
        debugPrint('═══════════════════════════════════════════════════════');
        debugPrint('[FCM Foreground] 앱이 포그라운드에 있을 때 메시지 수신');
        debugPrint('[FCM Foreground] 메시지 ID: ${message.messageId}');
        debugPrint('[FCM Foreground] 데이터: ${message.data}');
        debugPrint(
            '[FCM Foreground] 알림: ${message.notification?.title} - ${message.notification?.body}');
        debugPrint('[FCM Foreground] 메시지 전체: ${message.toString()}');
        debugPrint('═══════════════════════════════════════════════════════');

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

    // 리스너가 제대로 등록되었는지 확인
    _messaging.getInitialMessage().then((message) {
      debugPrint('[FCM] Initial message 체크 완료');
    }).catchError((error) {
      debugPrint('[FCM] Initial message 체크 오류: $error');
    });

    // background message
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('[FCM Opened App] 백그라운드에서 알림 탭으로 앱 열림');
      debugPrint('[FCM Opened App] 메시지 ID: ${message.messageId}');
      debugPrint('[FCM Opened App] 데이터: ${message.data}');
      debugPrint('═══════════════════════════════════════════════════════');
      _handleBackgroundMessage(message);
    });
    debugPrint('[FCM] Background message handler 등록 완료');

    // opened app
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('[FCM Initial Message] 종료 상태에서 알림 탭으로 앱 열림');
      debugPrint('[FCM Initial Message] 메시지 ID: ${initialMessage.messageId}');
      debugPrint('[FCM Initial Message] 데이터: ${initialMessage.data}');
      debugPrint('═══════════════════════════════════════════════════════');
      _handleBackgroundMessage(initialMessage);
    } else {
      debugPrint('[FCM] Initial message 없음 (정상 시작)');
    }

    debugPrint('[FCM] Message handlers 설정 완료');
  }

  void _handleLocalNotificationTap(String? payload) {
    debugPrint('[FCM Local Notification Tap] 알림 탭됨');
    debugPrint('[FCM Local Notification Tap] 페이로드: $payload');
    if (payload == null) {
      debugPrint('[FCM Local Notification Tap] 페이로드가 null입니다');
      return;
    }
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final type = data['type'] as String?;
      final scheduleId = data['scheduleId'] as String?;
      debugPrint(
          '[FCM Local Notification Tap] 데이터: $data, 타입: $type, scheduleId: $scheduleId');

      // 스케줄 관련 알림인 경우
      if (type != null &&
              (type.startsWith('schedule_') ||
                  type.startsWith('preparation_')) ||
          scheduleId != null) {
        debugPrint('[FCM Local Notification Tap] 스케줄 관련 알림으로 화면 이동');

        // 타입에 따라 다르게 처리
        // schedule_5min_before, schedule_start, schedule_step, preparation_step 등
        // 모두 스케줄 시작/진행 화면으로 이동 (이미 시작된 경우도 같은 화면에서 처리)
        getIt.get<NavigationService>().push('/scheduleStart');
      } else if (type == 'chat') {
        debugPrint('[FCM Local Notification Tap] 채팅 화면으로 이동');
        // open chat screen
      } else {
        debugPrint('[FCM Local Notification Tap] 알 수 없는 타입: $type');
      }
    } catch (e) {
      debugPrint('[FCM Local Notification Tap] 페이로드 파싱 오류: $e');
    }
  }

  Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    debugPrint('[FCM Handle Background] 백그라운드 메시지 처리 시작');
    debugPrint('[FCM Handle Background] 메시지 ID: ${message.messageId}');
    debugPrint('[FCM Handle Background] 데이터: ${message.data}');

    final type = message.data['type'] as String?;
    final scheduleId = message.data['scheduleId'] as String?;
    debugPrint('[FCM Handle Background] 타입: $type, scheduleId: $scheduleId');

    // 스케줄 관련 알림인 경우 (5분전, 시작, 단계별 모두 포함)
    if (type != null &&
            (type.startsWith('schedule_') || type.startsWith('preparation_')) ||
        scheduleId != null) {
      debugPrint('[FCM Handle Background] 스케줄 관련 알림으로 화면 이동');
      debugPrint('[FCM Handle Background] 타입 상세: $type - 스케줄 시작/진행 화면으로 이동');

      // 타입에 관계없이 모두 스케줄 시작/진행 화면으로 이동
      // schedule_5min_before: 시작 전 알림 → 시작 화면으로
      // schedule_start: 시작 알림 → 시작 화면으로
      // schedule_step / preparation_step: 단계별 알림 → 이미 시작된 경우 진행 화면으로 (같은 /scheduleStart 경로)
      getIt.get<NavigationService>().push('/scheduleStart');
    } else if (type == 'chat') {
      debugPrint('[FCM Handle Background] 채팅 화면으로 이동');
      // open chat screen
    } else {
      debugPrint('[FCM Handle Background] 알 수 없는 타입: $type');
    }
  }
}
