import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';

typedef AlarmLaunchPayloadHandler = void Function(Map<String, String> payload);

@Singleton()
class AlarmSchedulerService {
  static const _channel = MethodChannel('on_time_front/native_alarm');

  AlarmLaunchPayloadHandler? _launchPayloadHandler;

  Future<AlarmSchedulerCapabilities> getCapabilities() async {
    if (kIsWeb) {
      return AlarmSchedulerCapabilities.unsupported;
    }
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'getCapabilities',
      );
      return _capabilitiesFromMap(raw);
    } on MissingPluginException {
      return AlarmSchedulerCapabilities.unsupported;
    } on PlatformException {
      return AlarmSchedulerCapabilities.unsupported;
    }
  }

  Future<AlarmPermissionState> checkPermission() async {
    if (kIsWeb) return AlarmPermissionState.unsupported;
    try {
      final raw = await _channel.invokeMethod<String>('checkPermission');
      return AlarmPermissionStateWireValue.fromWireValue(raw);
    } on MissingPluginException {
      return AlarmPermissionState.unsupported;
    } on PlatformException {
      return AlarmPermissionState.unsupported;
    }
  }

  Future<AlarmPermissionState> requestPermission() async {
    if (kIsWeb) return AlarmPermissionState.unsupported;
    try {
      final raw = await _channel.invokeMethod<String>('requestPermission');
      return AlarmPermissionStateWireValue.fromWireValue(raw);
    } on MissingPluginException {
      return AlarmPermissionState.unsupported;
    } on PlatformException {
      return AlarmPermissionState.unsupported;
    }
  }

  Future<void> scheduleNativeAlarm(ScheduledAlarmRecord record) async {
    try {
      await _channel.invokeMethod<void>(
        'scheduleNativeAlarm',
        _recordToMethodArguments(record),
      );
    } on PlatformException catch (error) {
      throw _exceptionFromPlatformException(error);
    }
  }

  Future<void> cancelNativeAlarm(ScheduledAlarmRecord record) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>(
        'cancelNativeAlarm',
        _recordToMethodArguments(record),
      );
    } on MissingPluginException {
      return;
    } on PlatformException catch (error) {
      throw _exceptionFromPlatformException(error);
    }
  }

  Future<void> cancelAllNativeAlarms(
    List<ScheduledAlarmRecord> records,
  ) async {
    for (final record in records) {
      await cancelNativeAlarm(record);
    }
  }

  Future<void> initializeLaunchHandling(
    AlarmLaunchPayloadHandler onPayload,
  ) async {
    _launchPayloadHandler = onPayload;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'alarmLaunch') {
        final payload = _payloadFromObject(call.arguments);
        if (payload != null) {
          _launchPayloadHandler?.call(payload);
        }
      }
    });

    if (kIsWeb) return;
    try {
      final initialPayload = await _channel.invokeMapMethod<String, dynamic>(
        'getLaunchPayload',
      );
      final payload = _payloadFromObject(initialPayload);
      if (payload != null) {
        _launchPayloadHandler?.call(payload);
      }
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  Map<String, dynamic> _recordToMethodArguments(ScheduledAlarmRecord record) {
    return {
      'scheduleId': record.scheduleId,
      'alarmTime': record.alarmTime.millisecondsSinceEpoch,
      'preparationStartTime':
          record.preparationStartTime.millisecondsSinceEpoch,
      'nativeAlarmId': record.nativeAlarmId ?? stableAlarmId(record.scheduleId),
      'title': record.scheduleTitle,
      'body': 'It is time to get ready.',
      'payload': record.payload,
    };
  }

  AlarmSchedulerCapabilities _capabilitiesFromMap(Map<String, dynamic>? raw) {
    if (raw == null) {
      return AlarmSchedulerCapabilities.unsupported;
    }
    return AlarmSchedulerCapabilities(
      supportsNativeAlarm: raw['supportsNativeAlarm'] as bool? ?? false,
      nativeAlarmProvider: AlarmProviderWireValue.fromWireValue(
        raw['nativeAlarmProvider'] as String?,
      ),
      fallbackProvider: AlarmProviderWireValue.fromWireValue(
        raw['fallbackProvider'] as String?,
      ),
    );
  }

  AlarmSchedulingException _exceptionFromPlatformException(
    PlatformException error,
  ) {
    switch (error.code) {
      case 'permissionDenied':
        return AlarmSchedulingException(
          reason: AlarmFailureReason.platformError,
          permissionIssue: AlarmPermissionIssue.nativePermissionDenied,
          message: error.message ?? 'Native alarm permission denied',
        );
      case 'unsupported':
        return AlarmSchedulingException(
          reason: AlarmFailureReason.platformError,
          message: error.message ?? 'Native alarms are unsupported',
        );
      default:
        return AlarmSchedulingException(
          reason: AlarmFailureReason.platformError,
          message: error.message ?? error.code,
        );
    }
  }

  Map<String, String>? _payloadFromObject(Object? raw) {
    if (raw is! Map) return null;
    return raw.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
  }
}
