import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';

abstract interface class PreparationLocalDataSource {
  final AppDatabase appDatabase;

  PreparationLocalDataSource({
    required this.appDatabase,
  });

  Stream<PreparationEntity> getPreparationByScheduleId(String scheduleId);

  Stream<PreparationStepEntity> getPreparationStepById(
      String preparationStepId);

  Future<void> createDefualtPreparation(
      PreparationEntity preparationEntity, String userId);

  Future<void> createCustomPreparation(
      PreparationEntity preparation, String scheduleId);

  Future<void> updatePreparation(PreparationStepEntity preparationEntity);

  Future<void> deletePreparation(PreparationEntity preparationEntity);
}
