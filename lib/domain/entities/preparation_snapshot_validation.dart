import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/entities/timed_preparation_snapshot_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';

/// Binds reconstructible progress to the current encrypted source of truth.
/// Legacy text is compared only in memory, never parsed, persisted or logged.
TimedPreparationSnapshotEntity? validatePreparationSnapshot(
  TimedPreparationSnapshotEntity snapshot,
  ScheduleWithPreparationEntity schedule,
) {
  final current = schedule.preparation.preparationStepList;
  final stored = snapshot.preparation.preparationStepList;
  final isCurrent = ScheduleWithPreparationEntity.isCurrentIdentity(
    snapshot.scheduleFingerprint,
  );
  if (snapshot.scheduleFingerprint !=
      (isCurrent
          ? schedule.cacheFingerprint
          : schedule.legacyCacheFingerprint)) {
    return null;
  }
  if (stored.length != current.length) return null;
  for (var i = 0; i < current.length; i++) {
    final left = stored[i];
    final right = current[i];
    if (left.id != right.id || left.elapsedTime.isNegative) return null;
    if (!snapshot.contentOmitted &&
        (left.preparationName != right.preparationName ||
            left.preparationTime != right.preparationTime ||
            left.nextPreparationId != right.nextPreparationId)) {
      return null;
    }
  }
  final ids = current.map((step) => step.id).toSet();
  if (ids.length != current.length ||
      snapshot.actionEvents.any(
        (event) => event.stepId != null && !ids.contains(event.stepId),
      )) {
    return null;
  }
  return TimedPreparationSnapshotEntity(
    preparation: PreparationWithTimeEntity(
      preparationStepList: [
        for (var i = 0; i < current.length; i++)
          current[i].copyWith(
            elapsedTime: stored[i].elapsedTime,
            isDone: stored[i].isDone,
          ),
      ],
    ),
    savedAt: snapshot.savedAt,
    startedAt: snapshot.startedAt,
    scheduleFingerprint: schedule.cacheFingerprint,
    actionEvents: snapshot.actionEvents,
    requiresConfirmation: snapshot.requiresConfirmation,
  );
}
