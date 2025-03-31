export 'device_info_service_unsupported.dart'
    if (dart.library.html) 'device_info_service_web.dart'
    if (dart.library.io) 'device_info_service_mobile.dart';

enum PlatformType {
  android,
  ios,
  web,
}

enum OsType {
  android,
  ios,
  macos,
  windows,
  linux,
  unknown,
}
