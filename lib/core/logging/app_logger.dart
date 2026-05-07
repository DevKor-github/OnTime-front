import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

final class AppLogger {
  const AppLogger._();

  static const redacted = '<redacted>';
  static const omitted = '<omitted>';

  static bool get isEnabled => kDebugMode;

  static void configureFlutterDebugPrint() {
    if (!kDebugMode) {
      debugPrint = _discardDebugPrint;
    }
  }

  static void debug(
    String message, {
    String name = 'OnTime',
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode) return;
    developer.log(
      redactText(message),
      name: name,
      error: error == null ? null : redactValue(error),
      stackTrace: stackTrace,
    );
  }

  static Object? redactValue(Object? value) {
    if (value == null) return null;
    if (value is Uri) return redactUri(value);
    if (value is Map) {
      return value.map((key, nestedValue) {
        final keyText = key.toString();
        if (_isSensitiveKey(keyText)) {
          return MapEntry(key, redacted);
        }
        return MapEntry(key, redactValue(nestedValue));
      });
    }
    if (value is Iterable && value is! String) {
      return value.map(redactValue).toList(growable: false);
    }
    return redactText(value.toString());
  }

  static Map<String, dynamic> redactMap(Map<dynamic, dynamic> values) {
    return values.map(
      (key, value) => MapEntry(key.toString(), redactValueForKey(key, value)),
    );
  }

  static Object? redactValueForKey(Object? key, Object? value) {
    if (_isSensitiveKey(key?.toString() ?? '')) {
      return redacted;
    }
    return redactValue(value);
  }

  static String redactUri(Uri uri) {
    if (!uri.hasQuery) return uri.toString();
    final redactedParameters = uri.queryParameters.map(
      (key, value) => MapEntry(key, redactValueForKey(key, value).toString()),
    );
    return uri.replace(queryParameters: redactedParameters).toString();
  }

  static String redactToken(String? token) {
    if (token == null || token.isEmpty) return redacted;
    return '$redacted length=${token.length}';
  }

  static String redactText(String message) {
    var result = message.replaceAllMapped(
      RegExp(
        r'\bBearer\s+[A-Za-z0-9._~+/=-]+',
        caseSensitive: false,
      ),
      (_) => 'Bearer $redacted',
    );
    result = result.replaceAllMapped(
      RegExp(
        r'\b(authorization(?:-refresh)?|access[_-]?token|refresh[_-]?token|firebase[_-]?token|fcm[_-]?token|id[_-]?token|oauth[_-]?token|token)\b\s*[:=]\s*([^,\s}\]]+)',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}=$redacted',
    );
    return result;
  }

  static bool _isSensitiveKey(String key) {
    final normalized = key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return normalized == 'authorization' ||
        normalized == 'authorizationrefresh' ||
        normalized == 'accessToken'.toLowerCase() ||
        normalized == 'refreshtoken' ||
        normalized == 'firebasetoken' ||
        normalized == 'fcmtoken' ||
        normalized == 'idtoken' ||
        normalized == 'oauthtoken' ||
        normalized.endsWith('secret') ||
        normalized.endsWith('token');
  }
}

void _discardDebugPrint(String? message, {int? wrapWidth}) {}
