import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/data/data_sources/alarm_registry_local_data_source.dart';
import 'package:on_time_front/data/repositories/alarm_registry_repository_impl.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';

void main() {
  late _FakeAlarmRegistryLocalDataSource localDataSource;
  late AlarmRegistryRepositoryImpl repository;

  setUp(() {
    localDataSource = _FakeAlarmRegistryLocalDataSource();
    repository = AlarmRegistryRepositoryImpl(localDataSource: localDataSource);
  });

  test('loadAll returns the current local registry', () async {
    localDataSource.records = [_record('schedule-1')];

    expect(await repository.loadAll(), [_record('schedule-1')]);
  });

  test(
    'upsert replaces an existing schedule record and keeps others',
    () async {
      localDataSource.records = [
        _record('schedule-1', title: 'Old'),
        _record('schedule-2'),
      ];

      await repository.upsert(_record('schedule-1', title: 'New'));

      expect(localDataSource.records, [
        _record('schedule-2'),
        _record('schedule-1', title: 'New'),
      ]);
    },
  );

  test('deleteByScheduleId removes only the requested schedule', () async {
    localDataSource.records = [_record('schedule-1'), _record('schedule-2')];

    await repository.deleteByScheduleId('schedule-1');

    expect(localDataSource.records, [_record('schedule-2')]);
  });

  test(
    'replaceAll deduplicates by schedule id and deleteAll clears storage',
    () async {
      await repository.replaceAll([
        _record('schedule-1', title: 'Old'),
        _record('schedule-1', title: 'New'),
        _record('schedule-2'),
      ]);

      expect(localDataSource.records, [
        _record('schedule-1', title: 'New'),
        _record('schedule-2'),
      ]);

      await repository.deleteAll();

      expect(localDataSource.records, isEmpty);
    },
  );
}

ScheduledAlarmRecord _record(String scheduleId, {String title = 'Meeting'}) {
  return ScheduledAlarmRecord(
    scheduleId: scheduleId,
    alarmTime: DateTime(2026, 5, 15, 8),
    preparationStartTime: DateTime(2026, 5, 15, 8, 5),
    scheduleFingerprint: 'fingerprint-$scheduleId',
    provider: AlarmProvider.androidAlarmManager,
    scheduleTitle: title,
    payload: {'type': 'schedule_alarm', 'scheduleId': scheduleId},
  );
}

class _FakeAlarmRegistryLocalDataSource
    implements AlarmRegistryLocalDataSource {
  List<ScheduledAlarmRecord> records = const [];

  @override
  Future<List<ScheduledAlarmRecord>> loadAll() async => records;

  @override
  Future<void> replaceAll(List<ScheduledAlarmRecord> records) async {
    this.records = List.of(records);
  }
}
