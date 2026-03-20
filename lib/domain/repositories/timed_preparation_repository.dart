import 'package:on_time_front/domain/entities/timed_preparation_snapshot_entity.dart';

abstract interface class TimedPreparationRepository {
  Future<void> saveTimedPreparationSnapshot(
    String scheduleId,
    TimedPreparationSnapshotEntity snapshot,
  );

  Future<TimedPreparationSnapshotEntity?> getTimedPreparationSnapshot(
    String scheduleId,
  );

  Future<void> clearTimedPreparation(String scheduleId);
}
