import 'package:on_time_front/core/services/js_interop_service.dart';

Future<String> requestNotificationPermission() {
  return JsInteropService.requestNotificationPermission();
}
