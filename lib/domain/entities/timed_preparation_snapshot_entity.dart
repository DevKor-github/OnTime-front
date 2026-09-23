import 'package:equatable/equatable.dart';
import 'package:on_time_front/domain/entities/preparation_action_event_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';

class TimedPreparationSnapshotEntity extends Equatable {
  const TimedPreparationSnapshotEntity({
    required this.preparation,
    required this.savedAt,
    required this.scheduleFingerprint,
    this.startedAt,
    this.contentOmitted = false,
    this.requiresConfirmation = false,
    this.actionEvents = const [],
  });

  final PreparationWithTimeEntity preparation;
  final DateTime savedAt;
  final String scheduleFingerprint;
  final DateTime? startedAt;
  final bool contentOmitted;
  final bool requiresConfirmation;
  final List<PreparationActionEventEntity> actionEvents;

  TimedPreparationSnapshotEntity copyWith({
    PreparationWithTimeEntity? preparation,
    DateTime? savedAt,
    String? scheduleFingerprint,
    DateTime? startedAt,
    List<PreparationActionEventEntity>? actionEvents,
    bool? requiresConfirmation,
  }) {
    return TimedPreparationSnapshotEntity(
      preparation: preparation ?? this.preparation,
      savedAt: savedAt ?? this.savedAt,
      scheduleFingerprint: scheduleFingerprint ?? this.scheduleFingerprint,
      startedAt: startedAt ?? this.startedAt,
      contentOmitted: contentOmitted,
      requiresConfirmation: requiresConfirmation ?? this.requiresConfirmation,
      actionEvents: actionEvents ?? this.actionEvents,
    );
  }

  @override
  List<Object?> get props => [
    preparation,
    savedAt,
    scheduleFingerprint,
    startedAt,
    actionEvents,
    contentOmitted,
    requiresConfirmation,
  ];
}
