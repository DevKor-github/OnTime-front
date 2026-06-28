import 'package:equatable/equatable.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';

enum AlarmDeliveryMode { nativeAlarm, fallbackNotification, unavailable }

class AlarmDeliveryPolicy extends Equatable {
  const AlarmDeliveryPolicy._({
    required this.mode,
    required this.activeProvider,
    required this.blockingPermissionIssue,
    required this.recoveryPermissionIssue,
  });

  factory AlarmDeliveryPolicy.evaluate({
    required AlarmSchedulerCapabilities capabilities,
    required AlarmPermissionState nativePermission,
    required AlarmPermissionState fallbackPermission,
  }) {
    if (capabilities.supportsNativeAlarm &&
        capabilities.nativeAlarmProvider != AlarmProvider.none &&
        nativePermission == AlarmPermissionState.granted) {
      return AlarmDeliveryPolicy._(
        mode: AlarmDeliveryMode.nativeAlarm,
        activeProvider: capabilities.nativeAlarmProvider,
        blockingPermissionIssue: null,
        recoveryPermissionIssue: null,
      );
    }

    if (capabilities.fallbackProvider == AlarmProvider.localNotification &&
        fallbackPermission == AlarmPermissionState.granted) {
      return AlarmDeliveryPolicy._(
        mode: AlarmDeliveryMode.fallbackNotification,
        activeProvider: AlarmProvider.localNotification,
        blockingPermissionIssue: null,
        recoveryPermissionIssue: _nativeRecoveryIssue(
          capabilities,
          nativePermission,
        ),
      );
    }

    final blockingIssue = _blockingPermissionIssue(
      capabilities,
      nativePermission,
      fallbackPermission,
    );
    return AlarmDeliveryPolicy._(
      mode: AlarmDeliveryMode.unavailable,
      activeProvider: AlarmProvider.none,
      blockingPermissionIssue: blockingIssue,
      recoveryPermissionIssue: null,
    );
  }

  final AlarmDeliveryMode mode;
  final AlarmProvider activeProvider;
  final AlarmPermissionIssue? blockingPermissionIssue;
  final AlarmPermissionIssue? recoveryPermissionIssue;

  bool get canDeliver => activeProvider != AlarmProvider.none;

  bool get isUnsupported {
    return mode == AlarmDeliveryMode.unavailable &&
        blockingPermissionIssue == null;
  }

  bool get shouldDisableAlarms {
    return mode == AlarmDeliveryMode.unavailable &&
        blockingPermissionIssue != null;
  }

  @override
  List<Object?> get props => [
    mode,
    activeProvider,
    blockingPermissionIssue,
    recoveryPermissionIssue,
  ];

  static AlarmPermissionIssue? _nativeRecoveryIssue(
    AlarmSchedulerCapabilities capabilities,
    AlarmPermissionState nativePermission,
  ) {
    if (!capabilities.supportsNativeAlarm ||
        capabilities.nativeAlarmProvider == AlarmProvider.none) {
      return null;
    }
    if (nativePermission == AlarmPermissionState.denied ||
        nativePermission == AlarmPermissionState.notDetermined) {
      return AlarmPermissionIssue.nativePermissionDenied;
    }
    return null;
  }

  static AlarmPermissionIssue? _blockingPermissionIssue(
    AlarmSchedulerCapabilities capabilities,
    AlarmPermissionState nativePermission,
    AlarmPermissionState fallbackPermission,
  ) {
    if (capabilities.supportsNativeAlarm &&
        capabilities.nativeAlarmProvider != AlarmProvider.none &&
        (nativePermission == AlarmPermissionState.denied ||
            nativePermission == AlarmPermissionState.notDetermined)) {
      return AlarmPermissionIssue.nativePermissionDenied;
    }
    if (capabilities.fallbackProvider == AlarmProvider.localNotification &&
        (fallbackPermission == AlarmPermissionState.denied ||
            fallbackPermission == AlarmPermissionState.notDetermined)) {
      return AlarmPermissionIssue.notificationPermissionDenied;
    }
    return null;
  }
}
