import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';

abstract interface class PreparationLocalDataSource {
  final AppDatabase appDatabase;

  PreparationLocalDataSource({
    required this.appDatabase,
  });

  Future<void> createDefaultPreparation(
      PreparationEntity preparationEntity, String userId);

  Future<void> createCustomPreparation(
      PreparationEntity preparation, String scheduleId);

  Future<void> updatePreparationStep(
      PreparationStepEntity preparationStepEntity);

  Future<void> updateDefaultPreparation(
      PreparationEntity preparationEntity, String userId);

  Future<void> updateCustomPreparation(
      PreparationEntity preparationEntity, String scheduleId);

  Future<void> deletePreparation(PreparationEntity preparationEntity);

  Future<PreparationEntity> getPreparationByScheduleId(String scheduleId);

  Future<PreparationStepEntity> getPreparationStepById(
      String preparationStepId);
}
