import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/preparation_action_event_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/entities/timed_preparation_snapshot_entity.dart';
import 'package:on_time_front/domain/repositories/timed_preparation_repository.dart';

@Injectable()
class SaveTimedPreparationUseCase {
  final TimedPreparationRepository _timedPreparationRepository;

  SaveTimedPreparationUseCase(this._timedPreparationRepository);

  Future<void> call(
    ScheduleWithPreparationEntity schedule,
    PreparationWithTimeEntity preparation, {
    DateTime? savedAt,
    DateTime? startedAt,
    List<PreparationActionEventEntity> actionEvents = const [],
  }) {
    final snapshot = TimedPreparationSnapshotEntity(
      preparation: preparation,
      savedAt: savedAt ?? DateTime.now(),
      scheduleFingerprint: schedule.cacheFingerprint,
      startedAt: startedAt,
      actionEvents: actionEvents,
    );
    return _timedPreparationRepository.saveTimedPreparationSnapshot(
      schedule.id,
      snapshot,
    );
  }
}
