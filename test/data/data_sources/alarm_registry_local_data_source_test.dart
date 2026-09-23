import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/data/data_sources/alarm_registry_local_data_source.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/data/models/scheduled_alarm_record_model.dart';
import 'package:on_time_front/domain/entities/scheduled_notification_content.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AlarmRegistryLocalDataSourceImpl dataSource;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dataSource = AlarmRegistryLocalDataSourceImpl();
  });

  test(
    'wrong-typed known registry is removed instead of retaining raw text',
    () async {
      SharedPreferences.setMockInitialValues({
        'scheduled_alarm_registry': ['SECRET'],
      });
      expect(await dataSource.loadAll(), isEmpty);
      expect(
        (await SharedPreferences.getInstance()).containsKey(
          'scheduled_alarm_registry',
        ),
        isFalse,
      );
    },
  );

  test(
    'loadAll returns empty for missing, empty, and corrupt storage',
    () async {
      expect(await dataSource.loadAll(), isEmpty);

      SharedPreferences.setMockInitialValues({'scheduled_alarm_registry': ''});
      expect(await AlarmRegistryLocalDataSourceImpl().loadAll(), isEmpty);

      SharedPreferences.setMockInitialValues({
        'scheduled_alarm_registry': 'not json',
      });
      expect(await AlarmRegistryLocalDataSourceImpl().loadAll(), isEmpty);
    },
  );

  test(
    'malformed new content metadata never drops registry ownership records',
    () async {
      final content = ScheduledNotificationContent(
        scheduleTitle: 'Meeting',
        detailed: false,
        languageCode: 'ko',
      );
      final valid = _record('affected').copyWith(
        scheduleTitle: content.title,
        contentDigest: content.digest,
        contentVersion: ScheduledNotificationContent.schemaVersion,
        contentLanguageCode: content.languageCode,
      );
      final other = _record('unrelated');
      for (final change in <String, List<Object>>{
        'contentDigest': [42, [], 'short', 'g' * 64],
        'contentVersion': ['1', 1.5, [], -1],
        'contentLanguageCode': [42, [], 'fr'],
        'cancellationPending': ['false', 1, []],
      }.entries) {
        for (final value in change.value) {
          final json = ScheduledAlarmRecordModel(valid).toJson()
            ..[change.key] = value;
          SharedPreferences.setMockInitialValues({
            'scheduled_alarm_registry': jsonEncode([
              json,
              ScheduledAlarmRecordModel(other).toJson(),
            ]),
          });
          final records = await AlarmRegistryLocalDataSourceImpl().loadAll();
          expect(records.map((r) => r.scheduleId), [
            'affected',
            'unrelated',
          ], reason: '${change.key}: $value');
          expect(records.first.hasCurrentContent, isFalse);
          expect(records.first.provider, valid.provider);
          expect(records.first.nativeAlarmId, valid.nativeAlarmId);
          expect(
            records.first.fallbackNotificationId,
            valid.fallbackNotificationId,
          );
          expect(records.last, other);
        }
      }
    },
  );

  test(
    'replaceAll persists records and removes the key when cleared',
    () async {
      final record = _record('schedule-1');

      await dataSource.replaceAll([record]);

      expect(await dataSource.loadAll(), [record]);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('scheduled_alarm_registry'), isNotNull);

      await dataSource.replaceAll(const []);

      expect(await dataSource.loadAll(), isEmpty);
      expect(prefs.getString('scheduled_alarm_registry'), isNull);
    },
  );

  for (final timing in NotificationTiming.values) {
    for (final pending in [false, true]) {
      test(
        'preferences round trip preserves $timing and ownership pending=$pending',
        () async {
          final content = ScheduledNotificationContent(
            scheduleTitle: 'Private meeting',
            detailed: false,
            languageCode: 'ko',
          );
          final original = _record('persisted').copyWith(
            provider: AlarmProvider.localNotification,
            scheduleTitle: content.title,
            contentDigest: content.digest,
            contentVersion: ScheduledNotificationContent.schemaVersion,
            contentLanguageCode: content.languageCode,
            notificationTiming: timing,
            cancellationPending: pending,
          );

          await dataSource.replaceAll([original]);
          final prefs = await SharedPreferences.getInstance();
          final stored =
              jsonDecode(prefs.getString('scheduled_alarm_registry')!) as List;
          expect(stored.single['notificationTiming'], timing.name);
          final loaded =
              (await AlarmRegistryLocalDataSourceImpl().loadAll()).single;
          expect(loaded, original);
          expect(loaded.hasCurrentContent, !pending);
          // The read path sanitizes and can rewrite storage; a second read must
          // retain the actual scheduling mode and the cancellation identity too.
          expect(
            (await AlarmRegistryLocalDataSourceImpl().loadAll()).single,
            original,
          );
        },
      );
    }
  }
}

ScheduledAlarmRecord _record(String scheduleId) {
  return ScheduledAlarmRecord(
    scheduleId: scheduleId,
    alarmTime: DateTime(2026, 5, 15, 8),
    preparationStartTime: DateTime(2026, 5, 15, 8, 5),
    scheduleFingerprint: 'v2:${'a' * 64}',
    nativeAlarmId: 42,
    fallbackNotificationId: 43,
    provider: AlarmProvider.androidAlarmManager,
    scheduleTitle: 'Meeting',
    payload: {
      'type': 'schedule_alarm',
      'scheduleId': scheduleId,
      'alarmLaunchPayloadVersion': '9',
      'promptVariant': 'alarm',
      'detailedNotificationContent': 'false',
    },
  );
}
