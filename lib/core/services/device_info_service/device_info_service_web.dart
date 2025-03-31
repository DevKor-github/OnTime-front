import 'package:on_time_front/core/services/device_info_service/shared.dart';
import 'package:on_time_front/core/services/js_interop_service.dart';

class DeviceInfoService {
  static PlatformType get platformType {
    return PlatformType.web;
  }

  static OsType get osType {
    return OsType.unknown;
  }

  static bool get isInStandaloneMode {
    return JsInteropService.isInStandaloneMode();
  }
}
