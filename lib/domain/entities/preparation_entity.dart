import 'package:on_time_front/domain/entities/preparation_step_entity.dart';

class PreparationEntity {
  List<PreparationStepEntity> preparationStepList;

  PreparationEntity({
    required this.preparationStepList,
  });

  /// Remove a step by ID and re-link the list
  void removeStepById(String stepId) {
    // Find the index of the step to delete
    final stepIndex =
        preparationStepList.indexWhere((step) => step.id == stepId);

    if (stepIndex == -1) {
      throw Exception("Step with ID $stepId not found");
    }

    // Get the previous and next steps
    final previousStep =
        stepIndex > 0 ? preparationStepList[stepIndex - 1] : null;
    final nextStep = stepIndex < preparationStepList.length - 1
        ? preparationStepList[stepIndex + 1]
        : null;

    // Update the previous step to point to the next step
    if (previousStep != null) {
      previousStep.nextPreparationId = nextStep?.id;
    }

    // Remove the current step
    preparationStepList.removeAt(stepIndex);
  }

  /// Re-link the entire list based on the current order
  void relinkList() {
    for (int i = 0; i < preparationStepList.length; i++) {
      if (i < preparationStepList.length - 1) {
        preparationStepList[i].nextPreparationId =
            preparationStepList[i + 1].id;
      } else {
        preparationStepList[i].nextPreparationId = null;
      }
    }
  }

  /// Add a step at a specific position
  void addStep(PreparationStepEntity newStep, {int? index}) {
    if (index == null || index >= preparationStepList.length) {
      preparationStepList.add(newStep);
    } else {
      preparationStepList.insert(index, newStep);
    }
    relinkList();
  }

  @override
  String toString() {
    return 'PreparationEntity(preparationStepList: ${preparationStepList.toString()})';
  }
}
