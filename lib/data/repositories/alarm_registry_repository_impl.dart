import 'package:injectable/injectable.dart';
import 'package:on_time_front/data/data_sources/alarm_registry_local_data_source.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/repositories/alarm_registry_repository.dart';

@Singleton(as: AlarmRegistryRepository)
class AlarmRegistryRepositoryImpl implements AlarmRegistryRepository {
  final AlarmRegistryLocalDataSource localDataSource;

  AlarmRegistryRepositoryImpl({required this.localDataSource});

  @override
  Future<List<ScheduledAlarmRecord>> loadAll() {
    return localDataSource.loadAll();
  }

  @override
  Future<void> upsert(ScheduledAlarmRecord record) async {
    final records = await loadAll();
    final nextRecords = records
        .where((existing) => existing.scheduleId != record.scheduleId)
        .toList()
      ..add(record);
    await replaceAll(nextRecords);
  }

  @override
  Future<void> deleteByScheduleId(String scheduleId) async {
    final records = await loadAll();
    await replaceAll(
      records.where((record) => record.scheduleId != scheduleId).toList(),
    );
  }

  @override
  Future<void> deleteAll() {
    return replaceAll(const []);
  }

  @override
  Future<void> replaceAll(List<ScheduledAlarmRecord> records) {
    final byScheduleId = <String, ScheduledAlarmRecord>{};
    for (final record in records) {
      byScheduleId[record.scheduleId] = record;
    }
    return localDataSource.replaceAll(byScheduleId.values.toList());
  }
}
