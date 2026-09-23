import 'dart:convert';
import 'package:on_time_front/domain/entities/notification_route_payload.dart';
import 'package:on_time_front/data/data_sources/alarm_registry_local_data_source.dart';
import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:on_time_front/core/logging/app_logger.dart';
import 'package:on_time_front/core/services/notification_content.dart';
import 'package:on_time_front/core/services/notification_tap_router.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:permission_handler/permission_handler.dart'
    as permission_handler;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

enum AuthorizationStatus { authorized, denied, notDetermined, provisional }

class NotificationService {
  NotificationService._({
    FlutterLocalNotificationsPlugin? localNotifications,
    NotificationTapRouter? notificationTapRouter,
    String Function()? localeProvider,
    bool? isIOSOverride,
  }) : _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin(),
       _notificationTapRouter =
           notificationTapRouter ?? const NoopNotificationTapRouter(),
       _localeProvider = localeProvider,
       _isIOSOverride = isIOSOverride;

  @visibleForTesting
  NotificationService.test({
    required FlutterLocalNotificationsPlugin localNotifications,
    NotificationTapRouter? notificationTapRouter,
    String Function()? localeProvider,
    bool isFlutterLocalNotificationsInitialized = false,
    bool isTimezoneInitialized = false,
    bool? isIOSOverride,
  }) : _localNotifications = localNotifications,
       _notificationTapRouter =
           notificationTapRouter ?? const NoopNotificationTapRouter(),
       _localeProvider = localeProvider,
       _isIOSOverride = isIOSOverride,
       _isFlutterLocalNotificationsInitialized =
           isFlutterLocalNotificationsInitialized,
       _isTimezoneInitialized = isTimezoneInitialized;

  static final NotificationService instance = NotificationService._();
  static const _nativeAlarmChannel = MethodChannel(
    'on_time_front/native_alarm',
  );

  final FlutterLocalNotificationsPlugin _localNotifications;
  NotificationTapRouter _notificationTapRouter;
  final String Function()? _localeProvider;
  final bool? _isIOSOverride;
  bool _isFlutterLocalNotificationsInitialized = false;
  bool _isTimezoneInitialized = false;
  Future<void>? _initializationFuture;

  bool get _isIOS => !kIsWeb && (_isIOSOverride ?? Platform.isIOS);

  String get _locale =>
      _localeProvider?.call() ??
      ui.PlatformDispatcher.instance.locale.languageCode;

  void configureDelegate({
    required NotificationTapRouter notificationTapRouter,
  }) {
    _notificationTapRouter = notificationTapRouter;
  }

  /// Uses only the plugin's public API. Its pending list is cache evidence,
  /// not proof about historical OS logs or first-launch-before-boot delivery.
  Future<void> removeLegacySchedulePayloads() async {
    await setupFlutterNotifications();
    final source = AlarmRegistryLocalDataSourceImpl();
    var records = await source.loadAll();
    final pending = await _localNotifications.pendingNotificationRequests();
    for (final request in pending) {
      Map<String, dynamic>? payload;
      try {
        final decoded = jsonDecode(request.payload ?? '');
        if (decoded is Map<String, dynamic>) payload = decoded;
      } catch (_) {
        /* Unknown ownership is not cancelled indiscriminately. */
      }
      final owner = records
          .where(
            (record) =>
                record.provider == AlarmProvider.localNotification &&
                record.fallbackNotificationId == request.id,
          )
          .firstOrNull;
      final knownScheduleType =
          payload?['type'] == 'schedule_notification' ||
          payload?['type'] == 'schedule_alarm';
      if (owner == null && !knownScheduleType) continue;
      final safe = payload == null
          ? <String, String>{}
          : minimalScheduleRoutePayload(payload);
      if (safe.isNotEmpty &&
          payload!.length == safe.length &&
          safe.entries.every((entry) => payload![entry.key] == entry.value)) {
        continue;
      }
      // A malformed route can still be an owned platform registration. This
      // internal cancellation-only ID is never used to load or open a Schedule.
      final id =
          safe['scheduleId'] ??
          owner?.scheduleId ??
          'privacy-cleanup:notification:${request.id}';
      final existing =
          owner ??
          records
              .where(
                (record) =>
                    record.scheduleId == id &&
                    record.provider == AlarmProvider.localNotification,
              )
              .firstOrNull;
      final tombstone =
          (existing ??
                  ScheduledAlarmRecord(
                    scheduleId: id,
                    alarmTime: DateTime.fromMillisecondsSinceEpoch(
                      0,
                      isUtc: true,
                    ),
                    preparationStartTime: DateTime.fromMillisecondsSinceEpoch(
                      0,
                      isUtc: true,
                    ),
                    scheduleFingerprint: '',
                    provider: AlarmProvider.localNotification,
                    scheduleTitle: 'OnTime',
                    payload: safe,
                  ))
              .copyWith(
                fallbackNotificationId: request.id,
                cancellationPending: true,
              );
      records = [...records.where((record) => record != existing), tombstone];
      await source.replaceAll(records); // Ownership survives interruption.
      await _localNotifications.cancel(id: request.id);
      final remaining = await _localNotifications.pendingNotificationRequests();
      if (remaining.any((record) => record.id == request.id)) {
        throw StateError('Legacy notification cancellation is unconfirmed');
      }
      records = records.where((record) => record != tombstone).toList();
      await source.replaceAll(records);
    }
  }

