import 'package:on_time_front/domain/entities/alarm_entities.dart';

abstract interface class AlarmRegistryRepository {
  Future<List<ScheduledAlarmRecord>> loadAll();

  Future<void> upsert(ScheduledAlarmRecord record);

  Future<void> deleteByScheduleId(String scheduleId);

  Future<void> deleteAll();

  Future<void> replaceAll(List<ScheduledAlarmRecord> records);
}

/// Optional integrity evidence from stores that can detect lost identities.
/// An empty list alone cannot prove that unknown platform registrations ended.
abstract interface class AlarmOwnershipIntegrity {
  Future<bool> hasUnresolvedOwnership();
}

/// Cleared only after complete platform evidence and durable journal read-back.
abstract interface class RecoverableAlarmOwnershipIntegrity
    implements AlarmOwnershipIntegrity {
  Future<void> clearResolvedOwnership();
}
