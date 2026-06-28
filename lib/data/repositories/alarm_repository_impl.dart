import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/services/alarm_scheduler_service.dart';
import 'package:on_time_front/core/services/app_metadata_service.dart';
import 'package:on_time_front/core/services/device_info_service/shared.dart';
import 'package:on_time_front/core/validation/backend_constraints.dart';
import 'package:on_time_front/data/data_sources/alarm_remote_data_source.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/repositories/alarm_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

@Singleton(as: AlarmRepository)
class AlarmRepositoryImpl implements AlarmRepository {
  final AlarmRemoteDataSource remoteDataSource;
  final AlarmSchedulerService schedulerService;
  final AppMetadataProvider appMetadataProvider;

  AlarmRepositoryImpl({
    required this.remoteDataSource,
    required this.schedulerService,
    required this.appMetadataProvider,
  });

  static const _deviceIdKey = 'alarm_device_id';

  @override
  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null &&
        BackendConstraints.deviceIdPattern.hasMatch(existing)) {
      return existing;
    }

    final next = const Uuid().v4();
    await prefs.setString(_deviceIdKey, next);
    return next;
  }

  @override
  Future<AlarmDeviceInfo> buildCurrentDeviceInfo() async {
    final capabilities = await schedulerService.getCapabilities();
    final metadata = await appMetadataProvider.getMetadata();
    return AlarmDeviceInfo(
      deviceId: await getDeviceId(),
      platform: _platformWireValue(),
      appVersion: metadata.version,
      osVersion: _osWireValue(),
      supportsNativeAlarm: capabilities.supportsNativeAlarm,
      nativeAlarmProvider: capabilities.nativeAlarmProvider,
      fallbackProvider: capabilities.fallbackProvider,
    );
  }

  @override
  Future<AlarmSettings> getAlarmSettings() {
    return remoteDataSource.getAlarmSettings();
  }

  @override
  Future<AlarmSettings> updateAlarmSettings({required bool alarmsEnabled}) {
    return remoteDataSource.updateAlarmSettings(alarmsEnabled: alarmsEnabled);
  }

  @override
  Future<void> registerCurrentDevice(AlarmDeviceInfo deviceInfo) {
    return remoteDataSource.registerCurrentDevice(deviceInfo);
  }

  @override
  Future<void> unregisterCurrentDevice(String deviceId) {
    return remoteDataSource.unregisterCurrentDevice(deviceId);
  }

  @override
  Future<List<ScheduleWithPreparationEntity>> getAlarmWindow(
    DateTime startDate,
    DateTime endDate,
  ) {
    return remoteDataSource.getAlarmWindow(startDate, endDate);
  }

  @override
  Future<void> postAlarmStatus(AlarmStatusReport report) {
    return remoteDataSource.postAlarmStatus(report);
  }

  String _platformWireValue() {
    try {
      switch (DeviceInfoService.platformType) {
        case PlatformType.android:
          return 'android';
        case PlatformType.ios:
          return 'ios';
        case PlatformType.web:
          return 'web';
      }
    } catch (_) {
      return 'unknown';
    }
  }

  String _osWireValue() {
    try {
      switch (DeviceInfoService.osType) {
        case OsType.android:
          return 'android';
        case OsType.ios:
          return 'ios';
        case OsType.macos:
          return 'macos';
        case OsType.windows:
          return 'windows';
        case OsType.linux:
          return 'linux';
        case OsType.unknown:
          return 'unknown';
      }
    } catch (_) {
      return 'unknown';
    }
  }
}