  Future<void> initialize() {
    return _initializationFuture ??= _initialize().whenComplete(() {
      _initializationFuture = null;
    });
  }

  Future<void> _initialize() async {
    await setupFlutterNotifications();
    await _ensureTimezoneInitialized();
  }

  Future<AuthorizationStatus> checkNotificationPermission() async {
    if (_isIOS) {
      final permissions = await _localNotifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.checkPermissions();
      if (permissions == null) return AuthorizationStatus.notDetermined;
      return permissions.isEnabled
          ? AuthorizationStatus.authorized
          : AuthorizationStatus.denied;
    }
    if (kIsWeb) return AuthorizationStatus.denied;
    final status = await permission_handler.Permission.notification.status;
    if (status.isGranted || status.isLimited || status.isProvisional) {
      return AuthorizationStatus.authorized;
    }
    if (status.isDenied) return AuthorizationStatus.notDetermined;
    return AuthorizationStatus.denied;
  }

  Future<AuthorizationStatus> requestPermission() async {
    if (_isIOS) {
      final granted = await _localNotifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted == true
          ? AuthorizationStatus.authorized
          : AuthorizationStatus.denied;
    }
    if (kIsWeb) return AuthorizationStatus.denied;
    final granted = await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    return granted == false
        ? AuthorizationStatus.denied
        : AuthorizationStatus.authorized;
  }

  Future<bool> openNotificationSettings() =>
      permission_handler.openAppSettings();

  Future<void> setupFlutterNotifications() async {
    if (_isFlutterLocalNotificationsInitialized) return;

    const generalChannel = AndroidNotificationChannel(
      'high_importance_channel',
      'Important notifications',
      description: 'OnTime local notifications.',
      importance: Importance.high,
    );
    const scheduleChannel = AndroidNotificationChannel(
      'scheduled_notification_channel',
      'Schedule notifications',
      description: 'OnTime schedule preparation notifications.',
      importance: Importance.max,
    );
    final android = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(generalChannel);
    await android?.createNotificationChannel(scheduleChannel);

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        _notificationTapRouter.routeLocalNotificationTap(response.payload);
      },
    );
    _isFlutterLocalNotificationsInitialized = true;
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    await setupFlutterNotifications();
    await _localNotifications.show(
      id: Object.hash(title, body, DateTime.now().microsecondsSinceEpoch),
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'Important notifications',
          channelDescription: 'OnTime local notifications.',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: encodeLocalNotificationPayload(payload),
    );
  }

  Future<void> showPreparationStepNotification({
    required String scheduleName,
    required String preparationName,
    required String scheduleId,
    required String stepId,
  }) async {
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      return;
    }
    await showLocalNotification(
      title: _locale == 'ko' ? '준비 단계가 바뀌었어요' : 'Preparation updated',
      body: _locale == 'ko'
          ? 'OnTime을 열어 다음 단계를 확인하세요.'
          : 'Open OnTime to see the next step.',
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

  Future<void> scheduleFallbackAlarm(ScheduledAlarmRecord record) async {
    record.requireCurrentContent();
    if (!await hasNotificationPermission()) {
      throw const AlarmSchedulingException(
        reason: AlarmFailureReason.platformError,
        permissionIssue: AlarmPermissionIssue.notificationPermissionDenied,
        message: 'Notification permission denied',
      );
    }
    await setupFlutterNotifications();
    await _ensureTimezoneInitialized();
    final content = record.deliveryContent;
    await _localNotifications.zonedSchedule(
      id: fallbackNotificationIdForRecord(record),
      title: content.title,
      body: content.body,
      scheduledDate: tz.TZDateTime.from(record.alarmTime, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'scheduled_notification_channel',
          'Schedule notifications',
          channelDescription: 'OnTime schedule preparation notifications.',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.reminder,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: encodeLocalNotificationPayload(
        minimalScheduleRoutePayload(record.payload),
      ),
    );
  }

  Future<void> cancelFallbackNotification(int notificationId) async {
    await setupFlutterNotifications();
    await _localNotifications.cancel(id: notificationId);
  }

  Future<void> cancelAll() async {
    await setupFlutterNotifications();
    await _localNotifications.cancelAll();
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
        }
      } on MissingPluginException {
        AppLogger.debug('[LocalNotification] timezone plugin unavailable');
      } on PlatformException catch (error) {
        AppLogger.debug(
          '[LocalNotification] timezone failed code=${error.code}',
        );
      }
    }
    _isTimezoneInitialized = true;
  }
}
