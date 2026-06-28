import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/alarm_delivery_policy.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';

void main() {
  test('native grant uses the native alarm provider', () {
    final decision = AlarmDeliveryPolicy.evaluate(
      capabilities: const AlarmSchedulerCapabilities(
        supportsNativeAlarm: true,
        nativeAlarmProvider: AlarmProvider.androidAlarmManager,
        fallbackProvider: AlarmProvider.localNotification,
      ),
      nativePermission: AlarmPermissionState.granted,
      fallbackPermission: AlarmPermissionState.denied,
    );

    expect(decision.mode, AlarmDeliveryMode.nativeAlarm);
    expect(decision.activeProvider, AlarmProvider.androidAlarmManager);
    expect(decision.canDeliver, isTrue);
    expect(decision.blockingPermissionIssue, isNull);
    expect(decision.recoveryPermissionIssue, isNull);
    expect(decision.shouldDisableAlarms, isFalse);
  });

  test(
    'native denial with granted fallback keeps delivery enabled without a blocking issue',
    () {
      final decision = AlarmDeliveryPolicy.evaluate(
        capabilities: const AlarmSchedulerCapabilities(
          supportsNativeAlarm: true,
          nativeAlarmProvider: AlarmProvider.androidAlarmManager,
          fallbackProvider: AlarmProvider.localNotification,
        ),
        nativePermission: AlarmPermissionState.denied,
        fallbackPermission: AlarmPermissionState.granted,
      );

      expect(decision.mode, AlarmDeliveryMode.fallbackNotification);
      expect(decision.canDeliver, isTrue);
      expect(decision.blockingPermissionIssue, isNull);
      expect(
        decision.recoveryPermissionIssue,
        AlarmPermissionIssue.nativePermissionDenied,
      );
      expect(decision.shouldDisableAlarms, isFalse);
    },
  );

  test(
    'native denial with denied fallback blocks delivery on native permission',
    () {
      final decision = AlarmDeliveryPolicy.evaluate(
        capabilities: const AlarmSchedulerCapabilities(
          supportsNativeAlarm: true,
          nativeAlarmProvider: AlarmProvider.androidAlarmManager,
          fallbackProvider: AlarmProvider.localNotification,
        ),
        nativePermission: AlarmPermissionState.denied,
        fallbackPermission: AlarmPermissionState.denied,
      );

      expect(decision.mode, AlarmDeliveryMode.unavailable);
      expect(decision.canDeliver, isFalse);
      expect(
        decision.blockingPermissionIssue,
        AlarmPermissionIssue.nativePermissionDenied,
      );
      expect(decision.shouldDisableAlarms, isTrue);
    },
  );

  test('unsupported native alarms use granted fallback delivery', () {
    final decision = AlarmDeliveryPolicy.evaluate(
      capabilities: const AlarmSchedulerCapabilities(
        supportsNativeAlarm: false,
        nativeAlarmProvider: AlarmProvider.none,
        fallbackProvider: AlarmProvider.localNotification,
      ),
      nativePermission: AlarmPermissionState.unsupported,
      fallbackPermission: AlarmPermissionState.granted,
    );

    expect(decision.mode, AlarmDeliveryMode.fallbackNotification);
    expect(decision.activeProvider, AlarmProvider.localNotification);
    expect(decision.blockingPermissionIssue, isNull);
    expect(decision.recoveryPermissionIssue, isNull);
    expect(decision.shouldDisableAlarms, isFalse);
  });

  test('all unavailable reports unsupported without disabling alarms', () {
    final decision = AlarmDeliveryPolicy.evaluate(
      capabilities: AlarmSchedulerCapabilities.unsupported,
      nativePermission: AlarmPermissionState.unsupported,
      fallbackPermission: AlarmPermissionState.unsupported,
    );

    expect(decision.mode, AlarmDeliveryMode.unavailable);
    expect(decision.canDeliver, isFalse);
    expect(decision.isUnsupported, isTrue);
    expect(decision.blockingPermissionIssue, isNull);
    expect(decision.shouldDisableAlarms, isFalse);
  });
}
