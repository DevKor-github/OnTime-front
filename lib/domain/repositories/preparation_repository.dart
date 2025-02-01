import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';

abstract interface class PreparationRepository {
  Future<PreparationEntity> getPreparationByScheduleId(String scheduleId);

  Future<PreparationEntity> getDefualtPreparation();

  Future<PreparationStepEntity> getPreparationStepById(
      String preparationStepId);

  Future<void> createDefaultPreparation(PreparationEntity preparationEntity);

  Future<void> createCustomPreparation(
      PreparationEntity preparationEntity, String scheduleId);

  Future<void> updatePreparation(PreparationStepEntity preparationStepEntity);
}
