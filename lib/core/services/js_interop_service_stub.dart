class JsInteropService {
  static Future<String> requestNotificationPermission() async {
    throw UnsupportedError('JsInteropService is only available on web');
  }

  static bool isInStandaloneMode() {
    throw UnsupportedError('JsInteropService is only available on web');
  }
}
