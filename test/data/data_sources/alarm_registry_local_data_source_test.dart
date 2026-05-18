import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/data/data_sources/alarm_registry_local_data_source.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AlarmRegistryLocalDataSourceImpl dataSource;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dataSource = AlarmRegistryLocalDataSourceImpl();
  });

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
}

ScheduledAlarmRecord _record(String scheduleId) {
  return ScheduledAlarmRecord(
    scheduleId: scheduleId,
    alarmTime: DateTime(2026, 5, 15, 8),
    preparationStartTime: DateTime(2026, 5, 15, 8, 5),
    scheduleFingerprint: 'fingerprint-$scheduleId',
    nativeAlarmId: 42,
    fallbackNotificationId: 43,
    provider: AlarmProvider.androidAlarmManager,
    scheduleTitle: 'Meeting',
    payload: {'type': 'schedule_alarm', 'scheduleId': scheduleId},
  );
}
