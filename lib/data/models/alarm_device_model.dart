import 'package:on_time_front/domain/entities/alarm_entities.dart';

class AlarmDeviceInfoModel {
  final String deviceId;
  final String platform;
  final String appVersion;
  final String osVersion;
  final bool supportsNativeAlarm;
  final AlarmProvider nativeAlarmProvider;
  final AlarmProvider fallbackProvider;

  const AlarmDeviceInfoModel({
    required this.deviceId,
    required this.platform,
    required this.appVersion,
    required this.osVersion,
    required this.supportsNativeAlarm,
    required this.nativeAlarmProvider,
    required this.fallbackProvider,
  });

  factory AlarmDeviceInfoModel.fromEntity(AlarmDeviceInfo entity) {
    return AlarmDeviceInfoModel(
      deviceId: entity.deviceId,
      platform: entity.platform,
      appVersion: entity.appVersion,
      osVersion: entity.osVersion,
      supportsNativeAlarm: entity.supportsNativeAlarm,
      nativeAlarmProvider: entity.nativeAlarmProvider,
      fallbackProvider: entity.fallbackProvider,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'platform': platform,
      'appVersion': appVersion,
      'osVersion': osVersion,
      'supportsNativeAlarm': supportsNativeAlarm,
      'nativeAlarmProvider': nativeAlarmProvider.wireValue,
      'fallbackProvider': fallbackProvider.wireValue,
    };
  }
}
