import 'dart:js_interop';

@JS()
external JSPromise<JSString> _requestNotificationPermission();

@JS()
external JSBoolean _isInStandaloneMode();

class JsInteropService {
  static Future<String> requestNotificationPermission() {
    return _requestNotificationPermission()
        .toDart
        .then((jsString) => jsString.toString());
  }

  static bool isInStandaloneMode() {
    return _isInStandaloneMode().toDart;
  }
}
