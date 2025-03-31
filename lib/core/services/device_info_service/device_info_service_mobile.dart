import 'dart:io';

import 'package:on_time_front/core/services/device_info_service/shared.dart';

class DeviceInfoService {
  static PlatformType get platformType {
    if (Platform.isAndroid) {
      return PlatformType.android;
    } else if (Platform.isIOS) {
      return PlatformType.ios;
    } else {
      throw UnimplementedError(
          'DeviceInfoService is not supported on this platform.');
    }
  }

  static OsType get osType {
    if (Platform.isAndroid) {
      return OsType.android;
    } else if (Platform.isIOS) {
      return OsType.ios;
    } else {
      return OsType.unknown;
    }
  }

  static bool get isInStandaloneMode {
    // In mobile, we are always in standalone mode
    return true;
  }
}
