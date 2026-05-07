import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/logging/app_logger.dart';

void main() {
  group('AppLogger redaction', () {
    test('redacts sensitive map values recursively', () {
      final value = AppLogger.redactValue({
        'Authorization': 'Bearer access-token',
        'nested': {
          'refreshToken': 'refresh-token',
          'safe': 'visible',
        },
        'items': [
          {'firebaseToken': 'fcm-token'},
        ],
      });

      expect(value, {
        'Authorization': AppLogger.redacted,
        'nested': {
          'refreshToken': AppLogger.redacted,
          'safe': 'visible',
        },
        'items': [
          {'firebaseToken': AppLogger.redacted},
        ],
      });
    });

    test('redacts bearer tokens and token assignments in text', () {
      final redacted = AppLogger.redactText(
        'Authorization: Bearer abc.def token=secret refresh_token=rotate-value',
      );

      expect(redacted, isNot(contains('abc.def')));
      expect(redacted, isNot(contains('secret')));
      expect(redacted, isNot(contains('rotate-value')));
      expect(redacted, contains('Authorization=${AppLogger.redacted}'));
      expect(redacted, contains('token=${AppLogger.redacted}'));
      expect(redacted, contains('refresh_token=${AppLogger.redacted}'));
    });

    test('redacts sensitive query parameters in urls', () {
      final redacted = AppLogger.redactUri(
        Uri.parse(
          'https://api.example.test/path?access_token=secret&page=1',
        ),
      );

      expect(redacted, isNot(contains('secret')));
      final query = Uri.parse(redacted).queryParameters;
      expect(query['access_token'], AppLogger.redacted);
      expect(query['page'], '1');
    });
  });
}
