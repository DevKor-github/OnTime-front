import 'package:equatable/equatable.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_with_time_entity.dart';

class PreparationWithTimeEntity extends PreparationEntity implements Equatable {
  const PreparationWithTimeEntity({
    required List<PreparationStepWithTimeEntity> preparationStepList,
  }) : super(preparationStepList: preparationStepList);

  factory PreparationWithTimeEntity.fromPreparation(
      PreparationEntity preparation) {
    return PreparationWithTimeEntity(
      preparationStepList: preparation.preparationStepList
          .map(
            (step) => PreparationStepWithTimeEntity(
              id: step.id,
              preparationName: step.preparationName,
              preparationTime: step.preparationTime,
              nextPreparationId: step.nextPreparationId,
            ),
          )
          .toList(),
    );
  }

  PreparationWithTimeEntity copyWith({
    List<PreparationStepWithTimeEntity>? preparationStepList,
  }) {
    return PreparationWithTimeEntity(
      preparationStepList: preparationStepList ?? this.preparationStepList,
    );
  }

  @override
  List<PreparationStepWithTimeEntity> get preparationStepList =>
      super.preparationStepList.cast<PreparationStepWithTimeEntity>();

  PreparationStepWithTimeEntity? get currentStep {
    for (final step in preparationStepList) {
      if (!step.isDone) {
        return step;
      }
    }
    return null; // All steps are done
  }

  Duration get elapsedTime => preparationStepList.fold<Duration>(
      Duration.zero, (sum, s) => sum + s.elapsedTime);

  PreparationWithTimeEntity timeElapsed(Duration elapsed) {
    final current = currentStep;
    if (current == null) {
      return this; // All steps are done, no changes needed
    }

    Duration remainingElapsed = elapsed;
    List<PreparationStepWithTimeEntity> updatedSteps =
        List.from(preparationStepList);

    // Find the current step index
    int currentIndex = updatedSteps.indexWhere((step) => step.id == current.id);

    // Apply elapsed time to current and subsequent steps if needed
    while (remainingElapsed > Duration.zero &&
        currentIndex < updatedSteps.length) {
      final step = updatedSteps[currentIndex];
      if (step.isDone) {
        currentIndex++;
        continue;
      }

      final stepRemainingTime = step.preparationTime - step.elapsedTime;

      if (remainingElapsed >= stepRemainingTime) {
        // Complete this step and move to next
        updatedSteps[currentIndex] = step.copyWith(
          elapsedTime: step.preparationTime,
          isDone: true,
        );
        remainingElapsed -= stepRemainingTime;
        currentIndex++;
      } else {
        // Partially complete this step
        updatedSteps[currentIndex] = step.copyWith(
          elapsedTime: step.elapsedTime + remainingElapsed,
          isDone: step.elapsedTime + remainingElapsed >= step.preparationTime,
        );
        remainingElapsed = Duration.zero;
      }
    }

    return copyWith(preparationStepList: updatedSteps);
  }

  PreparationWithTimeEntity skipCurrentStep() {
    final current = currentStep;
    if (current == null) {
      return this; // All steps are done, no changes needed
    }

    final updatedCurrentStep = current.copyWith(
      elapsedTime: current.preparationTime,
      isDone: true,
    );
    return copyWith(
      preparationStepList: preparationStepList
          .map((step) =>
              step.id == updatedCurrentStep.id ? updatedCurrentStep : step)
          .toList(),
    );
  }

  @override
  String toString() {
    return 'PreparationWithTimeEntity(preparationStepList: ${preparationStepList.toString()})';
  }

  @override
  List<Object?> get props => [preparationStepList];
}
