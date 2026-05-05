import 'package:on_time_front/domain/entities/alarm_entities.dart';

abstract interface class AlarmRegistryRepository {
  Future<List<ScheduledAlarmRecord>> loadAll();

  Future<void> upsert(ScheduledAlarmRecord record);

  Future<void> deleteByScheduleId(String scheduleId);

  Future<void> deleteAll();

  Future<void> replaceAll(List<ScheduledAlarmRecord> records);
}
