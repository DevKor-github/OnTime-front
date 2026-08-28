import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract final class LocalTimeZoneService {
  static const _channel = MethodChannel('on_time_front/native_alarm');

  static Future<String> current() async {
    if (kIsWeb) return 'UTC';
    try {
      final identifier = await _channel.invokeMethod<String>(
        'getLocalTimeZone',
      );
      return identifier == null || identifier.isEmpty ? 'UTC' : identifier;
    } catch (_) {
      // A missing platform binding/plugin must not prevent local scheduling or
      // recovery mode from starting. UTC is the deterministic safe fallback.
      return 'UTC';
    }
  }
}
