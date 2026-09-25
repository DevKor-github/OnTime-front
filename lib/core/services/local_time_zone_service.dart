import '../time/time_zone_rules.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract final class LocalTimeZoneService {
  static const _channel = MethodChannel('on_time_front/native_alarm');

  static Future<String> current() async {
    if (kIsWeb) throw const LocalTimeZoneUnavailable();
    try {
      final identifier = await _channel.invokeMethod<String>(
        'getLocalTimeZone',
      );
      if (identifier == null || !TimeZoneRules.contains(identifier)) {
        throw const LocalTimeZoneUnavailable();
      }
      return identifier;
    } catch (_) {
      throw const LocalTimeZoneUnavailable();
    }
  }
}

class LocalTimeZoneUnavailable implements Exception {
  const LocalTimeZoneUnavailable();
}
