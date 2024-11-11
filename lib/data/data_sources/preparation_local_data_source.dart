import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';

abstract interface class PreparationLocalDataSource {
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

class PreparationLocalDataSourceImpl implements PreparationLocalDataSource {
  final AppDatabase appDatabase;

  PreparationLocalDataSourceImpl({
    required this.appDatabase,
  });

  @override
  Future<void> createCustomPreparation(
      PreparationEntity preparation, String scheduleId) async {
    await appDatabase.preparationScheduleDao.createPreparationSchedule(
        preparation.toPreparationScheduleModelList(scheduleId));
  }

  @override
  Future<void> createDefaultPreparation(
      PreparationEntity preparationEntity, String userId) async {
    await appDatabase.preparationUserDao.createPreparationUser(
        preparationEntity.toPreparationUserModelList(userId), userId);
  }

  @override
  Future<void> deletePreparation(PreparationEntity preparationEntity) {
    // TODO: implement deletePreparation
    throw UnimplementedError();
  }

  @override
  Future<PreparationEntity> getPreparationByScheduleId(String scheduleId) {
    // TODO: implement getPreparationByScheduleId
    throw UnimplementedError();
  }

  @override
  Future<PreparationStepEntity> getPreparationStepById(
      String preparationStepId) {
    // TODO: implement getPreparationStepById
    throw UnimplementedError();
  }

  @override
  Future<void> updatePreparationStep(
      PreparationStepEntity preparationStepEntity) {
    // TODO: implement updatePreparation
    throw UnimplementedError();
  }

  @override
  Future<void> updateCustomPreparation(
      PreparationEntity preparationEntity, String scheduleId) async {
    await appDatabase.preparationScheduleDao
        .deletePreparationScheduleByScheduleId(scheduleId);
    await appDatabase.preparationScheduleDao.createPreparationSchedule(
        preparationEntity.toPreparationScheduleModelList(scheduleId));
  }

  @override
  Future<void> updateDefaultPreparation(
      PreparationEntity preparationEntity, String userId) async {
    await appDatabase.preparationUserDao.deletePreparationUserByUserId(userId);
    await appDatabase.preparationUserDao.createPreparationUser(
        preparationEntity.toPreparationUserModelList(userId), userId);
  }
}
