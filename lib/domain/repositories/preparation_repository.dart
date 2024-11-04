import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';

abstract interface class PreparationRepository {
  /// Get preparation by [scheduleId]
  /// This is for getting preparation by scheduleId
  Stream<PreparationEntity> getPreparationByScheduleId(int scheduleId);

  /// Get preparationStep by [preparationStepId]
  /// This is for getting preparation by preparationStepId
  Stream<PreparationStepEntity> getPreparationStepById(int preparationStepId);

  /// Create user's default preparation
  /// This is for creating default preparation for a user
  Future<void> createDefualtPreparation(
      PreparationEntity preparationEntity, int userId);

  /// Create custom preparation
  /// This is for creating custom preparation for a specific schedule
  Future<void> createCustomPreparation(
      PreparationEntity preparationEntity, int scheduleId);

  /// Update preparation
  /// This is for updating preparation
  Future<void> updatePreparation(PreparationStepEntity preparationEntity);

  /// Delete preparation
  /// This is for deleting preparation
  Future<void> deletePreparation(PreparationEntity preparationEntity);
}
