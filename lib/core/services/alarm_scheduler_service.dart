import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/logging/app_logger.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';

typedef AlarmLaunchPayloadHandler = void Function(Map<String, String> payload);

@Singleton()
class AlarmSchedulerService {
  static const _channel = MethodChannel('on_time_front/native_alarm');
  static const _logTag = '[AlarmSchedulerService]';

  AlarmLaunchPayloadHandler? _launchPayloadHandler;

  Future<AlarmSchedulerCapabilities> getCapabilities() async {
    if (kIsWeb) {
      AppLogger.debug('$_logTag getCapabilities -> unsupported: web');
      return AlarmSchedulerCapabilities.unsupported;
    }
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'getCapabilities',
      );
      final capabilities = _capabilitiesFromMap(raw);
      AppLogger.debug('$_logTag getCapabilities -> $capabilities');
      return capabilities;
    } on MissingPluginException {
      AppLogger.debug(
          '$_logTag getCapabilities -> unsupported: missing plugin');
      return AlarmSchedulerCapabilities.unsupported;
    } on PlatformException catch (error) {
      AppLogger.debug(
        '$_logTag getCapabilities platform error: '
        '${error.code} ${error.message}',
      );
      return AlarmSchedulerCapabilities.unsupported;
    }
  }

  Future<AlarmPermissionState> checkPermission() async {
    if (kIsWeb) {
      AppLogger.debug('$_logTag checkPermission -> unsupported: web');
      return AlarmPermissionState.unsupported;
    }
    try {
      final raw = await _channel.invokeMethod<String>('checkPermission');
      final state = AlarmPermissionStateWireValue.fromWireValue(raw);
      AppLogger.debug('$_logTag checkPermission -> $state');
      return state;
    } on MissingPluginException {
      AppLogger.debug(
          '$_logTag checkPermission -> unsupported: missing plugin');
      return AlarmPermissionState.unsupported;
    } on PlatformException catch (error) {
      AppLogger.debug(
        '$_logTag checkPermission platform error: '
        '${error.code} ${error.message}',
      );
      return AlarmPermissionState.unsupported;
    }
  }

  Future<AlarmPermissionState> requestPermission() async {
    if (kIsWeb) {
      AppLogger.debug('$_logTag requestPermission -> unsupported: web');
      return AlarmPermissionState.unsupported;
    }
    try {
      final raw = await _channel.invokeMethod<String>('requestPermission');
      final state = AlarmPermissionStateWireValue.fromWireValue(raw);
      AppLogger.debug('$_logTag requestPermission -> $state');
      return state;
    } on MissingPluginException {
      AppLogger.debug(
          '$_logTag requestPermission -> unsupported: missing plugin');
      return AlarmPermissionState.unsupported;
    } on PlatformException catch (error) {
      AppLogger.debug(
        '$_logTag requestPermission platform error: '
        '${error.code} ${error.message}',
      );
      return AlarmPermissionState.unsupported;
    }
  }

  Future<void> scheduleNativeAlarm(ScheduledAlarmRecord record) async {
    try {
      AppLogger.debug(
        '$_logTag scheduleNativeAlarm start '
        'scheduleId=${record.scheduleId} '
        'nativeAlarmId=${record.nativeAlarmId} '
        'alarmTime=${record.alarmTime.toIso8601String()} '
        'provider=${record.provider}',
      );
      await _channel.invokeMethod<void>(
        'scheduleNativeAlarm',
        _recordToMethodArguments(record),
      );
      AppLogger.debug(
        '$_logTag scheduleNativeAlarm success '
        'scheduleId=${record.scheduleId}',
      );
    } on PlatformException catch (error) {
      AppLogger.debug(
        '$_logTag scheduleNativeAlarm platform error '
        'scheduleId=${record.scheduleId} code=${error.code} '
        'message=${error.message}',
      );
      throw _exceptionFromPlatformException(error);
    }
  }

  Future<void> cancelNativeAlarm(ScheduledAlarmRecord record) async {
    if (kIsWeb) {
      AppLogger.debug(
        '$_logTag cancelNativeAlarm skipped on web '
        'scheduleId=${record.scheduleId}',
      );
      return;
    }
    try {
      AppLogger.debug(
        '$_logTag cancelNativeAlarm start '
        'scheduleId=${record.scheduleId} '
        'nativeAlarmId=${record.nativeAlarmId}',
      );
      await _channel.invokeMethod<void>(
        'cancelNativeAlarm',
        _recordToMethodArguments(record),
      );
      AppLogger.debug(
        '$_logTag cancelNativeAlarm success '
        'scheduleId=${record.scheduleId}',
      );
    } on MissingPluginException {
      AppLogger.debug(
        '$_logTag cancelNativeAlarm skipped: missing plugin '
        'scheduleId=${record.scheduleId}',
      );
      return;
    } on PlatformException catch (error) {
      AppLogger.debug(
        '$_logTag cancelNativeAlarm platform error '
        'scheduleId=${record.scheduleId} code=${error.code} '
        'message=${error.message}',
      );
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
    AppLogger.debug('$_logTag initializeLaunchHandling');
    _launchPayloadHandler = onPayload;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'alarmLaunch') {
        final payload = _payloadFromObject(call.arguments);
        AppLogger.debug(
          '$_logTag alarmLaunch callback '
          '${AppLogger.summarizeMap(payload)}',
        );
        if (payload != null) {
          _launchPayloadHandler?.call(payload);
        }
      }
    });

    await dispatchPendingLaunchPayload();
  }

  Future<void> dispatchPendingLaunchPayload() async {
    final launchPayloadHandler = _launchPayloadHandler;
    if (launchPayloadHandler == null) {
      AppLogger.debug(
          '$_logTag dispatchPendingLaunchPayload skipped: no handler');
      return;
    }
    if (kIsWeb) {
      AppLogger.debug('$_logTag dispatchPendingLaunchPayload skipped: web');
      return;
    }
    try {
      final initialPayload = await _channel.invokeMapMethod<String, dynamic>(
        'getLaunchPayload',
      );
      final payload = _payloadFromObject(initialPayload);
      AppLogger.debug(
        '$_logTag getLaunchPayload -> ${AppLogger.summarizeMap(payload)}',
      );
      if (payload != null) {
        launchPayloadHandler(payload);
      }
    } on MissingPluginException {
      AppLogger.debug('$_logTag getLaunchPayload skipped: missing plugin');
      return;
    } on PlatformException catch (error) {
      AppLogger.debug(
        '$_logTag getLaunchPayload platform error: '
        '${error.code} ${error.message}',
      );
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
      'provider': record.provider.wireValue,
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
