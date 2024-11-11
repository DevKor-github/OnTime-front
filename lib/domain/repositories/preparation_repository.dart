import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';

abstract interface class PreparationRepository {
  /// Get preparation by [scheduleId]
  /// This is for getting preparation by scheduleId
  Stream<PreparationEntity> getPreparationByScheduleId(String scheduleId);

  /// Get preparationStep by [preparationStepId]
  /// This is for getting preparation by preparationStepId
  Stream<PreparationStepEntity> getPreparationStepById(
      String preparationStepId);

  /// Create user's default preparation
  /// This is for creating default preparation for a user
  Future<void> createDefaultPreparation(
      PreparationEntity preparationEntity, String userId);

  /// Create custom preparation
  /// This is for creating custom preparation for a specific schedule
  Future<void> createCustomPreparation(
      PreparationEntity preparationEntity, String scheduleId);

  /// Update preparation
  /// This is for updating preparation
  Future<void> updatePreparationStep(
      PreparationStepEntity preparationStepEntity);

  /// Delete preparationStep
  /// This is for deleting preparationStep
  Future<void> deletePreparation(PreparationEntity preparationEntity);

  /// Update preparation by scheduleId
  /// This is for updating preparation by scheduleId
  Future<void> updatePreparationByScheduleId(
      PreparationEntity preparationEntity, String scheduleId);
}
