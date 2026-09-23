import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'owned legacy pending is cancelled without clearing step notifications',
    () async {
      final plugin = _Plugin();
      final service = NotificationService.test(
        localNotifications: plugin,
        isFlutterLocalNotificationsInitialized: true,
      );
      await service.removeLegacySchedulePayloads();
      expect(plugin.cancelled, [11]);
      expect(plugin.pending.map((p) => p.id), [12]);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('scheduled_alarm_registry'), isNull);
    },
  );
  test(
    'cancel failure preserves only ownership tombstone and retry converges',
    () async {
      final plugin = _Plugin()..failCancellation = true;
      final service = NotificationService.test(
        localNotifications: plugin,
        isFlutterLocalNotificationsInitialized: true,
      );
      await expectLater(
        service.removeLegacySchedulePayloads(),
        throwsStateError,
      );
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('scheduled_alarm_registry')!;
      expect(raw, isNot(contains('SECRET')));
      final record = (jsonDecode(raw) as List).single as Map;
      expect(record['fallbackNotificationId'], 11);
      expect(record['cancellationPending'], true);
      plugin.failCancellation = false;
      await service.removeLegacySchedulePayloads();
      expect(prefs.getString('scheduled_alarm_registry'), isNull);
    },
  );
  test(
    'known schedule payload with invalid route ID cleans owned pending',
    () async {
      for (final id in [null, '', ' ', 'a\u0000b', 42]) {
        SharedPreferences.setMockInitialValues({});
        final plugin = _Plugin()..pending.clear();
        plugin.pending.add(
          PendingNotificationRequest(
            77,
            'SECRET',
            '',
            jsonEncode({
              'type': 'schedule_notification',
              'scheduleId': id,
              'scheduleFingerprint': 'SECRET',
            }),
          ),
        );
        plugin.failCancellation = true;
        final service = NotificationService.test(
          localNotifications: plugin,
          isFlutterLocalNotificationsInitialized: true,
        );
        await expectLater(
          service.removeLegacySchedulePayloads(),
          throwsStateError,
        );
        final raw = (await SharedPreferences.getInstance()).getString(
          'scheduled_alarm_registry',
        )!;
        expect(raw, isNot(contains('SECRET')));
        expect((jsonDecode(raw) as List).single['fallbackNotificationId'], 77);
        expect((jsonDecode(raw) as List).single['payload'], isEmpty);
        plugin.failCancellation = false;
        await service.removeLegacySchedulePayloads();
        expect(plugin.pending, isEmpty);
      }
    },
  );

  test(
    'successful cancel call without readback removal is not success',
    () async {
      final plugin = _Plugin()..ignoreCancellation = true;
      final service = NotificationService.test(
        localNotifications: plugin,
        isFlutterLocalNotificationsInitialized: true,
      );
      await expectLater(
        service.removeLegacySchedulePayloads(),
        throwsStateError,
      );
      final raw = (await SharedPreferences.getInstance()).getString(
        'scheduled_alarm_registry',
      )!;
      expect(raw, contains('cancellationPending'));
      expect(raw, isNot(contains('SECRET')));
    },
  );
}

class _Plugin implements FlutterLocalNotificationsPlugin {
  bool failCancellation = false;
  bool ignoreCancellation = false;
  final cancelled = <int>[];
  final pending = <PendingNotificationRequest>[
    PendingNotificationRequest(
      11,
      'SECRET TITLE',
      'generic',
      jsonEncode({
        'type': 'schedule_notification',
        'scheduleId': 'schedule',
        'scheduleFingerprint': 'SECRET PREPARATION',
        'alarmLaunchPayloadVersion': '8',
      }),
    ),
    PendingNotificationRequest(
      12,
      'step',
      'generic',
      jsonEncode({'type': 'preparation_step', 'scheduleId': 'schedule'}),
    ),
  ];
  @override
  Future<List<PendingNotificationRequest>>
  pendingNotificationRequests() async => [...pending];
  @override
  Future<void> cancel({required int id, String? tag}) async {
    cancelled.add(id);
    if (failCancellation) throw StateError('provider unavailable');
    if (!ignoreCancellation) pending.removeWhere((p) => p.id == id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
