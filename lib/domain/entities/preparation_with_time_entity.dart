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

  PreparationStepWithTimeEntity get currentStep =>
      preparationStepList.firstWhere(
        (step) => !step.isDone,
      );

  PreparationWithTimeEntity timeElapsed(Duration elapsed) {
    final updatedCurrentStep = currentStep.timeElapsed(elapsed);
    return copyWith(
      preparationStepList: preparationStepList
          .map((step) =>
              step.id == updatedCurrentStep.id ? updatedCurrentStep : step)
          .toList(),
    );
  }

  @override
  List<Object?> get props => [preparationStepList];
}
