import 'package:equatable/equatable.dart';
import 'package:on_time_front/domain/entities/schedule_save.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';

final class ScheduleDeletionTarget extends Equatable {
  const ScheduleDeletionTarget({
    required this.id,
    required this.incarnation,
    required this.version,
  });
  final String id;
  final String incarnation;
  final int version;
  @override
  List<Object?> get props => [id, incarnation, version];
}

final class ScheduleDeletionIntent {
  ScheduleDeletionIntent({
    required this.intentId,
    required this.snapshot,
    required this.scope,
    required List<ScheduleDeletionTarget> targets,
  }) : targets = List.unmodifiable(targets);
  final String intentId;
  final ScheduleEditSnapshot snapshot;
  final RecurringEditScope scope;
  final List<ScheduleDeletionTarget> targets;
}

final class ScheduleDeletionCommit {
  ScheduleDeletionCommit({
    required this.scheduleId,
    required this.store,
    required this.generation,
    required Set<String> removedIds,
    required this.changed,
    required this.alreadyAbsent,
  }) : removedIds = Set.unmodifiable(removedIds);
  final String scheduleId;
  final String store;
  final int generation;
  final Set<String> removedIds;
  final bool changed;

  /// Current absence is not evidence that a historical request succeeded.
  final bool alreadyAbsent;
}

enum ScheduleDeletionFailure { conflict, protected, unavailable }

final class ScheduleDeletionRejected implements Exception {
  const ScheduleDeletionRejected(this.failure);
  final ScheduleDeletionFailure failure;
}

enum ScheduleDeletionCleanup { complete, pending, unconfirmed }

final class ScheduleDeletionResult {
  const ScheduleDeletionResult({required this.commit, required this.cleanup});
  final ScheduleDeletionCommit commit;
  final ScheduleDeletionCleanup cleanup;
}
