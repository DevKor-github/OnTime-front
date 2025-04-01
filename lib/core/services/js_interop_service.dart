import 'dart:js_interop';

@JS()
external JSPromise<JSString> _requestNotificationPermission();

class JsInteropService {
  static Future<String> requestNotificationPermission() {
    return _requestNotificationPermission()
        .toDart
        .then((jsString) => jsString.toString());
  }
}
