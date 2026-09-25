import 'package:injectable/injectable.dart';
import 'package:on_time_front/data/data_sources/alarm_registry_local_data_source.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/repositories/alarm_registry_repository.dart';

@Singleton(as: AlarmRegistryRepository)
class AlarmRegistryRepositoryImpl
    implements AlarmRegistryRepository, RecoverableAlarmOwnershipIntegrity {
  final AlarmRegistryLocalDataSource localDataSource;

  AlarmRegistryRepositoryImpl({required this.localDataSource});

  @override
  Future<bool> hasUnresolvedOwnership() async {
    final source = localDataSource;
    return source is AlarmOwnershipIntegrity
        ? await (source as AlarmOwnershipIntegrity).hasUnresolvedOwnership()
        : false;
  }

  @override
  Future<void> clearResolvedOwnership() async {
    final source = localDataSource;
    if (source is RecoverableAlarmOwnershipIntegrity) {
      await (source as RecoverableAlarmOwnershipIntegrity)
          .clearResolvedOwnership();
    } else if (await hasUnresolvedOwnership()) {
      throw StateError('Registry cannot resolve ownership uncertainty');
    }
  }

  @override
  Future<List<ScheduledAlarmRecord>> loadAll() {
    return localDataSource.loadAll();
  }

  @override
  Future<void> upsert(ScheduledAlarmRecord record) async {
    final records = await loadAll();
    final nextRecords =
        records
            .where(
              (existing) =>
                  alarmOwnershipKey(existing) != alarmOwnershipKey(record),
            )
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
    final byOwnership = <String, ScheduledAlarmRecord>{};
    for (final record in records) {
      byOwnership[alarmOwnershipKey(record)] = record;
    }
    return localDataSource.replaceAll(byOwnership.values.toList());
  }
}
