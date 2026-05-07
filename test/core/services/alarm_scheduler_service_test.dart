import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/services/alarm_scheduler_service.dart';

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

  test('initializeLaunchHandling dispatches cold-start alarm payload',
      () async {
    pendingPayload = {
      'type': 'schedule_alarm',
      'scheduleId': 'schedule-1',
    };
    final receivedPayloads = <Map<String, String>>[];

    await AlarmSchedulerService().initializeLaunchHandling(
      receivedPayloads.add,
    );

    expect(receivedPayloads, [
      {
        'type': 'schedule_alarm',
        'scheduleId': 'schedule-1',
      },
    ]);
  });

  test('dispatchPendingLaunchPayload dispatches resumed alarm payload',
      () async {
    final receivedPayloads = <Map<String, String>>[];
    final service = AlarmSchedulerService();
    await service.initializeLaunchHandling(receivedPayloads.add);

    pendingPayload = {
      'type': 'schedule_alarm',
      'scheduleId': 'schedule-2',
    };
    await service.dispatchPendingLaunchPayload();

    expect(receivedPayloads, [
      {
        'type': 'schedule_alarm',
        'scheduleId': 'schedule-2',
      },
    ]);
  });
}
