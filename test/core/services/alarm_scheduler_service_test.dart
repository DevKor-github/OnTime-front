import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/services/alarm_scheduler_service.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('on_time_front/native_alarm');
  Map<String, dynamic>? pendingPayload;

  setUp(() {
    pendingPayload = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getLaunchPayload') {
            final payload = pendingPayload;
            pendingPayload = null;
            return payload;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'initializeLaunchHandling dispatches cold-start alarm payload',
    () async {
      pendingPayload = {'type': 'schedule_alarm', 'scheduleId': 'schedule-1'};
      final receivedPayloads = <Map<String, String>>[];

      await AlarmSchedulerService().initializeLaunchHandling(
        receivedPayloads.add,
      );

      expect(receivedPayloads, [
        {'type': 'schedule_alarm', 'scheduleId': 'schedule-1'},
      ]);
    },
  );

  test(
    'dispatchPendingLaunchPayload dispatches resumed alarm payload',
    () async {
      final receivedPayloads = <Map<String, String>>[];
      final service = AlarmSchedulerService();
      await service.initializeLaunchHandling(receivedPayloads.add);

      pendingPayload = {'type': 'schedule_alarm', 'scheduleId': 'schedule-2'};
      await service.dispatchPendingLaunchPayload();

      expect(receivedPayloads, [
        {'type': 'schedule_alarm', 'scheduleId': 'schedule-2'},
      ]);
    },
  );

  test('getCapabilities maps native alarm provider capabilities', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getCapabilities') {
            return {
              'supportsNativeAlarm': true,
              'nativeAlarmProvider': 'androidAlarmManager',
              'fallbackProvider': 'localNotification',
            };
          }
          return null;
        });

    final capabilities = await AlarmSchedulerService().getCapabilities();

    expect(capabilities.supportsNativeAlarm, isTrue);
    expect(capabilities.nativeAlarmProvider, AlarmProvider.androidAlarmManager);
    expect(capabilities.fallbackProvider, AlarmProvider.localNotification);
  });

  test(
    'getCapabilities treats missing platform implementation as unsupported',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);

      final capabilities = await AlarmSchedulerService().getCapabilities();

      expect(capabilities, AlarmSchedulerCapabilities.unsupported);
    },
  );

  test(
    'getCapabilities treats native platform errors as unsupported',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'getCapabilities') {
              throw PlatformException(
                code: 'nativeDown',
                message: 'alarm service unavailable',
              );
            }
            return null;
          });

      final capabilities = await AlarmSchedulerService().getCapabilities();

      expect(capabilities, AlarmSchedulerCapabilities.unsupported);
    },
  );

  test('getCapabilities treats null native response as unsupported', () async {
    final capabilities = await AlarmSchedulerService().getCapabilities();

    expect(capabilities, AlarmSchedulerCapabilities.unsupported);
  });

  test(
    'checkPermission and requestPermission map native wire values',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'checkPermission') {
              return 'denied';
            }
            if (call.method == 'requestPermission') {
              return 'granted';
            }
            return null;
          });

      final service = AlarmSchedulerService();

      expect(await service.checkPermission(), AlarmPermissionState.denied);
      expect(await service.requestPermission(), AlarmPermissionState.granted);
    },
  );

  test(
    'permission checks treat missing platform implementation as unsupported',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      final service = AlarmSchedulerService();

      expect(await service.checkPermission(), AlarmPermissionState.unsupported);
      expect(
        await service.requestPermission(),
        AlarmPermissionState.unsupported,
      );
    },
  );

  test(
    'permission checks treat native platform errors as unsupported',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(
              code: 'nativeDown',
              message: 'permission API unavailable',
            );
          });
      final service = AlarmSchedulerService();

      expect(await service.checkPermission(), AlarmPermissionState.unsupported);
      expect(
        await service.requestPermission(),
        AlarmPermissionState.unsupported,
      );
    },
  );

  test('scheduleNativeAlarm sends the native alarm contract payload', () async {
    Map<Object?, Object?>? nativeArguments;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'scheduleNativeAlarm') {
            nativeArguments = (call.arguments as Map).cast<Object?, Object?>();
          }
          return null;
        });

    final alarmTime = DateTime.utc(2026, 5, 15, 8);
    final preparationStartTime = DateTime.utc(2026, 5, 15, 8, 5);
    await AlarmSchedulerService().scheduleNativeAlarm(
      ScheduledAlarmRecord(
        scheduleId: 'schedule-1',
        alarmTime: alarmTime,
        preparationStartTime: preparationStartTime,
        scheduleFingerprint: 'fingerprint',
        provider: AlarmProvider.androidAlarmManager,
        scheduleTitle: 'Morning meeting',
        payload: const {'type': 'schedule_alarm', 'scheduleId': 'schedule-1'},
      ),
    );

    expect(nativeArguments, isNotNull);
    expect(nativeArguments!['scheduleId'], 'schedule-1');
    expect(nativeArguments!['alarmTime'], alarmTime.millisecondsSinceEpoch);
    expect(
      nativeArguments!['preparationStartTime'],
      preparationStartTime.millisecondsSinceEpoch,
    );
    expect(nativeArguments!['nativeAlarmId'], stableAlarmId('schedule-1'));
    expect(nativeArguments!['provider'], 'androidAlarmManager');
    expect(nativeArguments!['title'], 'Morning meeting');
    expect(nativeArguments!['body'], 'It is time to get ready.');
    expect(nativeArguments!['payload'], {
      'type': 'schedule_alarm',
      'scheduleId': 'schedule-1',
    });
  });

  test(
    'scheduleNativeAlarm exposes permission failures as scheduling exception',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(
              code: 'permissionDenied',
              message: 'exact alarm permission missing',
            );
          });

      await expectLater(
        AlarmSchedulerService().scheduleNativeAlarm(_scheduledAlarmRecord()),
        throwsA(
          isA<AlarmSchedulingException>()
              .having(
                (error) => error.reason,
                'reason',
                AlarmFailureReason.platformError,
              )
              .having(
                (error) => error.permissionIssue,
                'permissionIssue',
                AlarmPermissionIssue.nativePermissionDenied,
              )
              .having(
                (error) => error.message,
                'message',
                'exact alarm permission missing',
              ),
        ),
      );
    },
  );

  test(
    'scheduleNativeAlarm maps unsupported and generic native errors',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'scheduleNativeAlarm') {
              throw PlatformException(code: 'unsupported');
            }
            return null;
          });

      await expectLater(
        AlarmSchedulerService().scheduleNativeAlarm(_scheduledAlarmRecord()),
        throwsA(
          isA<AlarmSchedulingException>()
              .having(
                (error) => error.reason,
                'reason',
                AlarmFailureReason.platformError,
              )
              .having(
                (error) => error.message,
                'message',
                'Native alarms are unsupported',
              ),
        ),
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'scheduleNativeAlarm') {
              throw PlatformException(code: 'nativeDown');
            }
            return null;
          });

      await expectLater(
        AlarmSchedulerService().scheduleNativeAlarm(_scheduledAlarmRecord()),
        throwsA(
          isA<AlarmSchedulingException>().having(
            (error) => error.message,
            'message',
            'nativeDown',
          ),
        ),
      );
    },
  );

  test(
    'cancelNativeAlarm sends cancellation payload for scheduled records',
    () async {
      Map<Object?, Object?>? nativeArguments;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'cancelNativeAlarm') {
              nativeArguments = (call.arguments as Map)
                  .cast<Object?, Object?>();
            }
            return null;
          });

      await AlarmSchedulerService().cancelNativeAlarm(
        _scheduledAlarmRecord(nativeAlarmId: 42),
      );

      expect(nativeArguments, isNotNull);
      expect(nativeArguments!['scheduleId'], 'schedule-1');
      expect(nativeArguments!['nativeAlarmId'], 42);
    },
  );

  test('cancelNativeAlarm ignores missing native platform', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);

    await AlarmSchedulerService().cancelNativeAlarm(_scheduledAlarmRecord());
  });

  test(
    'cancelNativeAlarm maps native platform failures to scheduling exception',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'cancelNativeAlarm') {
              throw PlatformException(
                code: 'permissionDenied',
                message: 'cannot cancel without permission',
              );
            }
            return null;
          });

      await expectLater(
        AlarmSchedulerService().cancelNativeAlarm(_scheduledAlarmRecord()),
        throwsA(
          isA<AlarmSchedulingException>()
              .having(
                (error) => error.reason,
                'reason',
                AlarmFailureReason.platformError,
              )
              .having(
                (error) => error.permissionIssue,
                'permissionIssue',
                AlarmPermissionIssue.nativePermissionDenied,
              )
              .having(
                (error) => error.message,
                'message',
                'cannot cancel without permission',
              ),
        ),
      );
    },
  );

  test(
    'cancelAllNativeAlarms cancels every provided record in order',
    () async {
      final canceledIds = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'cancelNativeAlarm') {
              canceledIds.add(
                ((call.arguments as Map<Object?, Object?>)['scheduleId']
                    as String),
              );
            }
            return null;
          });

      await AlarmSchedulerService().cancelAllNativeAlarms([
        _scheduledAlarmRecord(scheduleId: 'schedule-1'),
        _scheduledAlarmRecord(scheduleId: 'schedule-2'),
      ]);

      expect(canceledIds, ['schedule-1', 'schedule-2']);
    },
  );

  test(
    'dispatchPendingLaunchPayload ignores invalid and failed payload reads',
    () async {
      final receivedPayloads = <Map<String, String>>[];
      final service = AlarmSchedulerService();
      await service.initializeLaunchHandling(receivedPayloads.add);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'getLaunchPayload') {
              return 'not-a-map';
            }
            return null;
          });
      await service.dispatchPendingLaunchPayload();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'getLaunchPayload') {
              throw PlatformException(code: 'boom');
            }
            return null;
          });
      await service.dispatchPendingLaunchPayload();

      expect(receivedPayloads, isEmpty);
    },
  );
}

ScheduledAlarmRecord _scheduledAlarmRecord({
  String scheduleId = 'schedule-1',
  int? nativeAlarmId,
}) {
  return ScheduledAlarmRecord(
    scheduleId: scheduleId,
    alarmTime: DateTime.utc(2026, 5, 15, 8),
    preparationStartTime: DateTime.utc(2026, 5, 15, 8, 5),
    scheduleFingerprint: 'fingerprint',
    nativeAlarmId: nativeAlarmId,
    provider: AlarmProvider.androidAlarmManager,
    scheduleTitle: 'Morning meeting',
    payload: {'type': 'schedule_alarm', 'scheduleId': scheduleId},
  );
}
