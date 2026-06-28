import 'package:equatable/equatable.dart';

enum PreparationActionEventType { start, skipStep, finish }

class PreparationActionEventEntity extends Equatable {
  const PreparationActionEventEntity({
    required this.type,
    required this.occurredAt,
    this.stepId,
  });

  factory PreparationActionEventEntity.start({required DateTime occurredAt}) {
    return PreparationActionEventEntity(
      type: PreparationActionEventType.start,
      occurredAt: occurredAt,
    );
  }

  factory PreparationActionEventEntity.skipStep({
    required String stepId,
    required DateTime occurredAt,
  }) {
    return PreparationActionEventEntity(
      type: PreparationActionEventType.skipStep,
      occurredAt: occurredAt,
      stepId: stepId,
    );
  }

  factory PreparationActionEventEntity.finish({required DateTime occurredAt}) {
    return PreparationActionEventEntity(
      type: PreparationActionEventType.finish,
      occurredAt: occurredAt,
    );
  }

  final PreparationActionEventType type;
  final DateTime occurredAt;
  final String? stepId;

  @override
  List<Object?> get props => [type, occurredAt, stepId];
}
