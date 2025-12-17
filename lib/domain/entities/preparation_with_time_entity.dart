import 'package:equatable/equatable.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_with_time_entity.dart';
import 'package:on_time_front/presentation/shared/constants/constants.dart';

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

  /// Returns true if all preparation steps are completed
  bool get isAllStepsDone {
    return currentStep == null;
  }

  Duration get elapsedTime => preparationStepList.fold<Duration>(
      Duration.zero, (sum, s) => sum + s.elapsedTime);

  /// Returns the progress as a value between 0.0 and 1.0
  double get progress {
    final totalSeconds = totalDuration.inSeconds;
    final elapsed = elapsedTime.inSeconds;
    return totalSeconds == 0 ? 0.0 : (elapsed / totalSeconds).clamp(0.0, 1.0);
  }

  /// Returns the current step index, or -1 if all steps are done
  int get currentStepIndex {
    final current = currentStep;
    if (current == null) return -1;
    return preparationStepList.indexWhere((step) => step.id == current.id);
  }

  /// Returns the resolved current step index for display purposes
  int get resolvedCurrentStepIndex {
    final index = currentStepIndex;
    return index == -1 ? preparationStepList.length - 1 : index;
  }

  /// Returns the current step's remaining time
  Duration get currentStepRemainingTime {
    final current = currentStep;
    if (current == null) return Duration.zero;
    final remaining = current.preparationTime - current.elapsedTime;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Returns the current step's name for display
  String get currentStepName {
    final current = currentStep;
    if (current != null) return current.preparationName;
    return preparationStepList.isNotEmpty
        ? preparationStepList.last.preparationName
        : '';
  }

  /// Returns elapsed times for each step in seconds
  List<int> get stepElapsedTimesInSeconds {
    return preparationStepList
        .map<int>((step) => step.elapsedTime.inSeconds)
        .toList();
  }

  /// Returns the preparation state for each step
  List<PreparationStateEnum> get preparationStepStates {
    final resolvedIndex = resolvedCurrentStepIndex;

    return List<PreparationStateEnum>.generate(
      preparationStepList.length,
      (index) {
        if (isAllStepsDone) {
          // All steps are done
          return PreparationStateEnum.done;
        }
        if (index < resolvedIndex) {
          return PreparationStateEnum.done;
        }
        if (index == resolvedIndex && !isAllStepsDone) {
          return PreparationStateEnum.now;
        }
        return PreparationStateEnum.yet;
      },
    );
  }

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
