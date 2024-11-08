import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';

abstract interface class PreparationRemoteDataSource {
  Stream<PreparationEntity> getPreparationByScheduleId(String scheduleId);

  Stream<PreparationStepEntity> getPreparationStepById(
      String preparationStepId);

  Future<void> createDefaultPreparation(
      PreparationEntity preparationEntity, String userId);

  Future<void> createCustomPreparation(
      PreparationEntity preparationEntity, String scheduleId);

  Future<void> updatePreparation(PreparationStepEntity preparationEntity);

  Future<void> deletePreparation(PreparationEntity preparationEntity);
}
