import 'package:equatable/equatable.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';

class PreparationEntity extends Equatable {
  final List<PreparationStepEntity> preparationStepList;

  const PreparationEntity({
    required this.preparationStepList,
  });

  Duration get totalDuration {
    return preparationStepList.fold(
      Duration.zero,
      (previousValue, element) => previousValue + element.preparationTime,
    );
  }

  PreparationEntity get ordered {
    if (preparationStepList.length <= 1) {
      return this;
    }

    final stepById = {
      for (final step in preparationStepList) step.id: step,
    };
    final referencedIds = preparationStepList
        .map((step) => step.nextPreparationId)
        .whereType<String>()
        .toSet();

    final firstStep = preparationStepList.firstWhere(
      (step) => !referencedIds.contains(step.id),
      orElse: () => preparationStepList.first,
    );

    final orderedSteps = <PreparationStepEntity>[];
    final visitedIds = <String>{};
    PreparationStepEntity? currentStep = firstStep;

    while (currentStep != null && visitedIds.add(currentStep.id)) {
      orderedSteps.add(currentStep);
      currentStep = stepById[currentStep.nextPreparationId];
    }

    if (orderedSteps.length == preparationStepList.length) {
      return PreparationEntity(preparationStepList: orderedSteps);
    }

    for (final step in preparationStepList) {
      if (visitedIds.add(step.id)) {
        orderedSteps.add(step);
      }
    }

    return PreparationEntity(preparationStepList: orderedSteps);
  }

  @override
  String toString() {
    return 'PreparationEntity(preparationStepList: ${preparationStepList.toString()})';
  }

  @override
  List<Object?> get props => [preparationStepList];
}
