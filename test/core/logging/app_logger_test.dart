import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/logging/app_logger.dart';

void main() {
  group('AppLogger redaction', () {
    test('redacts sensitive map values recursively', () {
      final value = AppLogger.redactValue({
        'Authorization': 'Bearer access-token',
        'Authorization-refresh': 'Bearer refresh-header',
        'nested': {
          'refreshToken': 'refresh-token',
          'oauth_token': 'oauth-token',
          'safe': 'visible',
        },
        'items': [
          {
            'firebaseToken': 'fcm-token',
            'fcm_token': 'fcm-token-2',
            'clientSecret': 'secret-value',
          },
        ],
      });

      expect(value, {
        'Authorization': AppLogger.redacted,
        'Authorization-refresh': AppLogger.redacted,
        'nested': {
          'refreshToken': AppLogger.redacted,
          'oauth_token': AppLogger.redacted,
          'safe': 'visible',
        },
        'items': [
          {
            'firebaseToken': AppLogger.redacted,
            'fcm_token': AppLogger.redacted,
            'clientSecret': AppLogger.redacted,
          },
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
          'https://api.example.test/path?access_token=secret'
          '&refresh_token=rotate-secret&firebaseToken=fcm-secret&page=1',
        ),
      );

      expect(redacted, isNot(contains('secret')));
      expect(redacted, isNot(contains('rotate-secret')));
      expect(redacted, isNot(contains('fcm-secret')));
      final query = Uri.parse(redacted).queryParameters;
      expect(query['access_token'], AppLogger.redacted);
      expect(query['refresh_token'], AppLogger.redacted);
      expect(query['firebaseToken'], AppLogger.redacted);
      expect(query['page'], '1');
    });

    test('summarizes maps without exposing non-allowed payload fields', () {
      final summary = AppLogger.summarizeMap({
        'scheduleId': 'schedule-1',
        'title': 'Private appointment',
        'body': 'Leave home',
        'firebaseToken': 'fcm-token',
      });

      expect(summary, contains('keys=4'));
      expect(summary, contains('scheduleId=schedule-1'));
      expect(summary, isNot(contains('Private appointment')));
      expect(summary, isNot(contains('Leave home')));
      expect(summary, isNot(contains('fcm-token')));
    });
  });

  group('logging source scan', () {
    test('Dart app code uses AppLogger instead of raw debugPrint', () {
      final offenders = _sourceFiles(
        roots: ['lib'],
        extensions: ['.dart'],
        excludedPathFragments: [
          '/core/logging/app_logger.dart',
          '/l10n/app_localizations',
          '.g.dart',
          '.freezed.dart',
        ],
      )
          .where((file) {
            final source = file.readAsStringSync();
            return RegExp(r'(?<![A-Za-z0-9_])debugPrint(?:Stack)?\s*\(')
                .hasMatch(source);
          })
          .map((file) => file.path)
          .toList();

      expect(offenders, isEmpty);
    });

    test('native logs do not dump full extras, args, or payload maps', () {
      final offenders = _sourceFiles(
        roots: ['android/app/src/main/kotlin', 'ios/Runner'],
        extensions: ['.kt', '.swift'],
      )
          .where((file) {
            final source = file.readAsStringSync();
            final isNativeLog = file.path.endsWith('/NativeLog.kt');
            return source.contains('extras=\${intent') ||
                source.contains('extras=\${intent?') ||
                source.contains('args=\$args') ||
                source.contains('payload=\$payload') ||
                source.contains('-> \$payload') ||
                source.contains('-> \$launchPayload') ||
                source.contains('encodedPayload=%@') ||
                (!isNativeLog && RegExp(r'\bLog\.[diew]\(').hasMatch(source));
          })
          .map((file) => file.path)
          .toList();

      expect(offenders, isEmpty);
    });
  });
}

Iterable<File> _sourceFiles({
  required List<String> roots,
  required List<String> extensions,
  List<String> excludedPathFragments = const [],
}) sync* {
  final rootDirectory = Directory.current;
  for (final root in roots) {
    final directory = Directory('${rootDirectory.path}/$root');
    if (!directory.existsSync()) continue;
    for (final entity in directory.listSync(recursive: true)) {
      if (entity is! File) continue;
      final path = entity.path;
      if (!extensions.any(path.endsWith)) continue;
      if (excludedPathFragments.any(path.contains)) continue;
      yield entity;
    }
  }
}
