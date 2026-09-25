import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_content.dart';

Map<String, dynamic> validBackup() => {
  'formatVersion': 1,
  'cutoff': '2026-09-24T00:00:00.000Z',
  'sourceAppVersion': '1.1.0+56',
  'sourcePlatform': 'android',
  'dataRevision': 1,
  'profile': {
    'spareTimeMinutes': 0,
    'note': '',
    'isOnboardingCompleted': true,
    'eligibleOutcomeCount': 0,
    'onTimeOutcomeCount': 0,
  },
  'preferences': {
    'alarmsEnabled': true,
    'alarmOffsetMinutes': 0,
    'detailedNotificationContent': false,
  },
  'schedules': [
    {
      'id': 's1',
      'place': {'id': 'p1', 'name': 'Office'},
      'name': 'Meeting',
      'civilTime': '2026-09-01T09:00:00.000Z',
      'timeZoneId': 'Asia/Seoul',
      'occurrenceOffsetSeconds': 32400,
      'moveTimeMinutes': 0,
      'spareTimeMinutes': 0,
      'isChanged': false,
      'note': '',
      'latenessTime': -1,
      'doneStatus': 'notEnded',
      'preparationTemplateDeleted': false,
      'scoreContributionRecorded': false,
    },
  ],
  'defaultPreparation': [
    {'id': 'a', 'name': 'Prepare', 'minutes': 0, 'nextId': null},
  ],
  'schedulePreparations': <String, dynamic>{},
  'templates': <dynamic>[],
};

void main() {
  test(
    'valid legacy zero duration and null optional fields remain readable',
    () {
      expect(BackupContent.fromJson(validBackup()).schedules, hasLength(1));
    },
  );
  test('cyclic source preparation is rejected before ordering can mask it', () {
    final input = validBackup();
    input['defaultPreparation'] = [
      {'id': 'a', 'name': 'A', 'minutes': 1, 'nextId': 'b'},
      {'id': 'b', 'name': 'B', 'minutes': 1, 'nextId': 'a'},
    ];
    expect(() => BackupContent.fromJson(input), throwsFormatException);
  });
  test('unknown named zone cannot silently become UTC', () {
    final input = validBackup();
    input['schedules'][0]['timeZoneId'] = 'Not/AZone';
    expect(() => BackupContent.fromJson(input), throwsFormatException);
  });
  test(
    'civil date overflow is rejected instead of changing the appointment',
    () {
      final input = validBackup();
      input['schedules'][0]['civilTime'] = '2026-02-30T09:00:00.000Z';
      expect(() => BackupContent.fromJson(input), throwsFormatException);
    },
  );
  test('negative optional spare time is rejected before date arithmetic', () {
    final input = validBackup();
    input['schedules'][0]['spareTimeMinutes'] = -1;
    expect(() => BackupContent.fromJson(input), throwsFormatException);
  });
  test('overlong identifier is rejected before admission', () {
    final input = validBackup();
    input['schedules'][0]['id'] = 'x' * 513;
    expect(() => BackupContent.fromJson(input), throwsFormatException);
  });
  test(
    'revision must leave exact representation space for restore increment',
    () {
      final input = validBackup();
      input['dataRevision'] = 9007199254740991;
      expect(() => BackupContent.fromJson(input), throwsFormatException);
    },
  );
}
