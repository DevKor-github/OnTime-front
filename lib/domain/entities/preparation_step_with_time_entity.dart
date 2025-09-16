import 'package:on_time_front/domain/entities/preparation_step_entity.dart';

class PreparationStepWithTimeEntity extends PreparationStepEntity {
  final Duration elapsedTime;
  final bool isDone;

  const PreparationStepWithTimeEntity({
    required super.id,
    required super.preparationName,
    required super.preparationTime,
    required super.nextPreparationId,
    this.elapsedTime = Duration.zero,
    this.isDone = false,
  });

  @override
  PreparationStepWithTimeEntity copyWith({
    String? id,
    String? preparationName,
    Duration? preparationTime,
    String? nextPreparationId,
    Duration? elapsedTime,
    bool? isDone,
  }) {
    return PreparationStepWithTimeEntity(
      id: id ?? this.id,
      preparationName: preparationName ?? this.preparationName,
      preparationTime: preparationTime ?? this.preparationTime,
      nextPreparationId: nextPreparationId ?? this.nextPreparationId,
      elapsedTime: elapsedTime ?? this.elapsedTime,
      isDone: isDone ?? this.isDone,
    );
  }

  PreparationStepWithTimeEntity timeElapsed(Duration elapsed) {
    final updatedElapsed = elapsedTime + elapsed;
    final updatedIsDone = updatedElapsed >= preparationTime;
    return copyWith(
      elapsedTime: updatedElapsed,
      isDone: updatedIsDone,
    );
  }

  @override
  List<Object?> get props => [
        id,
        preparationName,
        preparationTime,
        nextPreparationId,
        elapsedTime,
        isDone
      ];
}
