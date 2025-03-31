import 'package:on_time_front/core/services/device_info_service/shared.dart';

class DeviceInfoService {
  static PlatformType get platformType => throw UnimplementedError(
      'DeviceInfoService is not supported on this platform.');

  static OsType get osType => throw UnimplementedError(
      'DeviceInfoService is not supported on this platform.');

  static bool get isInStandaloneMode => throw UnimplementedError(
      'DeviceInfoService is not supported on this platform.');
}
