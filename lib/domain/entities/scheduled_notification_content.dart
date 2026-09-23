import 'dart:convert';

import 'package:crypto/crypto.dart';

/// The exact content snapshot handed to either scheduled delivery provider.
/// Only its digest/version need to be persisted for reconciliation. A digest
/// detects changes; it is not encryption or an anonymity guarantee.
class ScheduledNotificationContent {
  static const schemaVersion = 1;

  final String title;
  final String body;
  final bool detailed;
  final String languageCode;
  final String? displayTimeZone;

  const ScheduledNotificationContent._({
    required this.title,
    required this.body,
    required this.detailed,
    required this.languageCode,
    required this.displayTimeZone,
  });

  factory ScheduledNotificationContent({
    required String scheduleTitle,
    required bool detailed,
    String languageCode = 'en',
    String? displayTimeZone,
  }) {
    final language = languageCode == 'ko' ? 'ko' : 'en';
    final zone = detailed ? displayTimeZone : null;
    return ScheduledNotificationContent._(
      title: detailed
          ? scheduleTitle
          : (language == 'ko' ? '일정 준비 시간이에요' : 'Time to prepare'),
      body: zone != null
          ? (language == 'ko' ? '일정 시간대: $zone' : 'Schedule time zone: $zone')
          : (language == 'ko'
                ? 'OnTime을 열어 일정을 확인하세요.'
                : 'Open OnTime to review your schedule.'),
      detailed: detailed,
      languageCode: language,
      displayTimeZone: zone,
    );
  }

  String get digest => sha256
      .convert(
        utf8.encode(
          jsonEncode([
            schemaVersion,
            title,
            body,
            detailed,
            languageCode,
            displayTimeZone,
          ]),
        ),
      )
      .toString();
}
